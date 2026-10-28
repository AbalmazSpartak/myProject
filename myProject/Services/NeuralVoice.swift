import AVFoundation
import Foundation
import NaturalLanguage
import Observation
import SherpaOnnx

/// Нейросетевой голос Kokoro (82M, int8) через sherpa-onnx: работает на процессоре, без интернета.
/// Модель (~100 МБ архив, ~150 МБ распакованная) не входит в приложение — скачивается по кнопке в настройках «Озвучки» с официального релиза sherpa-onnx.
/// Пока голос не скачан, выключен или не справился — озвучивает системный голос, как раньше.
/// Книги вслух: английские — Kokoro (если устройство успевает) или лёгкий голос Piper, русские — Piper; Piper скачивается отдельно
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
        /// Акцент в настройках «Озвучки»
        var accentCode: String { accent == "брит." ? "en-GB" : "en-US" }
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

    /// Голоса Kokoro выбранного акцента ("en-GB" — британские, иначе американские)
    static func voices(accent: String) -> [Voice] {
        voices.filter { $0.accentCode == accent }
    }

    /// Голос Kokoro не того акцента, что выбран в «Озвучке», — берём первый голос этого акцента
    static func alignWithAccent() {
        let defaults = UserDefaults.standard
        let accent = defaults.string(forKey: SpeechSettings.accentKey) ?? SpeechSettings.defaultAccent
        let id = defaults.object(forKey: voiceKey) as? Int ?? 1
        let list = voices(accent: accent)
        if !list.contains(where: { $0.id == id }), let first = list.first { defaults.set(first.id, forKey: voiceKey) }
    }

    /// Лёгкие голоса Piper для книг — только со свободной лицензией: CC0 или общественное достояние
    /// (у «Ирины» лицензия записи неизвестна; «Руслан», hfc и Ryan — только некоммерческие)
    enum PiperVoice: String, CaseIterable, Identifiable, Sendable {
        case dmitri, denis, kristin, cori, joe, norman

        nonisolated var id: Self { self }

        /// Язык книг, которые читает голос
        nonisolated var language: String {
            switch self {
            case .dmitri, .denis: "ru"
            case .kristin, .cori, .joe, .norman: "en"
            }
        }

        private nonisolated var locale: String {
            switch self {
            case .dmitri, .denis: "ru_RU"
            case .cori: "en_GB"
            case .kristin, .joe, .norman: "en_US"
            }
        }

        var title: String {
            switch self {
            case .dmitri: "Дмитрий"
            case .denis: "Денис"
            case .kristin: "Кристин"
            case .cori: "Кори"
            case .joe: "Джо"
            case .norman: "Норман"
            }
        }

        /// Для списка в настройках: имя, акцент, голос
        var summary: String {
            switch self {
            case .dmitri, .denis: "\(title) · муж."
            case .kristin: "\(title) · амер., жен."
            case .cori: "\(title) · брит., жен."
            case .joe, .norman: "\(title) · амер., муж."
            }
        }

        nonisolated var folder: String { "vits-piper-\(locale)-\(rawValue)-medium" }
        nonisolated var modelFile: String { "\(locale)-\(rawValue)-medium.onnx" }
        nonisolated var archive: URL {
            URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/\(folder).tar.bz2")!
        }

        static func voices(for language: String) -> [PiperVoice] {
            allCases.filter { $0.language == language }
        }
    }

    /// Голос, которым читается книга
    struct BookVoice: Sendable, Equatable {
        /// sherpa-onnx на процессоре (Kokoro, Piper) или Kokoro на нейроядре (голос по имени)
        enum Engine: Sendable, Equatable {
            case sherpa(NeuralVoiceEngine.Model)
            case kokoroML(String)
        }

        let engine: Engine
        let speaker: Int
    }

    /// Голос Kokoro по номеру из настроек — имя у Kokoro на нейроядре (у «Default» — af_heart)
    static func kokoroName(_ id: Int) -> String {
        let names = ["af_heart", "af_bella", "af_nicole", "af_sarah", "af_sky", "am_adam", "am_michael",
                     "bf_emma", "bf_isabella", "bm_george", "bm_lewis"]
        return names.indices.contains(id) ? names[id] : names[1]
    }

    static let voiceKey = "neural_voice_id"
    /// Читать книги вслух нейросетевым голосом (если он скачан); по умолчанию — да
    static let booksKey = "neural_voice_books"
    /// Замерено при чтении: Kokoro готовит речь медленнее, чем она звучит (iPhone 12, iPad Air 4 и старше)
    static let kokoroSlowKey = "neural_kokoro_too_slow"
    /// Кто читает английские книги: "kokoro", "piper" или "" — сам (Kokoro, если успевает)
    static let englishBooksVoiceKey = "neural_en_books_voice"
    static let downloadSize = "~100 МБ, на iPhone ~150 МБ"
    static let piperDownloadSize = "~67 МБ, на iPhone ~75 МБ"
    /// Для кнопки «Скачать»: одно число вместо двух
    static let piperDownloadSizeShort = "~75 МБ"

    private nonisolated static let archiveURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-en-v0_19.tar.bz2")!
    private nonisolated static let folderName = "kokoro-int8-en-v0_19"

    private(set) var phase: Phase = .notDownloaded
    /// Голоса Piper по языкам книг («ru», «en») — скачиваются отдельно
    private(set) var piperPhases: [String: Phase] = [:]
    /// Kokoro не успевает читать книги на этом устройстве — книги читает Piper или системный голос
    private(set) var kokoroTooSlow = UserDefaults.standard.bool(forKey: NeuralVoice.kokoroSlowKey)
    private(set) var englishBooksVoice = UserDefaults.standard.string(forKey: NeuralVoice.englishBooksVoiceKey) ?? ""
    /// Голос Piper, фраза которого готовится для «Прослушать», — в настройках крутится индикатор
    private(set) var previewing: PiperVoice?
    private var previewTask: Task<Void, Never>?
    private let previewNode = AVAudioPlayerNode()
    /// Частота, на которую подключён плеер «Прослушать»; nil — ещё не подключён
    private var previewRate: Double?
    /// Одна загрузка за раз: архивы распаковываются в общую папку
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
        for language in ["ru", "en"] {
            piperPhases[language] = Self.installedPiper(language: language) != nil ? .ready : .notDownloaded
        }
        // Английский Piper скачан, а выбора ещё не было (скачан до появления выбора) — читает он
        if englishBooksVoice.isEmpty, piperPhases["en"] == .ready { setEnglishBooksVoice("piper") }
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

    /// Скачанный голос Piper для книг на этом языке
    nonisolated static func installedPiper(language: String) -> PiperVoice? {
        PiperVoice.allCases.first { voice in
            let folder = root.appendingPathComponent(voice.folder, isDirectory: true)
            return voice.language == language && [voice.modelFile, "tokens.txt", "espeak-ng-data"].allSatisfy {
                FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
            }
        }
    }

    func piperPhase(_ language: String) -> Phase {
        piperPhases[language] ?? .notDownloaded
    }

    var isDownloading: Bool { downloadTask != nil }

    /// Голос скачан — слова озвучиваются им, иначе системным
    var isActive: Bool { phase == .ready }

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
                    try Self.install(archive, folder: Self.folderName) { fraction in
                        Task { @MainActor in NeuralVoice.shared.phase = .unpacking(fraction) }
                    }
                }.value
                phase = Self.isInstalled ? .ready : .failed("Архив распаковался не полностью")
            } catch is CancellationError {
                phase = .notDownloaded
            } catch {
                phase = .failed("Не удалось скачать голос. Проверьте интернет и место на iPhone.")
            }
            downloadTask = nil
        }
    }

    /// Голос Piper для книг; другой голос того же языка после установки удаляется — место не копится
    func downloadPiper(_ voice: PiperVoice) {
        guard downloadTask == nil else { return }
        let language = voice.language
        piperPhases[language] = .downloading(0)
        downloadTask = Task {
            do {
                let archive = try await Self.fetch(voice.archive) { fraction in
                    Task { @MainActor in
                        let shared = NeuralVoice.shared
                        if case .downloading = shared.piperPhase(language) { shared.piperPhases[language] = .downloading(fraction) }
                    }
                }
                piperPhases[language] = .unpacking(0)
                try await Task.detached(priority: .userInitiated) {
                    try Self.install(archive, folder: voice.folder) { fraction in
                        Task { @MainActor in NeuralVoice.shared.piperPhases[language] = .unpacking(fraction) }
                    }
                }.value
                for other in PiperVoice.voices(for: language) where other != voice {
                    try? FileManager.default.removeItem(at: Self.root.appendingPathComponent(other.folder))
                }
                piperPhases[language] = Self.installedPiper(language: language) == voice ? .ready : .failed("Архив распаковался не полностью")
                // Скачали английский Piper — значит, хотят им слушать книги
                if language == "en", piperPhases[language] == .ready { setEnglishBooksVoice("piper") }
            } catch is CancellationError {
                piperPhases[language] = Self.installedPiper(language: language) != nil ? .ready : .notDownloaded
            } catch {
                piperPhases[language] = .failed("Не удалось скачать голос. Проверьте интернет и место на iPhone.")
            }
            downloadTask = nil
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        phase = Self.isInstalled ? .ready : .notDownloaded
        for language in ["ru", "en"] {
            piperPhases[language] = Self.installedPiper(language: language) != nil ? .ready : .notDownloaded
        }
    }

    /// Удалить модель — освобождает место; озвучка снова системная. Голоса Piper остаются
    func remove() {
        stop()
        cache = [:]
        cacheOrder = []
        Task { await engine.unload() }
        try? FileManager.default.removeItem(at: Self.modelFolder)
        phase = .notDownloaded
    }

    /// Выгрузить модель из памяти (проба Kokoro на нейроядре — памяти на обе не хватает)
    func unloadEngine() async {
        stop()
        await engine.unload()
    }

    /// Удалить голос Piper этого языка — его книги снова читает Kokoro или системный голос
    func removePiper(language: String) {
        Task { await engine.unload() }
        for voice in PiperVoice.voices(for: language) {
            try? FileManager.default.removeItem(at: Self.root.appendingPathComponent(voice.folder))
        }
        piperPhases[language] = .notDownloaded
        if language == "en", englishBooksVoice == "piper" { setEnglishBooksVoice("") }
    }

    /// Выбор в настройках: кто читает английские книги
    func setEnglishBooksVoice(_ choice: String) {
        englishBooksVoice = choice
        UserDefaults.standard.set(choice, forKey: Self.englishBooksVoiceKey)
    }

    /// Замер скорости Kokoro при чтении — только если голос выбирается сам; явный выбор Kokoro не трогаем
    var checksKokoroSpeed: Bool { englishBooksVoice.isEmpty }

    /// Замер при чтении: Kokoro не успевает — английские книги дальше читает Piper или системный голос
    func markKokoroTooSlow() {
        kokoroTooSlow = true
        UserDefaults.standard.set(true, forKey: Self.kokoroSlowKey)
    }

    /// «Проверить снова» в настройках — следующее чтение опять замерит Kokoro
    func resetKokoroCheck() {
        kokoroTooSlow = false
        UserDefaults.standard.set(false, forKey: Self.kokoroSlowKey)
    }

    // MARK: - Книги вслух

    /// Нейросетевой голос для книги на этом языке; nil — книгу читает системный.
    /// Английские: Kokoro живее всех, но на A14 и старше не успевает — тогда Piper, если скачан
    func bookVoice(language: String) -> BookVoice? {
        guard UserDefaults.standard.object(forKey: Self.booksKey) as? Bool ?? true else { return nil }
        let language = language.hasPrefix("ru") ? "ru" : language.hasPrefix("en") ? "en" : language
        let piper = piperPhase(language) == .ready ? Self.installedPiper(language: language) : nil
        let piperVoice = piper.map {
            BookVoice(engine: .sherpa(.piper(Self.root.appendingPathComponent($0.folder, isDirectory: true), file: $0.modelFile)),
                      speaker: 0)
        }
        guard language == "en" else { return piperVoice }
        // Kokoro: на нейроядре — если скачан и iOS подходит, иначе на процессоре (если успевает)
        let kokoroML = KokoroML.shared.isReady ? BookVoice(engine: .kokoroML(Self.kokoroName(selectedVoice)), speaker: 0) : nil
        let kokoroCPU = phase == .ready ? BookVoice(engine: .sherpa(.kokoro(Self.modelFolder)), speaker: selectedVoice) : nil
        switch englishBooksVoice {
        case "kokoro": return kokoroML ?? kokoroCPU ?? piperVoice
        case "piper": return piperVoice ?? kokoroML ?? kokoroCPU
        default: return kokoroML ?? (kokoroTooSlow ? nil : kokoroCPU) ?? piperVoice
        }
    }

    /// Скачанный голос Piper для книг на этом языке — замена Kokoro на нейроядре, пока экран заблокирован
    func piperBookVoice(language: String) -> BookVoice? {
        let language = language.hasPrefix("ru") ? "ru" : language.hasPrefix("en") ? "en" : language
        guard piperPhase(language) == .ready, let voice = Self.installedPiper(language: language) else { return nil }
        return BookVoice(engine: .sherpa(.piper(Self.root.appendingPathComponent(voice.folder, isDirectory: true), file: voice.modelFile)),
                         speaker: 0)
    }

    /// «Прослушать» в настройках: короткая фраза голосом Piper
    func previewPiper(_ voice: PiperVoice) {
        stop()
        previewing = voice
        let text = voice.language == "ru" ? "Здравствуйте! Так будут звучать русские книги." : "Hello! This is how English books will sound."
        let model = NeuralVoiceEngine.Model.piper(Self.root.appendingPathComponent(voice.folder, isDirectory: true), file: voice.modelFile)
        previewTask = Task {
            let audio = try? await engine.audio(text, model: model, speaker: 0, speed: 1)
            guard !Task.isCancelled else { return }
            previewing = nil
            if let audio { try? playPreview(audio) }
        }
    }

    private func playPreview(_ audio: NeuralVoiceEngine.Audio) throws {
        let rate = Double(audio.sampleRate)
        if previewRate != rate {
            audioEngine.stop()
            if previewRate == nil { audioEngine.attach(previewNode) } else { audioEngine.disconnectNodeOutput(previewNode) }
            audioEngine.connect(previewNode, to: audioEngine.mainMixerNode,
                                format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
            previewRate = rate
        }
        if !audioEngine.isRunning {
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
        }
        guard !audio.samples.isEmpty, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audio.samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = buffer.frameCapacity
        audio.samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: audio.samples.count) }
        previewNode.scheduleBuffer(buffer, completionHandler: nil)
        previewNode.play()
    }

    /// Предложение книги — звук; готовится на своём потоке, главный не ждёт
    /// words — начала произнесённых слов в секундах (их отдаёт только Kokoro на нейроядре)
    func bookAudio(_ text: String, voice: BookVoice, speed: Float) async throws -> (audio: NeuralVoiceEngine.Audio, words: [Double]?) {
        switch voice.engine {
        case .sherpa(let model):
            return (try await engine.audio(text, model: model, speaker: voice.speaker, speed: speed), nil)
        case .kokoroML(let name):
            return try await KokoroML.shared.synthesize(text, voice: name, speed: speed)
        }
    }

    /// Скачать файл с прогрессом во временную папку
    private nonisolated static func fetch(_ url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let delegate = DownloadProgress(progress)
        let (temporary, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: kept)
        try FileManager.default.moveItem(at: temporary, to: kept)
        return kept
    }

    /// Распаковать архив в общую папку голосов; заменяется только папка этого голоса
    private nonisolated static func install(_ archive: URL, folder: String, progress: @escaping @Sendable (Double) -> Void) throws {
        let manager = FileManager.default
        try? manager.removeItem(at: root.appendingPathComponent(folder))
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
        // Выбрали системный голос в «Озвучке» — слова говорит он, даже если Kokoro скачан
        guard isActive, !SpeechSettings.forcesSystemVoice else { return false }
        let voice = selectedVoice
        // Скорость из «Озвучки» (0,75…1,25); «медленно» — ещё на 30% тише
        let speed = Float(SpeechSettings.neuralSpeedFactor * (slow ? 0.7 : 1.0))
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
                        // Kokoro на нейроядре уже в памяти (читается книга) — слово им: быстрее, и вторая модель не нужна
                        samples = KokoroML.shared.isLoaded
                            ? try await KokoroML.shared.synthesize(parts[index], voice: Self.kokoroName(voice), speed: speed).audio.samples
                            : try await engine.generate(parts[index], voice: voice, speed: speed, folder: folder)
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
        previewTask?.cancel()
        previewTask = nil
        previewing = nil
        if previewRate != nil { previewNode.stop() }
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
        let speaker = selectedVoice
        Task { try? await engine.warmUp(folder, speaker: speaker) }
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

    /// Kokoro — английский, много голосов; Piper — один голос в модели (русский для книг)
    enum Model: Sendable, Equatable {
        case kokoro(URL)
        case piper(URL, file: String)
    }

    struct Audio: Sendable {
        let samples: [Float]
        let sampleRate: Int
    }

    private var tts: SherpaOnnxOfflineTtsWrapper?
    /// Какая модель в памяти: другая — выгружаем и загружаем нужную
    private var loaded: Model?
    /// С каким языком espeak загружен Kokoro: британские голоса — «en-gb», иначе произношение выходит американским и с искажениями
    private var loadedLang = ""
    /// Британская фонетика в этой модели не нашлась — дальше сразу американская
    private var britishUnsupported = false
    private static let britishLang = "en-gb-x-rp"
    private var unloadTask: Task<Void, Never>?

    func generate(_ text: String, voice: Int, speed: Float, folder: URL) throws -> [Float] {
        try audio(text, model: .kokoro(folder), speaker: voice, speed: speed).samples
    }

    func audio(_ text: String, model: Model, speaker: Int, speed: Float) throws -> Audio {
        // Отменили, пока ждали очереди, — не тратим секунды на устаревшую фразу
        try Task.checkCancellation()
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return Audio(samples: [], sampleRate: Self.sampleRate) }
        var lang = Self.lang(for: model, speaker: speaker)
        if lang == Self.britishLang, britishUnsupported { lang = "en-us" }
        var generated = try load(model, lang: lang).generate(text: clean, sid: speaker, speed: speed)
        // Нет такого голоса espeak — библиотека возвращает пустоту (раньше на этом падало приложение): читаем по-старому
        if generated.audio == nil, lang == Self.britishLang {
            britishUnsupported = true
            generated = try load(model, lang: "en-us").generate(text: clean, sid: speaker, speed: speed)
        }
        scheduleUnload()
        guard generated.audio != nil else { throw NeuralVoiceError.empty }
        let samples = generated.samples
        guard !samples.isEmpty else { throw NeuralVoiceError.empty }
        return Audio(samples: samples, sampleRate: Int(generated.sampleRate))
    }

    func warmUp(_ folder: URL, speaker: Int) throws {
        _ = try load(.kokoro(folder), lang: Self.lang(for: .kokoro(folder), speaker: speaker))
        scheduleUnload()
    }

    /// Голоса Kokoro 7–10 (Emma, Isabella, George, Lewis) — британские
    nonisolated static func lang(for model: Model, speaker: Int) -> String {
        guard case .kokoro = model else { return "" }
        return speaker >= 7 ? britishLang : "en-us"
    }

    func unload() {
        unloadTask?.cancel()
        tts = nil
        loaded = nil
    }

    private func load(_ model: Model, lang: String = "") throws -> SherpaOnnxOfflineTtsWrapper {
        if let tts, loaded == model, loadedLang == lang { return tts }
        tts = nil
        loaded = nil
        // Замер на A14: 4 потока быстрее всего (2 — на 10% медленнее, 3 — ещё медленнее: поток уходит на экономное ядро)
        let threads = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 2))
        let folder: URL
        let required: String
        switch model {
        case .kokoro(let url): (folder, required) = (url, "model.int8.onnx")
        case .piper(let url, let file): (folder, required) = (url, file)
        }
        let path = { (name: String) in folder.appendingPathComponent(name).path }
        guard FileManager.default.fileExists(atPath: path(required)) else { throw NeuralVoiceError.notInstalled }
        var config = switch model {
        case .kokoro:
            sherpaOnnxOfflineTtsConfig(model: sherpaOnnxOfflineTtsModelConfig(
                kokoro: sherpaOnnxOfflineTtsKokoroModelConfig(model: path("model.int8.onnx"), voices: path("voices.bin"),
                                                              tokens: path("tokens.txt"), dataDir: path("espeak-ng-data"), lang: lang),
                numThreads: threads, debug: 0))
        case .piper(_, let file):
            sherpaOnnxOfflineTtsConfig(model: sherpaOnnxOfflineTtsModelConfig(
                vits: sherpaOnnxOfflineTtsVitsModelConfig(model: path(file), lexicon: "", tokens: path("tokens.txt"),
                                                          dataDir: path("espeak-ng-data")),
                numThreads: threads, debug: 0))
        }
        let created = SherpaOnnxOfflineTtsWrapper(config: &config)
        guard created.tts != nil else { throw NeuralVoiceError.notInstalled }
        tts = created
        loaded = model
        loadedLang = lang
        return created
    }

    private func scheduleUnload() {
        unloadTask?.cancel()
        unloadTask = Task {
            try? await Task.sleep(for: .seconds(180))
            guard !Task.isCancelled else { return }
            tts = nil
            loaded = nil
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
