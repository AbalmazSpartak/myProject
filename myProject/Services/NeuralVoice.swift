import AVFoundation
import Foundation
import NaturalLanguage
import Observation
import SherpaOnnx

/// Нейросетевой голос Kokoro (82M, int8) через sherpa-onnx: работает на процессоре, без интернета.
/// Модель (~100 МБ архив, ~150 МБ распакованная) не входит в приложение — скачивается по кнопке в настройках «Озвучки» с официального релиза sherpa-onnx.
/// Пока голос не скачан, выключен или не справился — озвучивает системный голос, как раньше
@MainActor
@Observable
final class NeuralVoice {
    static let shared = NeuralVoice()

    enum Phase: Equatable {
        case notDownloaded
        case downloading(Double)
        case unpacking(Double)
        case ready
        case failed(String)
    }

    struct Voice: Identifiable, Hashable {
        let id: Int
        let name: String
        let accent: String
        let female: Bool

        var title: String { "\(name) · \(accent), \(female ? "жен." : "муж.")" }
    }

    /// Голоса модели kokoro-en-v0_19 по номерам
    static let voices: [Voice] = [
        Voice(id: 0, name: "Default", accent: "амер.", female: true),
        Voice(id: 1, name: "Bella", accent: "амер.", female: true),
        Voice(id: 2, name: "Nicole", accent: "амер.", female: true),
        Voice(id: 3, name: "Sarah", accent: "амер.", female: true),
        Voice(id: 4, name: "Sky", accent: "амер.", female: true),
        Voice(id: 5, name: "Adam", accent: "амер.", female: false),
        Voice(id: 6, name: "Michael", accent: "амер.", female: false),
        Voice(id: 7, name: "Emma", accent: "брит.", female: true),
        Voice(id: 8, name: "Isabella", accent: "брит.", female: true),
        Voice(id: 9, name: "George", accent: "брит.", female: false),
        Voice(id: 10, name: "Lewis", accent: "брит.", female: false),
    ]

    static let enabledKey = "neural_voice_enabled"
    static let voiceKey = "neural_voice_id"
    static let downloadSize = "~100 МБ, на iPhone ~150 МБ"

    private nonisolated static let archiveURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2")!
    private nonisolated static let folderName = "kokoro-int8-en-v0_19"

    private(set) var phase: Phase = .notDownloaded
    private var downloadTask: Task<Void, Never>?
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isEngineReady = false
    /// Номер воспроизведения: после stop() старые куски не считаются
    private var playback = 0
    /// Сколько кусков ещё в очереди плеера
    private var scheduled = 0
    private static let format = AVAudioFormat(standardFormatWithSampleRate: Double(NeuralVoiceEngine.sampleRate), channels: 1)!
    private let engine = NeuralVoiceEngine()
    private var speakTask: Task<Void, Never>?
    private var pendingKey: String?
    private var cache: [String: [Float]] = [:]
    private var cacheOrder: [String] = []
    /// Фраза готовится — в настройках видно «Готовлю голос…»
    private(set) var isPreparing = false

    private init() {
        phase = Self.isInstalled ? .ready : .notDownloaded
    }

    // MARK: - Где лежит модель

    /// Application Support/NeuralVoice — не попадает в резервную копию iCloud
    nonisolated static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("NeuralVoice", isDirectory: true)
    }

    nonisolated static var modelFolder: URL { root.appendingPathComponent(folderName, isDirectory: true) }

    nonisolated static var isInstalled: Bool {
        let folder = modelFolder
        return ["model.int8.onnx", "voices.bin", "tokens.txt", "espeak-ng-data"].allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }

    /// Голос включён и скачан — озвучка идёт через него
    var isActive: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey) && phase == .ready
    }

    var selectedVoice: Int {
        UserDefaults.standard.object(forKey: Self.voiceKey) as? Int ?? 1
    }

    // MARK: - Загрузка

    func download() {
        guard downloadTask == nil else { return }
        phase = .downloading(0)
        downloadTask = Task {
            do {
                let archive = try await Self.fetch(Self.archiveURL) { fraction in
                    Task { @MainActor in
                        if case .downloading = NeuralVoice.shared.phase { NeuralVoice.shared.phase = .downloading(fraction) }
                    }
                }
                phase = .unpacking(0)
                try await Task.detached(priority: .userInitiated) {
                    try Self.install(archive) { fraction in
                        Task { @MainActor in NeuralVoice.shared.phase = .unpacking(fraction) }
                    }
                }.value
                phase = Self.isInstalled ? .ready : .failed("Архив распаковался не полностью")
                if phase == .ready { UserDefaults.standard.set(true, forKey: Self.enabledKey) }
            } catch is CancellationError {
                phase = .notDownloaded
            } catch {
                phase = .failed("Не удалось скачать голос. Проверьте интернет и место на iPhone.")
            }
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        phase = Self.isInstalled ? .ready : .notDownloaded
    }

    /// Удалить модель — освобождает место; озвучка снова системная
    func remove() {
        stop()
        cache = [:]
        cacheOrder = []
        Task { await engine.unload() }
        try? FileManager.default.removeItem(at: Self.root)
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        phase = .notDownloaded
    }

    /// Скачать файл с прогрессом во временную папку
    private nonisolated static func fetch(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = DownloadProgress(progress)
        let (temporary, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("kokoro-voice.tar.bz2")
        try? FileManager.default.removeItem(at: kept)
        try FileManager.default.moveItem(at: temporary, to: kept)
        return kept
    }

    private nonisolated static func install(_ archive: URL, progress: @escaping @Sendable (Double) -> Void) throws {
        let manager = FileManager.default
        try? manager.removeItem(at: root)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folder = root
        try? folder.setResourceValues(values)
        defer { try? manager.removeItem(at: archive) }
        try TarBz2Extractor.extract(archive, to: root, progress: progress)
    }

    // MARK: - Речь

    /// Сказать текст нейросетевым голосом; false — голос недоступен, говорит системный.
    /// Длинный текст режется на куски по предложениям и запятым: первый звучит почти сразу,
    /// следующий готовится, пока звучит предыдущий. Пока фраза готовится, повторное нажатие на неё
    /// ничего не запускает заново, а нажатие на другую отменяет старую — очередь не копится
    @discardableResult
    func speak(_ text: String, slow: Bool = false) -> Bool {
        guard isActive else { return false }
        let voice = selectedVoice
        let speed: Float = slow ? 0.7 : 1.0
        let key = "\(voice)|\(speed)|\(text)"
        if pendingKey == key { return true }
        stop()
        let parts = Self.split(text)
        guard !parts.isEmpty else { return true }
        pendingKey = key
        isPreparing = true
        let folder = Self.modelFolder
        speakTask = Task {
            var index = 0
            do {
                while index < parts.count {
                    let partKey = "\(voice)|\(speed)|\(parts[index])"
                    let samples: [Float]
                    if let cached = cache[partKey] {
                        samples = cached
                    } else {
                        samples = try await engine.generate(parts[index], voice: voice, speed: speed, folder: folder)
                        remember(samples, for: partKey)
                    }
                    try Task.checkCancellation()
                    try schedule(samples)
                    isPreparing = false
                    index += 1
                }
                finish(key)
            } catch is CancellationError {
            } catch {
                // Не справился — недосказанное системным голосом
                finish(key)
                TextToSpeechManager.shared.speakWithSystemVoice(parts[index...].joined(separator: " "), slow: slow)
            }
        }
        return true
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        pendingKey = nil
        isPreparing = false
        playback += 1
        scheduled = 0
        if isEngineReady { playerNode.stop() }
    }

    /// Предложения; длинные (больше 10 слов) — ещё и по запятым, кусками не короче 4 слов
    nonisolated static func split(_ text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        func words(_ string: String) -> Int { string.split(whereSeparator: \.isWhitespace).count }
        var parts: [String] = []
        for sentence in sentences {
            guard words(sentence) > 10 else {
                parts.append(sentence)
                continue
            }
            var current = ""
            for character in sentence {
                current.append(character)
                if ",;:—".contains(character), words(current) >= 4 {
                    parts.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                }
            }
            let rest = current.trimmingCharacters(in: .whitespaces)
            if rest.isEmpty { continue }
            if words(rest) < 3, let last = parts.popLast() {
                parts.append(last + " " + rest)
            } else {
                parts.append(rest)
            }
        }
        return parts
    }

    /// Загрузить модель заранее — первая фраза не ждёт 2–3 с загрузки
    func warmUp() {
        guard isActive else { return }
        let folder = Self.modelFolder
        Task { try? await engine.warmUp(folder) }
    }

    private func finish(_ key: String) {
        guard pendingKey == key else { return }
        pendingKey = nil
        isPreparing = false
    }

    /// Последние озвученные фразы — повтор того же слова звучит сразу
    private func remember(_ samples: [Float], for key: String) {
        if cache[key] == nil { cacheOrder.append(key) }
        cache[key] = samples
        if cacheOrder.count > 40 { cache[cacheOrder.removeFirst()] = nil }
    }

    // MARK: - Воспроизведение

    /// Куски ставятся в очередь плеера друг за другом — без пауз между ними
    private func schedule(_ samples: [Float]) throws {
        if !isEngineReady {
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: Self.format)
            isEngineReady = true
        }
        if !audioEngine.isRunning {
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
        }
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: Self.format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        scheduled += 1
        let current = playback
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in self?.bufferFinished(current) }
        }
        if !playerNode.isPlaying { playerNode.play() }
    }

    /// Всё сказано — через секунду тишины выключаем звук, и музыка возвращается к прежней громкости.
    /// Сессию не трогаем, если её взяла запись голоса («Произнеси») или читалка читает вслух
    private func bufferFinished(_ current: Int) {
        guard current == playback else { return }
        scheduled -= 1
        guard scheduled == 0, pendingKey == nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, current == self.playback, self.scheduled == 0, self.pendingKey == nil else { return }
                self.audioEngine.stop()
                let session = AVAudioSession.sharedInstance()
                guard session.category == .playback, !TextToSpeechManager.keepsSessionActive,
                      !TextToSpeechManager.shared.isSpeaking else { return }
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
}

/// Сама модель: загружается при первой фразе и держится в памяти, пока голосом пользуются;
/// через 3 минуты тишины выгружается — память нужна приложению
actor NeuralVoiceEngine {
    static let sampleRate = 24_000

    private var tts: SherpaOnnxOfflineTtsWrapper?
    private var unloadTask: Task<Void, Never>?

    func generate(_ text: String, voice: Int, speed: Float, folder: URL) throws -> [Float] {
        // Отменили, пока ждали очереди, — не тратим секунды на устаревшую фразу
        try Task.checkCancellation()
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        let tts = try load(folder)
        let audio = tts.generate(text: clean, sid: voice, speed: speed)
        scheduleUnload()
        let samples = audio.samples
        guard !samples.isEmpty else { throw NeuralVoiceError.empty }
        return samples
    }

    func warmUp(_ folder: URL) throws {
        _ = try load(folder)
        scheduleUnload()
    }

    func unload() {
        unloadTask?.cancel()
        tts = nil
    }

    private func load(_ folder: URL) throws -> SherpaOnnxOfflineTtsWrapper {
        if let tts { return tts }
        let path = { (name: String) in folder.appendingPathComponent(name).path }
        guard FileManager.default.fileExists(atPath: path("model.int8.onnx")) else { throw NeuralVoiceError.notInstalled }
        let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(model: path("model.int8.onnx"), voices: path("voices.bin"),
                                                           tokens: path("tokens.txt"), dataDir: path("espeak-ng-data"))
        let threads = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 2))
        let model = sherpaOnnxOfflineTtsModelConfig(kokoro: kokoro, numThreads: threads, debug: 0)
        var config = sherpaOnnxOfflineTtsConfig(model: model)
        let created = SherpaOnnxOfflineTtsWrapper(config: &config)
        guard created.tts != nil else { throw NeuralVoiceError.notInstalled }
        tts = created
        return created
    }

    private func scheduleUnload() {
        unloadTask?.cancel()
        unloadTask = Task {
            try? await Task.sleep(for: .seconds(180))
            guard !Task.isCancelled else { return }
            tts = nil
        }
    }
}

enum NeuralVoiceError: Error { case notInstalled, empty }

/// Прогресс загрузки модели
private final class DownloadProgress: NSObject, URLSessionTaskDelegate, Sendable {
    private let report: @Sendable (Double) -> Void

    init(_ report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let report = self.report
        // Наблюдение держится, пока жив task — через свойство progress
        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            report(progress.fractionCompleted)
        }
        objc_setAssociatedObject(task, &DownloadProgress.key, observation, .OBJC_ASSOCIATION_RETAIN)
    }

    nonisolated(unsafe) private static var key = 0
}
