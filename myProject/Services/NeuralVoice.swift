import AVFoundation
import Foundation
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
    private var player: AVAudioPlayer?
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
    /// Фраза готовится 0,5–4 с: пока готовится, повторное нажатие на неё ничего не запускает заново,
    /// а нажатие на другую отменяет ещё не начатые — очередь не копится
    @discardableResult
    func speak(_ text: String, slow: Bool = false) -> Bool {
        guard isActive else { return false }
        let voice = selectedVoice
        let speed: Float = slow ? 0.7 : 1.0
        let key = "\(voice)|\(speed)|\(text)"
        if pendingKey == key { return true }
        stop()
        if let samples = cache[key] {
            do { try play(samples) } catch { TextToSpeechManager.shared.speakWithSystemVoice(text, slow: slow) }
            return true
        }
        pendingKey = key
        isPreparing = true
        let folder = Self.modelFolder
        speakTask = Task {
            do {
                let samples = try await engine.generate(text, voice: voice, speed: speed, folder: folder)
                try Task.checkCancellation()
                remember(samples, for: key)
                finish(key)
                try play(samples)
            } catch is CancellationError {
            } catch {
                // Не справился — тот же текст системным голосом
                finish(key)
                TextToSpeechManager.shared.speakWithSystemVoice(text, slow: slow)
            }
        }
        return true
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        pendingKey = nil
        isPreparing = false
        player?.stop()
        player = nil
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

    private func play(_ samples: [Float]) throws {
        let data = Self.wav(samples, sampleRate: NeuralVoiceEngine.sampleRate)
        try AVAudioSession.sharedInstance().setActive(true)
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    /// PCM 16 бит, моно — WAV в памяти для AVAudioPlayer
    private nonisolated static func wav(_ samples: [Float], sampleRate: Int) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            var value = Int16(max(-1, min(1, sample)) * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        var header = Data()
        func append<T>(_ value: T) {
            var little = value
            withUnsafeBytes(of: &little) { header.append(contentsOf: $0) }
        }
        header.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + pcm.count).littleEndian)
        header.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16).littleEndian)
        append(UInt16(1).littleEndian)
        append(UInt16(1).littleEndian)
        append(UInt32(sampleRate).littleEndian)
        append(UInt32(sampleRate * 2).littleEndian)
        append(UInt16(2).littleEndian)
        append(UInt16(16).littleEndian)
        header.append(contentsOf: Array("data".utf8))
        append(UInt32(pcm.count).littleEndian)
        return header + pcm
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
