import Foundation
import Observation
import FluidAudio

/// Kokoro на нейроядре (FluidAudio, Core ML): на iPhone 12 готовит речь в 5 раз быстрее, чем она звучит
/// (на процессоре через sherpa-onnx не успевал). Модель (~440 МБ) скачивается по кнопке в настройках;
/// в память загружается ~25 с — поэтому заранее, при открытии английской книги. В памяти ~700 МБ,
/// поэтому Kokoro на процессоре на это время выгружается; через 10 минут тишины выгружается и этот.
/// На iOS 26.4 и новее авторы библиотеки сообщают о падениях при долгом синтезе (FluidAudio #844, #889) — там не используем
@MainActor
@Observable
final class KokoroML {
    static let shared = KokoroML()

    enum Phase: Equatable {
        case notDownloaded
        case downloading
        case ready
        case failed(String)
    }

    static let installedKey = "kokoro_ml_installed"
    /// Настройки: в режиме «Чтение» загружать заранее, при запуске приложения (по умолчанию — да)
    static let preloadKey = "kokoro_ml_preload"
    /// Язык последней открытой книги — нужен ли Kokoro вообще (русские книги читает Piper)
    static let lastBookLanguageKey = "last_book_language"
    /// На заблокированном экране iOS не даёт Kokoro видеоядро («Error in building plan»), а режим без него
    /// (старый, Tail на процессоре) роняет приложение — поэтому в фоне читает Piper (см. ReaderSpeech)
    static let downloadSize = "~440 МБ"

    private(set) var phase: Phase = .notDownloaded
    /// Модель в памяти — фразы готовятся сразу
    private(set) var isLoaded = false
    private var manager: KokoroAneManager?
    private var loadTask: Task<KokoroAneManager, Error>?
    private var unloadTask: Task<Void, Never>?

    private init() {
        phase = UserDefaults.standard.bool(forKey: Self.installedKey) && Self.modelsExist ? .ready : .notDownloaded
        // Модели старого режима (проба «без видеоядра») не нужны — место освобождаем
        if let legacy = Self.modelFolders.first?.appendingPathComponent("ANE") {
            try? FileManager.default.removeItem(at: legacy)
        }
        UserDefaults.standard.removeObject(forKey: "kokoro_ml_no_gpu")
    }

    /// iOS 18 – 26.3: на 26.4 и новее Core ML у Kokoro падает при долгом синтезе
    nonisolated static var isSupported: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion < 26 || (version.majorVersion == 26 && version.minorVersion < 4)
    }

    /// Скачан и на этой iOS работает
    var isReady: Bool { phase == .ready && Self.isSupported }

    /// Где FluidAudio держит модели: сам Kokoro и общий для него разбор произношения
    private nonisolated static var modelFolders: [URL] {
        let models = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("fluidaudio/Models", isDirectory: true)
        return [models.appendingPathComponent("kokoro-82m-coreml"), models.appendingPathComponent("kokoro")]
    }

    private nonisolated static var modelsExist: Bool {
        modelFolders.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - Загрузка

    /// Скачать (если нет) и сразу загрузить в память; скачали — английские книги читает он
    func download() {
        guard phase != .downloading else { return }
        phase = .downloading
        Task {
            do {
                _ = try await loaded()
                UserDefaults.standard.set(true, forKey: Self.installedKey)
                phase = .ready
            } catch {
                phase = .failed("Не удалось скачать голос. Проверьте интернет и место на iPhone.")
            }
        }
    }

    /// Режим «Чтение», запуск или возврат в приложение: загрузить заранее — к нажатию ▶️ уже готов.
    /// Только если это включено, английские книги читает Kokoro на нейроядре и последняя книга английская
    func preloadIfReading() {
        guard AppMode.current == .reading,
              UserDefaults.standard.object(forKey: Self.preloadKey) as? Bool ?? true,
              (UserDefaults.standard.string(forKey: Self.lastBookLanguageKey) ?? BookLanguage.english).hasPrefix("en"),
              let voice = NeuralVoice.shared.bookVoice(language: BookLanguage.english),
              case .kokoroML = voice.engine else { return }
        preload()
    }

    /// Загрузить заранее — первая фраза книги не ждёт ~25 с
    func preload() {
        guard isReady else { return }
        Task { _ = try? await loaded() }
    }

    /// Удалить модель — освобождает ~440 МБ
    func remove() {
        Task {
            await unload()
            for folder in Self.modelFolders { try? FileManager.default.removeItem(at: folder) }
            UserDefaults.standard.set(false, forKey: Self.installedKey)
            phase = .notDownloaded
            NeuralVoice.shared.kokoroRemoved()
        }
    }

    func unload() async {
        unloadTask?.cancel()
        await manager?.cleanup()
        manager = nil
        isLoaded = false
    }

    private func loaded() async throws -> KokoroAneManager {
        if let manager { return manager }
        if let loadTask { return try await loadTask.value }
        // Kokoro на процессоре — из памяти: обе модели вместе не помещаются (на iPhone 12 iOS закрывала приложение)
        await NeuralVoice.shared.unloadEngine()
        let task = Task { () throws -> KokoroAneManager in
            let manager = KokoroAneManager(version: .v3)
            try await manager.initialize()
            return manager
        }
        loadTask = task
        defer { loadTask = nil }
        let manager = try await task.value
        self.manager = manager
        isLoaded = true
        scheduleUnload()
        return manager
    }

    private func scheduleUnload() {
        unloadTask?.cancel()
        unloadTask = Task {
            try? await Task.sleep(for: .seconds(600))
            guard !Task.isCancelled else { return }
            await unload()
        }
    }

    // MARK: - Речь

    /// Звук и начало каждого произнесённого слова в секундах (nil — сопоставить не удалось)
    func synthesize(_ text: String, voice: String, speed: Float) async throws -> (audio: NeuralVoiceEngine.Audio, words: [Double]?) {
        let manager = try await loaded()
        scheduleUnload()
        let result = try await manager.synthesizeDetailed(text: text, voice: voice, speed: speed)
        return (NeuralVoiceEngine.Audio(samples: result.samples, sampleRate: result.sampleRate), Self.wordStarts(result))
    }

    /// Начала слов: звуки (IPA) один к одному с длительностями модели, слова — через пробел.
    /// Звуков больше или меньше, чем длительностей (символ не из словаря модели, текст разбит на куски), — nil
    nonisolated static func wordStarts(_ result: KokoroAneSynthesisResult) -> [Double]? {
        let scalars = Array(result.phonemes.unicodeScalars)
        let durations = result.predictedDurations
        guard durations.count == scalars.count + 2, !result.samples.isEmpty else {
            #if DEBUG
            print("[TTS] звуков \(scalars.count), длительностей \(durations.count) — без подсветки слов: \(result.phonemes)")
            fflush(stdout)
            #endif
            return nil
        }
        let total = durations.reduce(0) { $0 + Int($1) }
        guard total > 0 else { return nil }
        let secondsPerFrame = Double(result.samples.count) / Double(result.sampleRate) / Double(total)
        // Первая длительность — начало (BOS)
        var frames = Int(durations[0])
        var starts: [Double] = []
        var inWord = false
        for (index, scalar) in scalars.enumerated() {
            if scalar == " " {
                inWord = false
            } else if !inWord, scalar.properties.isAlphabetic {
                starts.append(Double(frames) * secondsPerFrame)
                inWord = true
            }
            frames += Int(durations[index + 1])
        }
        return starts
    }
}
