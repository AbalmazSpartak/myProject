import Foundation

/// Как отвечать в гонке: выбрать перевод из трёх или набрать его на клавиатуре.
/// Режим задаёт создатель комнаты (или сам игрок в одиночку) — он приходит в сообщении start
enum RaceAnswerMode: String, CaseIterable, Identifiable, Codable {
    /// Английское слово → нажать на перевод
    case choice
    /// Русское слово → набрать английское
    case typeEnglish
    /// Английское слово → набрать русский перевод
    case typeRussian

    var id: String { rawValue }

    static let storageKey = "race_answer_mode"

    var isTyping: Bool { self != .choice }

    var title: String {
        switch self {
        case .choice: return "Выбор"
        case .typeEnglish: return "рус → англ"
        case .typeRussian: return "англ → рус"
        }
    }

    /// Что показываем в гонке
    func prompt(for word: RaceWordPayload) -> String {
        self == .typeEnglish ? RaceAnswerCheck.mainTranslation(word.correctAnswer) : word.english
    }

    /// Подходит ли набранное: регистр, ё/е, пробелы и пояснения в скобках не важны; у перевода — любой из вариантов
    func matches(_ typed: String, word: RaceWordPayload) -> Bool {
        let answer = RaceAnswerCheck.normalized(typed)
        guard !answer.isEmpty else { return false }
        switch self {
        case .choice:
            return false
        case .typeEnglish:
            return answer == RaceAnswerCheck.normalized(word.english)
        case .typeRussian:
            return RaceAnswerCheck.variants(word.correctAnswer).contains(answer)
        }
    }

    /// Сколько символов набирать — по нему бот «печатает» дольше длинные слова
    func answerLength(for word: RaceWordPayload) -> Int {
        switch self {
        case .choice: return 0
        case .typeEnglish: return word.english.count
        case .typeRussian: return RaceAnswerCheck.variants(word.correctAnswer).map(\.count).min() ?? word.correctAnswer.count
        }
    }
}

enum RaceAnswerCheck {
    /// «дом, жилище; (разг.) хата» → ["дом", "жилище", "хата"]
    static func variants(_ translation: String) -> [String] {
        translation.split(whereSeparator: { ",;/".contains($0) }).map { normalized(String($0)) }.filter { !$0.isEmpty }
    }

    /// Первый вариант перевода — его показываем в «рус → англ»
    static func mainTranslation(_ translation: String) -> String {
        let first = translation.split(whereSeparator: { ",;".contains($0) }).first.map(String.init) ?? translation
        return first.trimmingCharacters(in: .whitespaces)
    }

    static func normalized(_ text: String) -> String {
        let withoutNotes = text.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
        return withoutNotes.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
