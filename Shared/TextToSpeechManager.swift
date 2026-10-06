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

    /// Включение и выключение аудиосессии — блокирующие вызовы: на главном потоке они дёргали начало слова.
    /// Делаем их по очереди в фоне, в том порядке, в каком попросили
    private static let sessionQueue = DispatchQueue(label: "speech.audio-session", qos: .userInitiated)
    /// Номер последней просьбы озвучить: устаревшие (успели нажать на другое слово) не говорят и не выключают сессию
    private var request = 0
    /// Голос ищется долго — находим один раз на акцент
    private var cachedVoice: (accent: String, voice: AVSpeechSynthesisVoice?)?

    private override init() {
        super.init()
        synthesizer.delegate = self
        // .playback — слышно и в беззвучном режиме; .duckOthers — чужой звук приглушается, а не останавливается.
        // Сессию здесь не включаем: включённая при запуске, она глушила музыку, даже когда ничего не озвучивалось
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    /// Заранее найти голос — первое слово после запуска не ждёт его
    func prepare() {
        _ = voice()
    }

    func speak(_ text: String) {
        // Если синтезатор уже говорит, останавливаем его перед новым словом
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        request += 1
        let current = request
        // Сессия включается в фоне; говорить начинаем, когда она готова, — звук не дёргается
        Self.sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(true)
            Task { @MainActor in
                guard current == self.request else { return }
                self.synthesizer.speak(self.utterance(text))
            }
        }
    }

    private func utterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice()
        utterance.rate = Float(UserDefaults.standard.object(forKey: SpeechSettings.rateKey) as? Double ?? SpeechSettings.defaultRate)
        return utterance
    }

    private func voice() -> AVSpeechSynthesisVoice? {
        let accent = UserDefaults.standard.string(forKey: SpeechSettings.accentKey) ?? SpeechSettings.defaultAccent
        if let cachedVoice, cachedVoice.accent == accent { return cachedVoice.voice }
        let voice = AVSpeechSynthesisVoice(language: accent)
        cachedVoice = (accent, voice)
        return voice
    }

    /// Синтезатор для кнопки 🔊 виджета: говорит через системную аудиосессию iOS, а не через сессию приложения
    private lazy var systemSessionSynthesizer: AVSpeechSynthesizer = {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.usesApplicationAudioSession = false
        return synthesizer
    }()

    /// Кнопка 🔊 виджета: iOS запускает приложение в фоне, а включить из фона свою сессию не даёт
    /// (ошибка «нельзя начать воспроизведение», проверено на iPhone). Системная сессия синтезатора работает.
    /// Ждём конца речи (не дольше 10 с), чтобы система не усыпила приложение посреди слова
    func speakFromBackground(_ text: String) async {
        let synthesizer = systemSessionSynthesizer
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance(text))
        for _ in 0..<100 {
            try? await Task.sleep(for: .milliseconds(100))
            if !synthesizer.isSpeaking { break }
        }
    }

    /// Озвучивает, только если включено «Озвучивать слово сразу»
    func speakAutomatically(_ text: String) {
        guard UserDefaults.standard.bool(forKey: SpeechSettings.autoSpeakKey) else { return }
        speak(text)
    }

    /// Речь закончилась — через секунду тишины выключаем сессию, и музыка возвращается к прежней громкости.
    /// Пауза — чтобы между словами подряд музыка не прыгала туда-сюда
    private func deactivateIfIdle() {
        let current = request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            MainActor.assumeIsolated {
                guard current == self.request, !self.synthesizer.isSpeaking else { return }
                Self.sessionQueue.async {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }
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
