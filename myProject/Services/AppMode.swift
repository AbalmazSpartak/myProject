import Foundation

/// Режим приложения: изучение английского — всё как есть; чтение — только библиотека и читалка.
/// Выбирается при первом запуске, меняется в Настройках; данные общие, при смене ничего не пропадает
enum AppMode: String, CaseIterable {
    case learning
    case reading

    static let storageKey = "app_mode"
    /// Вопрос о режиме уже задан
    static let chosenKey = "app_mode_chosen"
    /// Спрашивать режим при каждом запуске
    static let askKey = "app_mode_ask"

    /// Текущий режим — для кода вне экранов (запуск, напоминания, сигналы словаря)
    static var current: AppMode {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppMode.init(rawValue:)) ?? .learning
    }

    var title: String {
        switch self {
        case .learning: "Изучение"
        case .reading: "Чтение"
        }
    }
}
