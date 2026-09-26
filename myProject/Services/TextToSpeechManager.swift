import AVFoundation

final class TextToSpeechManager {
    // Создаем единственный экземпляр класса (паттерн Singleton)
    static let shared = TextToSpeechManager()
    
    // Встроенный синтезатор речи
    private let synthesizer = AVSpeechSynthesizer()
    
    // Приватный инициализатор, чтобы нельзя было создать другие экземпляры
    private init() {
        // Опционально: настройка аудиосессии, чтобы звук работал даже в беззвучном режиме
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    // Метод для озвучивания текста
    func speak(_ text: String) {
        // Если синтезатор уже говорит, останавливаем его перед новым словом
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Устанавливаем английский язык (США), так как в словаре мы озвучиваем word.english
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Можно немного замедлить речь для лучшего понимания (норма — около 0.5)
        utterance.rate = 0.45
        
        // Запускаем озвучку
        synthesizer.speak(utterance)
    }
}
