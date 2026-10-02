import AVFoundation

/// Настройки озвучки (Профиль → ⚙️ → «Озвучка»)
enum SpeechSettings {
    /// "en-US" — американский акцент, "en-GB" — британский
    static let accentKey = "speech_accent"
    static let defaultAccent = "en-US"
    /// Скорость AVSpeechUtterance: 0.5 — обычная речь
    static let rateKey = "speech_rate"
    static let defaultRate = 0.45
    static let rateRange = 0.3...0.55
    /// Произносить английское слово сразу при показе, без нажатия на динамик
    static let autoSpeakKey = "speech_auto"
}

/// Озвучка слов. Музыку пользователя не останавливает: на время речи приглушает и потом возвращает громкость
final class TextToSpeechManager: NSObject {
    static let shared = TextToSpeechManager()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
        // .playback — слышно и в беззвучном режиме; .duckOthers — чужой звук приглушается, а не останавливается.
        // Сессию здесь не включаем: включённая при запуске, она глушила музыку, даже когда ничего не озвучивалось
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    func speak(_ text: String) {
        // Если синтезатор уже говорит, останавливаем его перед новым словом
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        try? AVAudioSession.sharedInstance().setActive(true)

        let defaults = UserDefaults.standard
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: defaults.string(forKey: SpeechSettings.accentKey) ?? SpeechSettings.defaultAccent)
        utterance.rate = Float(defaults.object(forKey: SpeechSettings.rateKey) as? Double ?? SpeechSettings.defaultRate)
        synthesizer.speak(utterance)
    }

    /// Озвучивает, только если включено «Озвучивать слово сразу»
    func speakAutomatically(_ text: String) {
        guard UserDefaults.standard.bool(forKey: SpeechSettings.autoSpeakKey) else { return }
        speak(text)
    }

    /// Речь закончилась — выключаем сессию, и музыка возвращается к прежней громкости
    private func deactivateIfIdle() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateIfIdle() }
    }

    // Прервали ради нового слова — новое уже говорит, и deactivateIfIdle сессию не тронет
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.deactivateIfIdle() }
    }
}
