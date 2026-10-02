import SwiftUI

/// Раздел главного меню. «Мой профиль» сюда не входит: он всегда сверху, через него открываются настройки
enum MenuSection: String, CaseIterable {
    case flashcards, quiz, cloze, inputCards, dictionary, tetris, race, help

    var title: String {
        switch self {
        case .flashcards: return "Карточки для запоминания"
        case .quiz: return "Викторина"
        case .cloze: return "Слово в контексте"
        case .inputCards: return "Карточки ввода"
        case .dictionary: return "Словарь"
        case .tetris: return "Тетрис слов"
        case .race: return "Гонка слов"
        case .help: return "Справка"
        }
    }

    /// Название на кнопке меню — длинное переносится вручную
    var menuTitle: String {
        self == .flashcards ? "Карточки для\nзапоминания" : title
    }

    var icon: String {
        switch self {
        case .flashcards: return "brain.head.profile"
        case .quiz: return "checkmark.seal.fill"
        case .cloze: return "text.insert"
        case .inputCards: return "keyboard.fill"
        case .dictionary: return "book.fill"
        case .tetris: return "gamecontroller.fill"
        case .race: return "car.fill"
        case .help: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .flashcards: return .blue
        case .quiz: return .purple
        case .cloze: return .pink
        case .inputCards: return .teal
        case .dictionary: return .orange
        case .tetris: return .indigo
        case .race: return .green
        case .help: return .gray
        }
    }

    var screen: ActiveScreen {
        switch self {
        case .flashcards: return .flashcardsFSRS
        case .quiz: return .quiz
        case .cloze: return .cloze
        case .inputCards: return .inputCards
        case .dictionary: return .dictionary
        case .tetris: return .tetris
        case .race: return .race
        case .help: return .help
        }
    }
}

/// Раскрывающаяся группа разделов в меню. Состав групп постоянный, меняются порядок и видимость
enum MenuGroup: String, CaseIterable {
    case cards, miniGames

    var title: String {
        switch self {
        case .cards: return "Карточки"
        case .miniGames: return "Мини-игры"
        }
    }

    var icon: String {
        switch self {
        case .cards: return "square.stack.3d.up.fill"
        case .miniGames: return "gamecontroller.fill"
        }
    }

    var color: Color {
        switch self {
        case .cards: return .blue
        case .miniGames: return .indigo
        }
    }

    var sections: [MenuSection] {
        switch self {
        case .cards: return [.flashcards, .quiz, .cloze]
        case .miniGames: return [.tetris, .race]
        }
    }
}

/// Строка верхнего уровня меню: группа или раздел вне групп
enum MenuItem: Hashable {
    case group(MenuGroup)
    case section(MenuSection)

    var key: String {
        switch self {
        case .group(let group): return "group." + group.rawValue
        case .section(let section): return section.rawValue
        }
    }

    init?(key: String) {
        if key.hasPrefix("group.") {
            guard let group = MenuGroup(rawValue: String(key.dropFirst("group.".count))) else { return nil }
            self = .group(group)
        } else {
            guard let section = MenuSection(rawValue: key) else { return nil }
            self = .section(section)
        }
    }
}

/// Порядок и видимость разделов главного меню (Настройки → Главное меню)
struct MainMenuLayout: Equatable {
    static let storageKey = "main_menu_layout"

    var items: [MenuItem]
    var groupOrder: [MenuGroup: [MenuSection]]
    /// Скрытые группы и разделы — по MenuItem.key
    var hidden: Set<String>

    /// Как меню выглядело до настройки
    static let standard = MainMenuLayout(
        items: [.group(.cards), .group(.miniGames), .section(.inputCards), .section(.dictionary), .section(.help)],
        groupOrder: Dictionary(uniqueKeysWithValues: MenuGroup.allCases.map { ($0, $0.sections) }),
        hidden: []
    )

    func sections(in group: MenuGroup) -> [MenuSection] {
        groupOrder[group] ?? group.sections
    }

    func isHidden(_ item: MenuItem) -> Bool {
        hidden.contains(item.key)
    }

    mutating func setHidden(_ isHidden: Bool, for item: MenuItem) {
        if isHidden { hidden.insert(item.key) } else { hidden.remove(item.key) }
    }

    /// Что показывать в меню: скрытая группа или группа без видимых разделов не показывается
    var visibleItems: [MenuItem] {
        items.filter { item in
            guard !isHidden(item) else { return false }
            if case .group(let group) = item { return !visibleSections(in: group).isEmpty }
            return true
        }
    }

    func visibleSections(in group: MenuGroup) -> [MenuSection] {
        sections(in: group).filter { !isHidden(.section($0)) }
    }
}

// Хранение в @AppStorage одной JSON-строкой
extension MainMenuLayout: RawRepresentable {
    private struct Stored: Codable {
        var items: [String]
        var groups: [String: [String]]
        var hidden: [String]
    }

    /// Сохранённое приводим к текущему набору разделов: новые из обновлений появятся в конце и будут видны
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        let standard = MainMenuLayout.standard
        var items: [MenuItem] = []
        for item in stored.items.compactMap(MenuItem.init(key:)) where !items.contains(item) {
            items.append(item)
        }
        items += standard.items.filter { !items.contains($0) }

        var groupOrder: [MenuGroup: [MenuSection]] = [:]
        for group in MenuGroup.allCases {
            var order: [MenuSection] = []
            for section in (stored.groups[group.rawValue] ?? []).compactMap(MenuSection.init(rawValue:))
            where group.sections.contains(section) && !order.contains(section) {
                order.append(section)
            }
            groupOrder[group] = order + group.sections.filter { !order.contains($0) }
        }
        self.init(items: items, groupOrder: groupOrder, hidden: Set(stored.hidden))
    }

    var rawValue: String {
        let stored = Stored(
            items: items.map(\.key),
            groups: Dictionary(uniqueKeysWithValues: groupOrder.map { ($0.key.rawValue, $0.value.map(\.rawValue)) }),
            hidden: hidden.sorted()
        )
        guard let data = try? JSONEncoder().encode(stored) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
