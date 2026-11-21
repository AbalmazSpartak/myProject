import Foundation

/// Дубль или другое издание: сравнение новой книги с библиотекой. Отпечаток считается на лету — в базе ничего не хранится
nonisolated enum BookDuplicates {
    /// Что нашли среди книг библиотеки
    enum Verdict: Equatable, Sendable {
        case none
        /// Та же книга: текст совпадает почти целиком
        case duplicate
        /// Похоже, но текст другой: другое издание или перевод
        case edition
    }

    /// Результат поиска: какая книга библиотеки похожа и насколько (0…1)
    struct Match: Sendable {
        let index: Int
        let verdict: Verdict
        let similarity: Double
    }

    /// Абзацы короче этого в сравнении не участвуют: «Глава 1», эпиграфы и «***» у разных изданий разные
    static let minimumLength = 25

    /// Строчные буквы и цифры, без пробелов и знаков: «Hello,  World!» и «hello world» — одно и то же
    static func normalized(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// Отпечатки абзацев (FNV-1a, 64 бита): одинаковые абзацы дают одинаковое число при любом запуске
    static func fingerprint(_ chapters: [BookChapter]) -> Set<UInt64> {
        var result = Set<UInt64>()
        for chapter in chapters {
            for paragraph in chapter.paragraphs {
                let text = normalized(paragraph)
                guard text.count >= minimumLength else { continue }
                var hash: UInt64 = 0xcbf29ce484222325
                for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
                result.insert(hash)
            }
        }
        return result
    }

    /// Доля общих абзацев от большей из двух книг: 1 — одинаковые, 0 — ничего общего
    static func similarity(_ first: Set<UInt64>, _ second: Set<UInt64>) -> Double {
        let larger = max(first.count, second.count)
        guard larger > 0 else { return 0 }
        return Double(first.intersection(second).count) / Double(larger)
    }

    /// Решение по одной паре книг
    static func verdict(similarity: Double, sameTitle: Bool) -> Verdict {
        if similarity >= 0.97 { return .duplicate }
        if similarity >= 0.5 || sameTitle { return .edition }
        return .none
    }

    /// Книга из библиотеки в виде, удобном для фона: без ссылок на базу
    struct Candidate: Sendable {
        let title: String
        let author: String
        let paragraphCount: Int
        let chaptersData: Data
    }

    /// Сравнить новую книгу со всеми: берём самую похожую. Книги, у которых нет ничего общего по названию и размеру, не разбираем вовсе
    static func find(_ parsed: ParsedBook, among candidates: [Candidate]) -> Match? {
        let newPrint = fingerprint(parsed.chapters)
        let newCount = parsed.chapters.reduce(0) { $0 + $1.paragraphs.count }
        let newTitle = normalized(parsed.title)
        var best: Match?
        for (index, candidate) in candidates.enumerated() {
            let sameTitle = !newTitle.isEmpty && normalized(candidate.title) == newTitle
            let ratio = Double(max(candidate.paragraphCount, 1)) / Double(max(newCount, 1))
            guard sameTitle || (0.5...2.0).contains(ratio) else { continue }
            let chapters = (try? JSONDecoder().decode([BookChapter].self, from: candidate.chaptersData)) ?? []
            let score = similarity(newPrint, fingerprint(chapters))
            let result = verdict(similarity: score, sameTitle: sameTitle)
            guard result != .none else { continue }
            if best == nil || score > best!.similarity { best = Match(index: index, verdict: result, similarity: score) }
        }
        return best
    }
}
