import SwiftUI
import SwiftData
import WidgetKit

@main
struct MyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    // Создаем ModelContainer один раз и храним его в свойстве
    private var container: ModelContainer

    init() {
        do {
            // База — в общей с виджетом папке: виджет «Повторение» оценивает слова прямо в ней
            let sharedContainer = try ModelContainer(for: AppGroup.schema, configurations: ModelConfiguration(url: Self.storeURL()))
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: reloadWordsChangedByWidget()
            case .background: shareWithWidget()
            default: break
            }
        }
    }

    /// Виджет оценил слова, пока приложение было в фоне. Слова в памяти — со старым расписанием,
    /// и сохранение приложения затёрло бы ответы виджета; повторный запрос подтягивает их из базы
    private func reloadWordsChangedByWidget() {
        let context = container.mainContext
        for key in Set(AppGroup.takeWordsChangedByWidget()) {
            _ = AppGroup.word(forKey: key, in: context)
        }
    }

    /// Уходим в фон: сохранить прогресс и обновить виджет — у слов могло поменяться расписание
    private func shareWithWidget() {
        try? container.mainContext.save()
        AppGroup.defaults.set(studyScope.rawValue, forKey: StudyScope.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// База в общей папке. При первом запуске с виджетом её копия переносится из папки приложения;
    /// старая остаётся как есть — запасной. Нет доступа к общей папке или копирование не удалось — работаем по-старому
    private static func storeURL() -> URL {
        let old = AppGroup.appStoreURL
        guard let shared = AppGroup.sharedStoreURL else { return old }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: shared.path(percentEncoded: false)) || !fileManager.fileExists(atPath: old.path(percentEncoded: false)) {
            return shared
        }
        let folder = shared.deletingLastPathComponent()
        // База — файл и его журналы (-wal, -shm), картинки и обложки — в соседней папке .default_SUPPORT
        let names = ["default.store", "default.store-wal", "default.store-shm", ".default_SUPPORT"]
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            // Сама база — последней: пока её нет, копирование при следующем запуске начнётся заново
            for name in names.reversed() {
                let source = old.deletingLastPathComponent().appending(path: name)
                let target = folder.appending(path: name)
                guard fileManager.fileExists(atPath: source.path(percentEncoded: false)) else { continue }
                try? fileManager.removeItem(at: target)
                try fileManager.copyItem(at: source, to: target)
            }
            return shared
        } catch {
            for name in names { try? fileManager.removeItem(at: folder.appending(path: name)) }
            return old
        }
    }
}
