import Foundation

/// Номера глав для показа: в начале книги бывают титул, содержание, предисловие — это не «Глава 1».
/// Считаем только разделы, названные главами («CHAPTER I», «Глава 3», «IV.»); если таких нет, нумеруем все по порядку
struct ChapterNumbering {
    /// Номер с единицы для каждого раздела; nil — не глава (титул, содержание)
    let numbers: [Int?]
    /// Сколько всего глав
    let count: Int

    init(titles: [String]) {
        let recognized = titles.map { ParallelText.chapterNumber($0) != nil }
        guard recognized.contains(true) else {
            numbers = titles.indices.map { $0 + 1 }
            count = titles.count
            return
        }
        var next = 0
        numbers = recognized.map { isChapter in
            guard isChapter else { return nil }
            next += 1
            return next
        }
        count = next
    }

    /// Название без слова «Chapter»/«Глава» и номера: «CHAPTER I. Down the Rabbit-Hole» → «Down the Rabbit-Hole».
    /// Остался один номер без названия — nil
    static func cleanTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"^(?:chapter|глава)\s+[\p{L}\d]+\s*[.:—–\-]*\s*"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let range = Range(match.range, in: trimmed) else { return trimmed.isEmpty ? nil : trimmed }
        let rest = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    /// Строка списка глав: «1. Down the Rabbit-Hole»; у титула и содержания — только название
    func listTitle(for index: Int, title: String) -> String {
        guard numbers.indices.contains(index), let number = numbers[index] else { return title }
        guard let clean = Self.cleanTitle(title) else { return "Глава \(number)" }
        return "\(number). \(clean)"
    }

    /// «Глава 2 из 12 · The Pool of Tears»; у титула и содержания — только название
    func label(for index: Int, title: String) -> String {
        guard numbers.indices.contains(index), let number = numbers[index] else { return title }
        let head = "Глава \(number) из \(count)"
        return Self.cleanTitle(title).map { "\(head) · \($0)" } ?? head
    }

    /// Шапка читалки: «Глава 2 · The Pool of Tears»; у титула и содержания — только название
    func headerTitle(for index: Int, title: String) -> String {
        guard numbers.indices.contains(index), let number = numbers[index] else { return title }
        return Self.cleanTitle(title).map { "Глава \(number) · \($0)" } ?? "Глава \(number)"
    }
}
