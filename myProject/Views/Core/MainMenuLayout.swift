import SwiftUI

/// Раздел главного меню. «Мой профиль» сюда не входит: он всегда сверху, через него открываются настройки
enum MenuSection: String, CaseIterable {
    case flashcards, quiz, cloze, inputCards, dictionary, tetris, race, help, community, books, polyglot, review, schulte, speak

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
        case .polyglot: return "Step by Step"
        case .review: return "Повторение"
        case .schulte: return "Таблицы Шульте"
        case .speak: return "Произнеси"
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
        case .polyglot: return "character.bubble.fill"
        case .review: return "arrow.triangle.2.circlepath"
        case .schulte: return "square.grid.3x3.fill"
        case .speak: return "mic.fill"
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
        case .polyglot: return .red
        case .review: return .mint
        case .schulte: return .cyan
        case .speak: return .orange
        }
    }

    /// Подпись в «Фокусе дня»
    var focusHint: String {
        switch self {
        case .flashcards: return "Слова, которым пора на повторение, и новые — по дневной норме"
        case .quiz: return "Выберите правильный перевод из четырёх"
        case .cloze: return "Вставьте пропущенное слово в пример"
        case .inputCards: return "Напечатайте перевод сами"
        case .dictionary: return "Все слова, темы и ваши словари"
        case .tetris: return "Собирайте линии, отвечая на слова"
        case .race: return "Соревнуйтесь с друзьями рядом"
        case .help: return "Как устроены разделы приложения"
        case .community: return "Темы с текстом и словами"
        case .books: return "Читайте книги и сохраняйте слова"
        case .polyglot: return "Грамматика по схемам: составьте фразу из карточек"
        case .review: return "Прогон пройденных слов без сдвига расписания"
        case .schulte: return "Находите числа по порядку — внимание и боковое зрение для быстрого чтения"
        case .speak: return "Скажите слово — телефон проверит, понятно ли звучит"
        }
    }

    /// Открывается вкладкой внизу — на «Обзоре» и в его настройке не показывается.
    /// «Сообщество» тоже вкладка, но его можно поставить в «Фокус дня» и «Быстрый доступ» — к темам часто нужен короткий путь
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
        case .polyglot: return .polyglot
        case .review: return .review
        case .schulte: return .schulte
        case .speak: return .speak
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

/// Что показывать на «Обзоре» (Настройки → «Обзор»): раздел «Фокуса дня», плитки «Быстрого доступа»,
/// видны ли «Слово дня» и «Ваши подборки»
struct OverviewLayout: Equatable {
    static let storageKey = "overview_layout"

    var focus: MenuSection
    var quickAccess: [MenuSection]
    var showsWordOfDay: Bool
    var showsCollections: Bool

    static let standard = OverviewLayout(focus: .flashcards, quickAccess: [.inputCards, .quiz, .tetris, .cloze],
                                         showsWordOfDay: true, showsCollections: true)

    /// Разделы, которые можно поставить на «Обзор»: всё, кроме вкладок внизу
    static let choices = MenuSection.allCases.filter { !$0.isTab }
}

// Хранение в @AppStorage одной JSON-строкой
extension OverviewLayout: RawRepresentable {
    private struct Stored: Codable {
        var focus: String
        var quickAccess: [String]
        var showsWordOfDay: Bool
        var showsCollections: Bool
    }

    /// Разделы, которых больше нет в приложении, пропускаем
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        let focus = MenuSection(rawValue: stored.focus).flatMap { Self.choices.contains($0) ? $0 : nil }
        self.init(focus: focus ?? Self.standard.focus,
                  quickAccess: stored.quickAccess.compactMap(MenuSection.init(rawValue:)).filter(Self.choices.contains),
                  showsWordOfDay: stored.showsWordOfDay,
                  showsCollections: stored.showsCollections)
    }

    var rawValue: String {
        let stored = Stored(focus: focus.rawValue, quickAccess: quickAccess.map(\.rawValue),
                            showsWordOfDay: showsWordOfDay, showsCollections: showsCollections)
        guard let data = try? JSONEncoder().encode(stored) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
