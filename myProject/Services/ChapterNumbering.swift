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

    /// «Глава 2 из 12 · CHAPTER II. The Pool of Tears»; у титула и содержания — только название
    func label(for index: Int, title: String) -> String {
        guard numbers.indices.contains(index), let number = numbers[index] else { return title }
        return "Глава \(number) из \(count) · \(title)"
    }
}
