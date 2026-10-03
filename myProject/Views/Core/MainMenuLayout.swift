import SwiftUI

/// Раздел главного меню. «Мой профиль» сюда не входит: он всегда сверху, через него открываются настройки
enum MenuSection: String, CaseIterable {
    case flashcards, quiz, cloze, inputCards, dictionary, tetris, race, help, community, books

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
        case .community: return "Сообщество"
        case .books: return "Книги"
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
        case .community: return "person.3.fill"
        case .books: return "books.vertical.fill"
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
        case .community: return .cyan
        case .books: return .brown
        }
    }

    /// Открывается вкладкой внизу — в лентах «Обзора» и настройке меню не показывается
    var isTab: Bool {
        self == .dictionary
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
        case .community: return .community
        case .books: return .books
        }
    }
}

/// Готовые иконки и цвета для своих групп меню
enum MenuPalette {
    static let icons = [
        "folder.fill", "star.fill", "book.fill", "gamecontroller.fill", "brain.head.profile", "bolt.fill",
        "square.stack.3d.up.fill", "heart.fill", "flag.fill", "graduationcap.fill", "puzzlepiece.fill", "lightbulb.fill"
    ]

    static let colors: [(name: String, color: Color)] = [
        ("blue", .blue), ("purple", .purple), ("pink", .pink), ("red", .red),
        ("orange", .orange), ("green", .green), ("teal", .teal), ("indigo", .indigo)
    ]

    static func color(named name: String) -> Color {
        colors.first { $0.name == name }?.color ?? .blue
    }
}

/// Раскрывающаяся группа разделов в меню: стандартная или созданная пользователем
struct MenuGroup: Identifiable, Hashable {
    /// Стандартные группы — "cards", "inputCards" и "miniGames", свои — UUID
    let id: String
    var name: String
    var icon: String
    var colorName: String
    var sections: [MenuSection]

    var color: Color { MenuPalette.color(named: colorName) }

    static let cards = MenuGroup(id: "cards", name: "Карточки", icon: "square.stack.3d.up.fill",
                                 colorName: "blue", sections: [.flashcards, .quiz])
    static let inputCards = MenuGroup(id: "inputCards", name: "Карточки ввода", icon: "keyboard.fill",
                                      colorName: "teal", sections: [.inputCards, .cloze])
    static let miniGames = MenuGroup(id: "miniGames", name: "Мини-игры", icon: "gamecontroller.fill",
                                     colorName: "indigo", sections: [.tetris, .race])
}

/// Постоянные ленты «Обзора»: место у них своё, в настройке их можно только скрыть
enum FixedRibbon: String, CaseIterable {
    case wordOfDay, collections

    var title: String {
        switch self {
        case .wordOfDay: return "Слово дня"
        case .collections: return "Ваши подборки"
        }
    }

    var icon: String {
        switch self {
        case .wordOfDay: return "bolt.fill"
        case .collections: return "text.book.closed.fill"
        }
    }

    /// Ключ в MainMenuLayout.hidden — рядом с ключами групп и разделов
    var hiddenKey: String { "fixed." + rawValue }
}

/// Строка верхнего уровня меню: группа (по id) или раздел вне групп
enum MenuItem: Hashable {
    case group(String)
    case section(MenuSection)

    var key: String {
        switch self {
        case .group(let id): return "group." + id
        case .section(let section): return section.rawValue
        }
    }

    init?(key: String) {
        if key.hasPrefix("group.") {
            self = .group(String(key.dropFirst("group.".count)))
        } else {
            guard let section = MenuSection(rawValue: key) else { return nil }
            self = .section(section)
        }
    }
}

/// Порядок, группы и видимость разделов на «Обзоре» (Настройки → Ленты «Обзора»): каждая группа — лента;
/// там же — скрытые постоянные ленты (FixedRibbon).
/// Каждый раздел стоит ровно в одном месте: в группе или в общем списке
struct MainMenuLayout: Equatable {
    static let storageKey = "main_menu_layout"

    var items: [MenuItem]
    var groups: [String: MenuGroup]
    /// Скрытые группы и разделы — по MenuItem.key, постоянные ленты — по FixedRibbon.hiddenKey
    var hidden: Set<String>

    /// Меню по умолчанию
    static let standard = MainMenuLayout(
        items: [.group(MenuGroup.cards.id), .group(MenuGroup.inputCards.id), .group(MenuGroup.miniGames.id),
                .section(.dictionary), .section(.books), .section(.help), .section(.community)],
        groups: [MenuGroup.cards.id: .cards, MenuGroup.inputCards.id: .inputCards, MenuGroup.miniGames.id: .miniGames],
        hidden: []
    )

    /// Группы в порядке меню
    var orderedGroups: [MenuGroup] {
        items.compactMap { item in
            if case .group(let id) = item { return groups[id] }
            return nil
        }
    }

    func isHidden(_ item: MenuItem) -> Bool {
        hidden.contains(item.key)
    }

    mutating func setHidden(_ isHidden: Bool, for item: MenuItem) {
        if isHidden { hidden.insert(item.key) } else { hidden.remove(item.key) }
    }

    func isHidden(_ ribbon: FixedRibbon) -> Bool {
        hidden.contains(ribbon.hiddenKey)
    }

    mutating func setHidden(_ isHidden: Bool, for ribbon: FixedRibbon) {
        if isHidden { hidden.insert(ribbon.hiddenKey) } else { hidden.remove(ribbon.hiddenKey) }
    }

    /// Что показывать в меню: скрытая группа или группа без видимых разделов не показывается
    var visibleItems: [MenuItem] {
        items.filter { item in
            guard !isHidden(item) else { return false }
            if case .section(let section) = item, section.isTab { return false }
            if case .group(let id) = item { return !visibleSections(in: id).isEmpty }
            return true
        }
    }

    func visibleSections(in groupID: String) -> [MenuSection] {
        (groups[groupID]?.sections ?? []).filter { !isHidden(.section($0)) && !$0.isTab }
    }

    /// Группа, в которой стоит раздел; nil — раздел в общем списке
    func groupID(of section: MenuSection) -> String? {
        groups.values.first { $0.sections.contains(section) }?.id
    }

    // MARK: - Свои группы

    /// Новая группа — в конец меню, пока пустая (в меню не видна, пока в неё не перенесут разделы)
    mutating func addGroup(name: String, icon: String, colorName: String) {
        let group = MenuGroup(id: UUID().uuidString, name: name, icon: icon, colorName: colorName, sections: [])
        groups[group.id] = group
        items.append(.group(group.id))
    }

    /// Разделы удалённой группы встают в общий список на её место
    mutating func deleteGroup(_ id: String) {
        guard let group = groups[id], let index = items.firstIndex(of: .group(id)) else { return }
        items.replaceSubrange(index...index, with: group.sections.map { .section($0) })
        groups[id] = nil
        hidden.remove(MenuItem.group(id).key)
    }

    /// Переносит раздел в группу (в её конец) или в общий список (в его конец); видимость сохраняется
    mutating func move(_ section: MenuSection, toGroup targetID: String?) {
        // Уже там: nil == nil — раздел и так в общем списке
        guard groupID(of: section) != targetID else { return }
        items.removeAll { $0 == .section(section) }
        for id in groups.keys {
            groups[id]?.sections.removeAll { $0 == section }
        }
        if let targetID {
            groups[targetID]?.sections.append(section)
        } else {
            items.append(.section(section))
        }
    }
}

// Хранение в @AppStorage одной JSON-строкой
extension MainMenuLayout: RawRepresentable {
    private struct StoredGroup: Codable {
        var id: String
        var name: String
        var icon: String
        var color: String
        var sections: [String]
    }

    private struct Stored: Codable {
        var items: [String]
        var menuGroups: [StoredGroup]?
        /// Прошлая версия: только порядок разделов в стандартных группах
        var groups: [String: [String]]?
        var hidden: [String]
    }

    /// Сохранённое приводим в порядок: каждый раздел ровно в одном месте,
    /// новые разделы из обновлений — в конце общего списка и видимы
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }

        var groups: [String: MenuGroup] = [:]
        if let storedGroups = stored.menuGroups {
            for group in storedGroups {
                groups[group.id] = MenuGroup(id: group.id, name: group.name, icon: group.icon, colorName: group.color,
                                             sections: group.sections.compactMap(MenuSection.init(rawValue:)))
            }
        } else {
            // Настройка из прошлой версии: стандартные группы с сохранённым порядком разделов
            for standard in [MenuGroup.cards, MenuGroup.inputCards, MenuGroup.miniGames] {
                var group = standard
                let order = (stored.groups?[standard.id] ?? []).compactMap(MenuSection.init(rawValue:))
                    .filter(standard.sections.contains)
                group.sections = order + standard.sections.filter { !order.contains($0) }
                groups[group.id] = group
            }
        }

        var items: [MenuItem] = []
        var placed: Set<MenuSection> = []
        for item in stored.items.compactMap(MenuItem.init(key:)) where !items.contains(item) {
            switch item {
            case .group(let id):
                guard var group = groups[id] else { continue }
                group.sections = group.sections.filter { placed.insert($0).inserted }
                groups[id] = group
                items.append(item)
            case .section(let section):
                if placed.insert(section).inserted { items.append(item) }
            }
        }
        // Группы, которых нет в порядке, — в конец
        for id in groups.keys.sorted() where !items.contains(.group(id)) {
            groups[id]?.sections.removeAll { !placed.insert($0).inserted }
            items.append(.group(id))
        }
        items += MenuSection.allCases.filter { !placed.contains($0) }.map { .section($0) }

        self.init(items: items, groups: groups, hidden: Set(stored.hidden))
    }

    var rawValue: String {
        let stored = Stored(
            items: items.map(\.key),
            menuGroups: orderedGroups.map {
                StoredGroup(id: $0.id, name: $0.name, icon: $0.icon, color: $0.colorName, sections: $0.sections.map(\.rawValue))
            },
            groups: nil,
            hidden: hidden.sorted()
        )
        guard let data = try? JSONEncoder().encode(stored) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
