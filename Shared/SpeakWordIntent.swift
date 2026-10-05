import AppIntents

/// Кнопка 🔊 в виджете «Повторение». Звук из самого виджета не играет — система его сразу усыпляет;
/// интент воспроизведения звука система выполняет в приложении, запуская его в фоне (проверено на iPhone; фоновый режим «Аудио» включён)
struct SpeakWordIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Произнести слово"
    static let isDiscoverable = false

    @Parameter(title: "Текст") var text: String

    init() {}
    init(text: String) { self.text = text }

    @MainActor func perform() async throws -> some IntentResult {
        await TextToSpeechManager.shared.speakFromBackground(text)
        return .result()
    }
}

