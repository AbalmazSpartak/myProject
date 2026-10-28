@preconcurrency import AVFoundation
import UIKit

/// Настройки озвучки (Профиль → ⚙️ → «Озвучка»)
enum SpeechSettings {
    /// "en-US" — американский акцент, "en-GB" — британский
    static let accentKey = "speech_accent"
    static let defaultAccent = "en-US"
    /// Скорость AVSpeechUtterance: 0.5 — обычная речь
    static let rateKey = "speech_rate"
    static let defaultRate = 0.45
    static let rateRange = 0.3...0.55

    /// Скорость нейросетевого голоса по бегунку «Скорость речи»: на обычной точке — 1, на краях шкалы — 0,75 и 1,25
    static func neuralSpeedFactor(rate: Double) -> Double {
        let clamped = min(max(rate, rateRange.lowerBound), rateRange.upperBound)
        if clamped <= defaultRate {
            return 0.75 + 0.25 * (clamped - rateRange.lowerBound) / (defaultRate - rateRange.lowerBound)
        }
        return 1 + 0.25 * (clamped - defaultRate) / (rateRange.upperBound - defaultRate)
    }

    /// То же — из сохранённых настроек
    static var neuralSpeedFactor: Double {
        neuralSpeedFactor(rate: UserDefaults.standard.object(forKey: rateKey) as? Double ?? defaultRate)
    }
    /// Произносить английское слово сразу при показе, без нажатия на динамик
    static let autoSpeakKey = "speech_auto"
    /// Выбранный голос (identifier); пусто — автоматически лучший скачанный для акцента
    static let voiceKey = "speech_voice"
    /// Чем озвучивать слова: пусто — Kokoro, если скачан, иначе системный; "system" — выбрали системный голос в списке «Голос»
    static let wordsEngineKey = "speech_words_engine"

    static var forcesSystemVoice: Bool {
        UserDefaults.standard.string(forKey: wordsEngineKey) == "system"
    }

    /// Голоса акцента: премиум и улучшенные первыми, внутри — по имени.
    /// Без «забавных» (Bells, Bad News…) и личного голоса — его Apple сторонним приложениям не даёт
    nonisolated static func voices(for accent: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == accent && !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .sorted { ($0.quality.rawValue, $1.name) > ($1.quality.rawValue, $0.name) }
    }

    /// Голос для речи: выбранный, если он есть для этого акцента; иначе лучший скачанный (улучшенный или премиум);
    /// если таких нет — голос iOS по умолчанию
    nonisolated static func resolveVoice(accent: String, identifier: String) -> AVSpeechSynthesisVoice? {
        let list = voices(for: accent)
        if !identifier.isEmpty, let chosen = list.first(where: { $0.identifier == identifier }) { return chosen }
        if let best = list.first, best.quality != .default { return best }
        return AVSpeechSynthesisVoice(language: accent)
    }

    /// Лучший скачанный голос языка («ru», «de»…) — для книг не на английском
    nonisolated static func bestVoice(language: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) && !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }
}

/// Озвучка слов. Музыку пользователя не останавливает: на время речи приглушает и потом возвращает громкость
final class TextToSpeechManager: NSObject {
    static let shared = TextToSpeechManager()
    /// Читалка читает книгу вслух — сессию после озвучки слова не выключаем, иначе чтение замолкнет
    static var keepsSessionActive = false

    private let synthesizer = AVSpeechSynthesizer()

    /// Включение и выключение аудиосессии — блокирующие вызовы: на главном потоке они дёргали начало слова.
    /// Делаем их по очереди в фоне, в том порядке, в каком попросили
    private static let sessionQueue = DispatchQueue(label: "speech.audio-session", qos: .userInitiated)
    /// Номер последней просьбы озвучить: устаревшие (успели нажать на другое слово) не говорят и не выключают сессию
    private var request = 0
    /// Голос ищется долго — находим один раз на акцент и выбранный голос
    private var cachedVoice: (key: String, voice: AVSpeechSynthesisVoice?)?

    private static var currentVoiceSetting: (accent: String, identifier: String) {
        (UserDefaults.standard.string(forKey: SpeechSettings.accentKey) ?? SpeechSettings.defaultAccent,
         UserDefaults.standard.string(forKey: SpeechSettings.voiceKey) ?? "")
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
        // .playback — слышно и в беззвучном режиме; .duckOthers — чужой звук приглушается, а не останавливается.
        // Сессию здесь не включаем: включённая при запуске, она глушила музыку, даже когда ничего не озвучивалось.
        // Вызов блокирующий — в фоне, в той же очереди, что и включение сессии перед речью
        Self.sessionQueue.async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        #if !WIDGET_EXTENSION
        // Свернули приложение — озвучка слова или предложения замолкает (книга вслух — своя, она играет и в фоне)
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TextToSpeechManager.shared.stop() }
        }
        #endif
    }

    var isSpeaking: Bool { synthesizer.isSpeaking }

    /// Замолчать: и системный голос, и нейросетевой
    func stop() {
        request += 1
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        #if !WIDGET_EXTENSION
        NeuralVoice.shared.stop()
        #endif
    }

    /// Заранее найти голос — первое слово после запуска не ждёт его. Поиск занимает ~0,2 с — в фоне, не на главном потоке
    func prepare() {
        #if !WIDGET_EXTENSION
        NeuralVoice.shared.warmUp()
        #endif
        let (accent, identifier) = Self.currentVoiceSetting
        let key = "\(accent)|\(identifier)"
        Task.detached(priority: .utility) {
            let voice = SpeechSettings.resolveVoice(accent: accent, identifier: identifier)
            await MainActor.run {
                if self.cachedVoice?.key != key { self.cachedVoice = (key, voice) }
            }
        }
    }

    /// slow — медленнее обычного, чтобы расслышать звуки слова.
    /// Скачан и включён нейросетевой голос — говорит он, иначе системный
    func speak(_ text: String, slow: Bool = false) {
        #if !WIDGET_EXTENSION
        if NeuralVoice.shared.speak(text, slow: slow) {
            if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
            return
        }
        #endif
        speakWithSystemVoice(text, slow: slow)
    }

    /// Системный голос iOS — и запасной, когда нейросетевой не справился
    func speakWithSystemVoice(_ text: String, slow: Bool = false) {
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
                let utterance = self.utterance(text)
                if slow { utterance.rate = max(0.15, utterance.rate * 0.55) }
                self.synthesizer.speak(utterance)
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
        let (accent, identifier) = Self.currentVoiceSetting
        let key = "\(accent)|\(identifier)"
        if let cachedVoice, cachedVoice.key == key { return cachedVoice.voice }
        let voice = SpeechSettings.resolveVoice(accent: accent, identifier: identifier)
        cachedVoice = (key, voice)
        return voice
    }

    /// Прослушать конкретный голос (выбор голоса в настройках) — без запоминания
    func preview(_ text: String, voice: AVSpeechSynthesisVoice) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        request += 1
        let current = request
        Self.sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(true)
            Task { @MainActor in
                guard current == self.request else { return }
                let utterance = self.utterance(text)
                utterance.voice = voice
                self.synthesizer.speak(utterance)
            }
        }
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
                guard current == self.request, !self.synthesizer.isSpeaking, !Self.keepsSessionActive else { return }
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
