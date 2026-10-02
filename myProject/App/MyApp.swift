import SwiftUI
import SwiftData

@main
struct MyApp: App {
    // Считываем выбранную пользователем тему для мгновенного обновления интерфейса
    @AppStorage("app_theme") private var appTheme: String = "system"
    
    // Создаем ModelContainer один раз и храним его в свойстве
    private var container: ModelContainer
    
    init() {
        do {
            // Инициализируем контейнер для всех используемых моделей данных
            let sharedContainer = try ModelContainer(for: Word.self, Category.self, UserProfile.self, WordList.self)
            self.container = sharedContainer
            
            // Извлекаем контекст в локальную переменную, чтобы безопасно передать его в Task
            let mainContext = sharedContainer.mainContext
            
            // Загружаем words.csv при первом запуске и сливаем его обновления
            Task { @MainActor in
                DataPreloader.syncBundledWords(context: mainContext)
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
        }
    }
    
    // Преобразует строковое значение из настроек в системный тип ColorScheme
    private func colorSchemeForTheme(_ theme: String) -> ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // nil переводит приложение в автоматический режим (по системе)
        }
    }
}
