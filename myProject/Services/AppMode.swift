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
    /// «Только читалка»: режима «Обучение» и переключателя режимов нет, приложение — библиотека и читалка
    static let readerOnlyKey = "app_reader_only"

    /// «Только обучение»: читалки и переключателя режимов нет, приложение — слова, практика и словарь
    static let learningOnlyKey = "app_learning_only"

    static var isReaderOnly: Bool { UserDefaults.standard.bool(forKey: readerOnlyKey) }
    static var isLearningOnly: Bool { UserDefaults.standard.bool(forKey: learningOnlyKey) }

    /// Текущий режим — для кода вне экранов (запуск, напоминания, сигналы словаря)
    static var current: AppMode {
        if isReaderOnly { return .reading }
        if isLearningOnly { return .learning }
        return UserDefaults.standard.string(forKey: storageKey).flatMap(AppMode.init(rawValue:)) ?? .learning
    }

    var title: String {
        switch self {
        case .learning: "Изучение"
        case .reading: "Чтение"
        }
    }
}
