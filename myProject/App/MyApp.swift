import SwiftUI
import SwiftData

@main
struct MyApp: App {
    // Создаем ModelContainer один раз и храним его в свойстве
    private var container: ModelContainer
    
    init() {
        do {
            // Инициализируем контейнер для всех используемых моделей данных
            let sharedContainer = try ModelContainer(for: Word.self, Category.self, UserProfile.self, WordList.self, CommunityTopic.self, TopicAudioClip.self)
            self.container = sharedContainer
            
            // Извлекаем контекст в локальную переменную, чтобы безопасно передать его в Task
            let mainContext = sharedContainer.mainContext
            
            // Загружаем words.csv при первом запуске и сливаем его обновления
            Task { @MainActor in
                DataPreloader.syncBundledWords(context: mainContext)
                DataPreloader.resetImagesIfSourcesChanged(context: mainContext)
            }
        } catch {
            fatalError("Не удалось запустить хранилище SwiftData: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContext(container.mainContext)
                .appThemedColorScheme()
                // Текст растёт по «Размеру текста» iPhone, но не до самых огромных размеров, где ломаются шапки и карточки
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }
}
