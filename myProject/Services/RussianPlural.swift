import Foundation

/// Русские числительные с существительными: «1 слово», «2 слова», «5 слов»
enum RussianPlural {
    /// Форма по числу: one — 1, 21; few — 2–4; many — 0, 5–20 и 11–14
    static func form(_ count: Int, one: String, few: String, many: String) -> String {
        let lastTwo = abs(count) % 100, last = abs(count) % 10
        if (11...14).contains(lastTwo) { return many }
        switch last {
        case 1: return one
        case 2...4: return few
        default: return many
        }
    }

    /// «1 слово», «2 слова», «5 слов»
    static func words(_ count: Int) -> String {
        "\(count.formatted()) \(form(count, one: "слово", few: "слова", many: "слов"))"
    }

    /// «1 карточку», «2 карточки», «5 карточек» — после «посмотрели»
    static func cards(_ count: Int) -> String {
        "\(count.formatted()) \(form(count, one: "карточку", few: "карточки", many: "карточек"))"
    }
}
