import AVFoundation
import Observation
import Speech

/// Проверка произношения: слушает микрофон и распознаёт английскую речь — на телефоне, без интернета, если iPhone умеет.
/// Распознавателю подсказываем ожидаемое слово. Слово короткое: слушаем до 4 секунд или пока не услышали нужное
@MainActor
@Observable
final class SpeechChecker {
    enum Phase: Equatable { case idle, listening, processing, finished }

    private(set) var phase = Phase.idle
    /// Что распознано — по ходу речи обновляется
    private(set) var heard = ""
    /// Микрофон или распознавание речи запрещены в настройках
    private(set) var isDenied = false
    /// Распознавание сейчас недоступно (нет языка или сети, когда без неё нельзя)
    private(set) var isUnavailable = false

    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var expected = ""
    private var onFinish: ((String) -> Void)?

    static let listenSeconds = 4.0

    func listen(expecting word: String, onFinish: @escaping (String) -> Void) async {
        guard phase != .listening, phase != .processing else { return }
        guard await Self.authorize() else {
            isDenied = true
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            isUnavailable = true
            return
        }
        isUnavailable = false
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            restoreSession()
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.contextualStrings = [word]
        request.taskHint = .search
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request
        expected = word
        self.onFinish = onFinish
        heard = ""

        Self.installTap(on: engine.inputNode, request: request)
        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            restoreSession()
            return
        }
        phase = .listening
        task = Self.recognize(recognizer, request: request) { [weak self] text, isFinal in
            Task { @MainActor in self?.update(text, isFinal: isFinal) }
        }
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.listenSeconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    /// Хватит слушать: ждём окончательный результат, но не дольше секунды
    func stop() {
        guard phase == .listening else { return }
        timeout?.cancel()
        stopAudio()
        request?.endAudio()
        phase = .processing
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// Уйти с экрана — всё выключить без результата
    func cancel() {
        timeout?.cancel()
        if phase == .listening { stopAudio() }
        task?.cancel()
        task = nil
        request = nil
        onFinish = nil
        if phase != .idle, phase != .finished { restoreSession() }
        phase = .idle
    }

    func reset() {
        cancel()
        heard = ""
    }

    private func update(_ text: String?, isFinal: Bool) {
        guard phase == .listening || phase == .processing else { return }
        if let text { heard = text }
        // Услышали нужное слово — не ждём конца паузы
        if isFinal || Self.matches(heard, expected) {
            if phase == .listening { stopAudio() }
            finish()
        }
    }

    private func finish() {
        guard phase == .listening || phase == .processing else { return }
        timeout?.cancel()
        task?.cancel()
        task = nil
        request = nil
        phase = .finished
        restoreSession()
        let callback = onFinish
        onFinish = nil
        callback?(heard)
    }

    private func stopAudio() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    /// Возвращаем сессию озвучки: только воспроизведение, музыка приглушается
    private func restoreSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    // MARK: - Сравнение

    /// Распознанное содержит ожидаемое слово (или фразу); британское и американское написание — одно и то же
    nonisolated static func matches(_ heard: String, _ expected: String) -> Bool {
        let said = words(heard)
        let target = words(expected)
        guard !target.isEmpty, said.count >= target.count else { return false }
        for start in 0...(said.count - target.count) where zip(said[start...], target).allSatisfy({ same($0, $1) }) {
            return true
        }
        return false
    }

    nonisolated private static func words(_ text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .split { !($0.isLetter || $0 == "'") }
            .map(String.init)
    }

    nonisolated private static func same(_ a: String, _ b: String) -> Bool {
        a == b || american(a) == american(b)
    }

    /// colour → color, centre → center, realise → realize
    nonisolated private static func american(_ word: String) -> String {
        var w = word
        if w.hasSuffix("our"), w.count > 4 { w = String(w.dropLast(3)) + "or" }
        if w.hasSuffix("tre") { w = String(w.dropLast(3)) + "ter" }
        if w.hasSuffix("ise") { w = String(w.dropLast(3)) + "ize" }
        if w.hasSuffix("ised") { w = String(w.dropLast(4)) + "ized" }
        return w
    }

    // MARK: - Вне главного потока

    /// Звук с микрофона приходит в аудиопотоке — замыкание создаём вне главного актора
    nonisolated private static func installTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) {
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func recognize(_ recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest,
                                              handler: @escaping @Sendable (String?, Bool) -> Void) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? (error != nil))
        }
    }

    nonisolated private static func authorize() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
