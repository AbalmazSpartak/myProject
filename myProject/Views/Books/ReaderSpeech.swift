import AVFoundation
import MediaPlayer
import Observation

/// Чтение книги вслух: абзац за абзацем, с подсветкой абзаца и произносимого слова.
/// Играет и при выключенном экране, как аудиокнига: пауза — с экрана блокировки и кнопкой наушников
@MainActor
@Observable
final class ReaderSpeech: NSObject {
    /// Скорость относительно настройки «Озвучки»
    static let speedKey = "reader_speech_speed"
    static let speeds: [Double] = [0.75, 1, 1.25, 1.5]

    private(set) var isPlaying = false
    /// Читаемый абзац главы; nil — чтение не начиналось или остановлено
    private(set) var paragraph: Int?
    /// Произносимое слово внутри абзаца (UTF-16, как NSRange)
    private(set) var word: NSRange?

    /// Глава кончилась — читалка открывает следующую и вызывает start
    @ObservationIgnored var onChapterEnd: (() -> Void)?
    /// Язык книги не английский — голос этого языка; nil — английский голос из «Озвучки»
    @ObservationIgnored var language: String?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var paragraphs: [String] = []
    @ObservationIgnored private var title = ""
    @ObservationIgnored private var bookTitle = ""
    /// Высказывание, которое сейчас говорится: колбэки от прерванных старых не засчитываются
    @ObservationIgnored private var current: AVSpeechUtterance?
    @ObservationIgnored private var remoteReady = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Текст главы для чтения
    func load(paragraphs: [String], chapterTitle: String, bookTitle: String) {
        self.paragraphs = paragraphs
        title = chapterTitle
        self.bookTitle = bookTitle
    }

    /// Начать с абзаца
    func start(from index: Int) {
        guard paragraphs.indices.contains(index) else { return }
        stopSynthesizer()
        activateSession()
        setUpRemoteCommands()
        isPlaying = true
        speak(index)
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        synthesizer.pauseSpeaking(at: .word)
        updateNowPlaying()
    }

    func resume() {
        guard !isPlaying, let paragraph else { return }
        activateSession()
        isPlaying = true
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speak(paragraph)
        }
        updateNowPlaying()
    }

    /// Выход из читалки: тишина, подсветка снимается, экран блокировки очищается
    func stop() {
        isPlaying = false
        paragraph = nil
        word = nil
        stopSynthesizer()
        TextToSpeechManager.keepsSessionActive = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Речь

    private func speak(_ index: Int) {
        paragraph = index
        word = nil
        let utterance = AVSpeechUtterance(string: paragraphs[index])
        if let language {
            utterance.voice = SpeechSettings.bestVoice(language: language)
        } else {
            let accent = UserDefaults.standard.string(forKey: SpeechSettings.accentKey) ?? SpeechSettings.defaultAccent
            let identifier = UserDefaults.standard.string(forKey: SpeechSettings.voiceKey) ?? ""
            utterance.voice = SpeechSettings.resolveVoice(accent: accent, identifier: identifier)
        }
        let base = UserDefaults.standard.object(forKey: SpeechSettings.rateKey) as? Double ?? SpeechSettings.defaultRate
        let speed = UserDefaults.standard.object(forKey: Self.speedKey) as? Double ?? 1
        utterance.rate = Float(min(max(base * speed, Double(AVSpeechUtteranceMinimumSpeechRate)), 0.65))
        // Короткая пауза между абзацами — как вдох у чтеца
        utterance.postUtteranceDelay = 0.25
        current = utterance
        synthesizer.speak(utterance)
        updateNowPlaying()
    }

    private func stopSynthesizer() {
        current = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard utterance === current, isPlaying, let paragraph else { return }
        word = nil
        if paragraphs.indices.contains(paragraph + 1) {
            speak(paragraph + 1)
        } else {
            // Следующую главу читалка готовит сама и продолжает чтение
            isPlaying = false
            self.paragraph = nil
            onChapterEnd?()
        }
    }

    /// Сессия звука — общая с озвучкой слов; пока идёт чтение, озвучка слов её не выключает
    private func activateSession() {
        TextToSpeechManager.keepsSessionActive = true
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Экран блокировки и наушники

    private func setUpRemoteCommands() {
        guard !remoteReady else { return }
        remoteReady = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isPlaying ? self.pause() : self.resume()
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: bookTitle,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

extension ReaderSpeech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in
            guard utterance === self.current else { return }
            self.word = characterRange
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.finished(utterance) }
    }
}
