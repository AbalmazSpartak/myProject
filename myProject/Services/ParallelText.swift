import Foundation
import NaturalLanguage
import UniformTypeIdentifiers

/// Какие абзацы перевода стоят под каждым абзацем книги. Абзацы перевода — сквозным номером по всей книге:
/// переводчик мог объединить или разделить главы
nonisolated struct BookAlignment: Codable, Sendable {
    struct Span: Codable, Sendable {
        /// Первый абзац перевода (сквозной номер) и сколько их; 0 — у этого абзаца своего перевода нет (он у соседнего)
        var start: Int
        var count: Int
    }

    /// Для каждой главы книги — по абзацу
    var chapters: [[Span]]
}

/// Перевод книги, добавленный пользователем: сопоставление абзацев оригинала и перевода.
/// 1) Текст делится на главы по заголовкам («CHAPTER I», «Глава 1», «I. …»), главы сопоставляются по номерам —
///    предисловие переводчика или оглавление без пары пропускаются.
/// 2) Абзацы внутри главы — по длине (способ Гейла — Черча): перевод длиннее или короче в среднем одинаково,
///    а абзацы переводчик объединяет или делит — это допустимые шаги с небольшим штрафом
nonisolated enum ParallelText {
    /// Абзацы перевода подряд, без деления на главы — как на них ссылается BookAlignment
    static func flatten(_ chapters: [BookChapter]) -> [String] {
        chapters.flatMap(\.paragraphs)
    }

    /// lexicon — английские слова и их русские переводы из основной базы: с ним пары находятся и по смыслу, а не только по длине
    static func align(_ book: [BookChapter], translation: [BookChapter], lexicon: AlignmentLexicon? = nil) -> BookAlignment {
        let original = flatten(book)
        let translated = flatten(translation)
        let originalFeatures = original.map { Features(english: $0, lexicon: lexicon) }
        let translatedFeatures = lexicon == nil ? translated.map { Features(translation: $0, lemmas: []) } : russianFeatures(translated)
        var spans = [BookAlignment.Span](repeating: .init(start: 0, count: 0), count: original.count)

        let pairs = sectionPairs(original: sections(book), translation: sections(translation),
                                 originalCount: original.count, translationCount: translated.count)
        // Перевод в среднем длиннее или короче — по всем сопоставленным главам
        let originalChars = pairs.reduce(0.0) { sum, pair in sum + pair.original.reduce(0.0) { $0 + Double(original[$1].count) } }
        let translatedChars = pairs.reduce(0.0) { sum, pair in sum + pair.translation.reduce(0.0) { $0 + Double(translated[$1].count) } }
        let ratio = originalChars > 0 && translatedChars > 0 ? translatedChars / originalChars : 1

        for pair in pairs {
            // Заголовок главы — отдельно: «CHAPTER I.» + «Down the Rabbit-Hole» в переводе часто одна строка «I. В Кроличьей норке»
            let originalHeading = headingLength(pair.original.map { original[$0] })
            let translatedHeading = headingLength(pair.translation.map { translated[$0] })
            var originalBody = pair.original, translatedBody = pair.translation
            if originalHeading > 0, translatedHeading > 0 {
                spans[pair.original.lowerBound] = .init(start: pair.translation.lowerBound, count: translatedHeading)
                originalBody = pair.original.lowerBound + originalHeading..<pair.original.upperBound
                translatedBody = pair.translation.lowerBound + translatedHeading..<pair.translation.upperBound
            }
            let found = paragraphSpans(original: originalBody.map { originalFeatures[$0] },
                                       translation: translatedBody.map { translatedFeatures[$0] }, ratio: ratio)
            for (offset, span) in found.enumerated() {
                spans[originalBody.lowerBound + offset] = .init(start: translatedBody.lowerBound + span.start, count: span.count)
            }
        }

        var start = 0
        return BookAlignment(chapters: book.map { chapter in
            defer { start += chapter.paragraphs.count }
            return Array(spans[start..<start + chapter.paragraphs.count])
        })
    }

    /// Перевод абзацев главы: nil — абзаца перевода нет
    static func paragraphs(chapter: Int, alignment: BookAlignment, translation: [String]) -> [String?] {
        guard alignment.chapters.indices.contains(chapter) else { return [] }
        return alignment.chapters[chapter].map { span in
            guard span.count > 0, span.start >= 0, span.start + span.count <= translation.count else { return nil }
            return translation[span.start..<span.start + span.count].joined(separator: "\n\n")
        }
    }

    /// «Сдвинуть перевод» с этого абзаца до конца главы: позже (+1) — предыдущий абзац забирает абзац перевода себе,
    /// раньше (−1) — отдаёт свой последний. Так ни один абзац перевода не теряется и не повторяется
    static func shift(_ alignment: BookAlignment, chapter: Int, from paragraph: Int, by delta: Int, translationCount: Int) -> BookAlignment {
        guard alignment.chapters.indices.contains(chapter), alignment.chapters[chapter].indices.contains(paragraph) else { return alignment }
        var result = alignment
        var spans = result.chapters[chapter]
        // Предыдущий абзац главы, у которого есть перевод, — он отдаёт или забирает абзац
        guard let previous = spans[..<paragraph].lastIndex(where: { $0.count > 0 }) else {
            // Это первый абзац с переводом в главе — сдвигаем только начало
            for index in paragraph..<spans.count where spans[index].count > 0 {
                spans[index].start = min(max(spans[index].start + delta, 0), max(translationCount - spans[index].count, 0))
            }
            result.chapters[chapter] = spans
            return result
        }
        // Отдал свой единственный абзац — остаётся без перевода, это видно и поправимо
        spans[previous].count += delta
        for index in paragraph..<spans.count where spans[index].count > 0 {
            spans[index].start = min(max(spans[index].start + delta, 0), max(translationCount - spans[index].count, 0))
        }
        result.chapters[chapter] = spans
        return result
    }

    // MARK: - Главы

    /// Кусок текста от заголовка до заголовка; number — номер главы из заголовка, если он есть
    private struct Section {
        var number: Int?
        var range: Range<Int>
    }

    private struct SectionPair {
        let original: Range<Int>
        let translation: Range<Int>
    }

    /// Деление на главы: границы глав файла и абзацы-заголовки внутри них (Викитека кладёт книгу одной «главой»)
    private static func sections(_ chapters: [BookChapter]) -> [Section] {
        var result: [Section] = []
        var position = 0
        for chapter in chapters {
            var start = position
            var number = chapterNumber(chapter.title)
            for (offset, paragraph) in chapter.paragraphs.enumerated() {
                let index = position + offset
                guard paragraph.count < 90, let found = chapterNumber(paragraph) else { continue }
                // Заголовок в самом начале главы файла — это её же номер
                if index == start, number == nil {
                    number = found
                    continue
                }
                if index > start { result.append(Section(number: number, range: start..<index)) }
                start = index
                number = found
            }
            let end = position + chapter.paragraphs.count
            if end > start { result.append(Section(number: number, range: start..<end)) }
            position = end
        }
        return result
    }

    /// Сколько абзацев в начале главы — её заголовок: строка с номером и, если она без названия, короткая строка названия после неё
    private static func headingLength(_ paragraphs: [String]) -> Int {
        guard let first = paragraphs.first, first.count < 90, chapterNumber(first) != nil else { return 0 }
        // Без номера («CHAPTER I.» → «») — осталось ли название
        let rest = first.replacingOccurrences(of: "^(?:chapter|глава)?\\s*(?:[ivxlc]+|\\d+)\\s*[.):]?\\s*", with: "",
                                              options: [.regularExpression, .caseInsensitive])
        let hasTitle = rest.range(of: "\\p{L}{3,}", options: .regularExpression) != nil
        if !hasTitle, paragraphs.count > 1, paragraphs[1].count < 60, !paragraphs[1].hasSuffix("."), chapterNumber(paragraphs[1]) == nil {
            return 2
        }
        return 1
    }

    /// Номера глав есть с обеих сторон — главы с одинаковым номером в пару, остальное (предисловие, оглавление) без пары.
    /// Номеров нет, но глав поровну — по порядку. Иначе вся книга одним куском
    private static func sectionPairs(original: [Section], translation: [Section], originalCount: Int, translationCount: Int) -> [SectionPair] {
        func numbered(_ sections: [Section]) -> [Int: Range<Int>] {
            var result: [Int: Range<Int>] = [:]
            for section in sections {
                guard let number = section.number else { continue }
                // Одинаковый номер дважды (I в оглавлении и I у главы) — берём более длинный кусок
                if let existing = result[number], existing.count >= section.range.count { continue }
                result[number] = section.range
            }
            return result
        }
        let left = numbered(original), right = numbered(translation)
        let common = Set(left.keys).intersection(right.keys).sorted()
        if common.count >= 2 {
            return common.compactMap { number in
                guard let a = left[number], let b = right[number] else { return nil }
                return SectionPair(original: a, translation: b)
            }
        }
        if original.count == translation.count, original.count > 1 {
            return zip(original, translation).map { SectionPair(original: $0.range, translation: $1.range) }
        }
        return [SectionPair(original: 0..<originalCount, translation: 0..<translationCount)]
    }

    private static let russianOrdinals = [
        "первая": 1, "вторая": 2, "третья": 3, "четвертая": 4, "четвёртая": 4, "пятая": 5, "шестая": 6, "седьмая": 7,
        "восьмая": 8, "девятая": 9, "десятая": 10, "одиннадцатая": 11, "двенадцатая": 12, "тринадцатая": 13,
        "четырнадцатая": 14, "пятнадцатая": 15, "шестнадцатая": 16, "семнадцатая": 17, "восемнадцатая": 18,
        "девятнадцатая": 19, "двадцатая": 20,
    ]

    /// «CHAPTER IV. …», «Chapter 4», «Глава 4», «ГЛАВА ЧЕТВЁРТАЯ», «IV. Билль…», «IV» — номер главы
    static func chapterNumber(_ text: String) -> Int? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            "^(?:chapter|глава)\\s+([ivxlc]+|\\d+)\\b",
            "^([ivxlc]+|\\d+)\\s*[.)]\\s+\\S",
            "^([ivxlc]+|\\d+)\\s*\\.?$",
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range(at: 1), in: line) else { continue }
            let token = String(line[range])
            if let number = Int(token) { return number }
            if let number = romanNumber(token) { return number }
        }
        if let regex = try? NSRegularExpression(pattern: "^глава\\s+(\\p{L}+)", options: .caseInsensitive),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return russianOrdinals[line[range].lowercased()]
        }
        return nil
    }

    private static func romanNumber(_ token: String) -> Int? {
        let values: [Character: Int] = ["i": 1, "v": 5, "x": 10, "l": 50, "c": 100]
        let digits = token.lowercased().compactMap { values[$0] }
        guard digits.count == token.count, !digits.isEmpty else { return nil }
        var total = 0
        for (index, value) in digits.enumerated() {
            total += index + 1 < digits.count && value < digits[index + 1] ? -value : value
        }
        // «I» в начале английской фразы («I. …» бывает и местоимением) — только до 60 глав
        return total > 0 && total <= 60 ? total : nil
    }

    // MARK: - Абзацы

    /// Шаги сопоставления: сколько абзацев оригинала и перевода вместе, и насколько такой шаг обычен (−log вероятности)
    private static let beads: [(original: Int, translation: Int, cost: Double)] = [
        (1, 1, -log(0.89)), (1, 0, -log(0.0099)), (0, 1, -log(0.0099)),
        (2, 1, -log(0.089)), (1, 2, -log(0.089)), (2, 2, -log(0.011)),
        (3, 1, -log(0.005)), (1, 3, -log(0.005)),
    ]

    /// Насколько длины не похожи на перевод друг друга: разница длин относительно ожидаемой (Гейл — Черч)
    private static func lengthCost(_ original: Double, _ translation: Double, ratio: Double) -> Double {
        if original == 0, translation == 0 { return 0 }
        let mean = (original + translation / ratio) / 2
        let delta = (translation / ratio - original) / (6.8 * max(mean, 1)).squareRoot()
        let probability = erfc(abs(delta) / 2.squareRoot())
        return -log(max(probability, 1e-12))
    }

    /// Больше — таблица пути занимает слишком много памяти: кусок без глав сопоставляется просто по доле длины
    private static let maxCells = 1_500_000

    /// Что известно об абзаце для сопоставления: длина, реплика ли это, есть ли вопрос, слова
    struct Features: Sendable {
        let length: Double
        /// Реплика: “…” в оригинале, «— …» в переводе
        let dialogue: Bool
        let question: Bool
        /// Оригинал: для каждого слова из словаря — его русские переводы
        var translations: [Set<String>] = []
        /// Перевод: словарные формы слов
        var lemmas: Set<String> = []

        init(english text: String, lexicon: AlignmentLexicon?) {
            length = Double(text.count)
            dialogue = text.first.map { "“\"‘'".contains($0) } ?? false
            question = text.contains("?")
            if let lexicon { translations = lexicon.translations(of: text) }
        }

        init(translation text: String, lemmas: Set<String>) {
            length = Double(text.count)
            let first = text.first
            dialogue = first.map { "—–-«\"„".contains($0) } ?? false
            question = text.contains("?")
            self.lemmas = lemmas
        }
    }

    /// Словарные формы русских слов — теггером iOS, по всему переводу сразу
    private static func russianFeatures(_ paragraphs: [String]) -> [Features] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        return paragraphs.map { text in
            tagger.string = text
            tagger.setLanguage(.russian, range: text.startIndex..<text.endIndex)
            var lemmas = Set<String>()
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                                 options: [.omitPunctuation, .omitWhitespace, .omitOther]) { tag, range in
                let lemma = (tag?.rawValue ?? String(text[range])).lowercased()
                if lemma.count >= 3 { lemmas.insert(lemma) }
                return true
            }
            return Features(translation: text, lemmas: lemmas)
        }
    }

    /// Насколько шаг не похож на перевод по смыслу: реплика против описания, вопрос без вопроса, общих слов мало
    private static func contentCost(_ original: ArraySlice<Features>, _ translation: ArraySlice<Features>) -> Double {
        guard let a = original.first, let b = translation.first else { return 0 }
        var cost = 0.0
        if a.dialogue != b.dialogue { cost += 1.2 }
        if original.contains(where: \.question) != translation.contains(where: \.question) { cost += 0.8 }
        let words = original.flatMap(\.translations)
        guard words.count >= 2 else { return cost }
        let lemmas = translation.count == 1 ? b.lemmas : translation.reduce(into: Set<String>()) { $0.formUnion($1.lemmas) }
        let found = words.filter { !$0.isDisjoint(with: lemmas) }.count
        // Общих слов хотя бы треть — как у верной пары вольного перевода. В короткой реплике слов мало — и доверия к ним меньше
        let share = Double(found) / Double(words.count)
        let confidence = min(1, Double(words.count) / 4)
        return cost + 7 * confidence * max(0, 1 - share / 0.33)
    }

    /// Абзацы перевода для каждого абзаца главы: start — номер в переводе главы
    private static func paragraphSpans(original: [Features], translation: [Features], ratio: Double) -> [BookAlignment.Span] {
        let n = original.count, m = translation.count
        guard n > 0 else { return [] }
        guard m > 0 else { return original.map { _ in .init(start: 0, count: 0) } }
        guard (n + 1) * (m + 1) <= maxCells else {
            return proportionalSpans(lengths: original.map(\.length), translation.map(\.length))
        }
        let a = original.map(\.length), b = translation.map(\.length)
        // Стоимость лучшего пути до (i, j) и шаг, которым туда пришли
        var cost = [[Double]](repeating: [Double](repeating: .infinity, count: m + 1), count: n + 1)
        var step = [[Int]](repeating: [Int](repeating: -1, count: m + 1), count: n + 1)
        cost[0][0] = 0
        for i in 0...n {
            for j in 0...m where cost[i][j] < .infinity {
                for (index, bead) in beads.enumerated() {
                    let i2 = i + bead.original, j2 = j + bead.translation
                    guard i2 <= n, j2 <= m else { continue }
                    let lengthA = a[i..<i2].reduce(0, +), lengthB = b[j..<j2].reduce(0, +)
                    let total = cost[i][j] + bead.cost + lengthCost(lengthA, lengthB, ratio: ratio)
                        + contentCost(original[i..<i2], translation[j..<j2])
                    if total < cost[i2][j2] {
                        cost[i2][j2] = total
                        step[i2][j2] = index
                    }
                }
            }
        }
        // Путь от конца к началу
        var path: [(i: Int, j: Int, bead: Int)] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            let index = step[i][j]
            guard index >= 0 else { break }
            let bead = beads[index]
            i -= bead.original
            j -= bead.translation
            path.append((i, j, index))
        }
        path.reverse()

        var spans = [BookAlignment.Span](repeating: .init(start: 0, count: 0), count: n)
        var lastWithTranslation: Int?
        var pending: (start: Int, count: Int)?
        for (i, j, index) in path {
            let bead = beads[index]
            if bead.original == 0 {
                // Абзац перевода без пары — к предыдущему абзацу (или к следующему, если это начало главы)
                if let last = lastWithTranslation, spans[last].start + spans[last].count == j {
                    spans[last].count += bead.translation
                } else {
                    pending = pending.map { ($0.start, $0.count + bead.translation) } ?? (j, bead.translation)
                }
                continue
            }
            var start = j, count = bead.translation
            if let waiting = pending, count > 0, waiting.start + waiting.count == j {
                start = waiting.start
                count += waiting.count
                pending = nil
            }
            spans[i] = .init(start: start, count: count)
            if count > 0 { lastWithTranslation = i }
        }
        return spans
    }
}

extension ParallelText {
    /// Абзац перевода достаётся тому абзацу оригинала, на чью долю длины приходится его середина
    nonisolated static func proportionalSpans(lengths original: [Double], _ translated: [Double]) -> [BookAlignment.Span] {
        guard !original.isEmpty else { return [] }
        guard !translated.isEmpty else { return original.map { _ in .init(start: 0, count: 0) } }
        let originalLengths = original.map { max($0, 1) }
        let translatedLengths = translated.map { max($0, 1) }
        let originalTotal = originalLengths.reduce(0, +)
        let translatedTotal = translatedLengths.reduce(0, +)
        var middles: [Double] = []
        var passed = 0.0
        for length in translatedLengths {
            middles.append((passed + length / 2) / translatedTotal)
            passed += length
        }
        var result: [BookAlignment.Span] = []
        var next = 0
        var end = 0.0
        for (index, length) in originalLengths.enumerated() {
            end += length / originalTotal
            let start = next
            while next < translatedLengths.count, index == original.count - 1 || middles[next] <= end { next += 1 }
            result.append(.init(start: start, count: next - start))
        }
        return result
    }
}

/// Английское слово → русские переводы из основной базы (words.csv) — подсказка, какие абзацы — пара
nonisolated struct AlignmentLexicon: Sendable {
    private let entries: [String: Set<String>]

    init(entries: [String: Set<String>]) {
        self.entries = entries
    }

    var isEmpty: Bool { entries.isEmpty }

    static func isStopWord(_ word: String) -> Bool { stopWords.contains(word) }

    /// Частые слова есть почти в каждом абзаце — по ним пару не узнать
    private static let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "at", "for", "with", "is", "was", "be", "been", "are",
        "were", "he", "she", "it", "they", "i", "you", "we", "her", "his", "him", "them", "me", "my", "your", "our", "their",
        "this", "that", "what", "which", "who", "said", "say", "not", "no", "yes", "so", "as", "all", "very", "if", "then",
        "there", "here", "do", "did", "had", "have", "has", "would", "could", "will", "shall", "one", "out", "up", "down",
    ]

    /// words.csv: слово, часть речи, транскрипция, перевод (варианты через запятую) — нужны первый и четвёртый столбцы
    static func load(_ url: URL) -> AlignmentLexicon? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var entries: [String: Set<String>] = [:]
        for line in text.split(separator: "\n").dropFirst() {
            let fields = csvFields(String(line))
            guard fields.count > 3 else { continue }
            let english = fields[0].lowercased().trimmingCharacters(in: .whitespaces)
            guard !english.contains(" "), !stopWords.contains(english) else { continue }
            // «ловить, успевать (на транспорт)» → ловить, успевать: первое слово каждого варианта, без пояснений в скобках
            let plain = fields[3].replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
            for variant in plain.split(whereSeparator: { ",;".contains($0) }) {
                let words = variant.split(separator: " ").map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
                for word in words where word.count >= 3 { entries[english, default: []].insert(word) }
            }
        }
        return AlignmentLexicon(entries: entries)
    }

    /// Переводы слов абзаца: для слова — форма из словаря (dogs → dog, walked → walk)
    func translations(of text: String) -> [Set<String>] {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z]+") else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let word = ns.substring(with: match.range).lowercased()
            guard word.count >= 3, !Self.stopWords.contains(word) else { return nil }
            for key in Self.forms(of: word) {
                if let found = entries[key] { return found }
            }
            return nil
        }
    }

    private static func forms(of word: String) -> [String] {
        var result = [word]
        for (suffix, replacement) in [("ies", "y"), ("es", ""), ("s", ""), ("ied", "y"), ("ed", ""), ("ed", "e"), ("ing", ""), ("ing", "e"), ("ly", "")]
        where word.hasSuffix(suffix) && word.count > suffix.count + 2 {
            result.append(String(word.dropLast(suffix.count)) + replacement)
        }
        return result
    }

    /// Строка CSV: поля через запятую, в кавычках — с запятыми внутри
    private static func csvFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var quoted = false
        var iterator = line.makeIterator()
        while let character = iterator.next() {
            if character == "\"" {
                quoted.toggle()
            } else if character == ",", !quoted {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        fields.append(current)
        return fields
    }
}

extension UTType {
    /// FB2 — частый формат русских книг; системе он неизвестен, тип — по расширению
    static let fictionBook = UTType(filenameExtension: "fb2") ?? .xml
    /// Файлы, из которых получается книга: EPUB, FB2 (и FB2 в ZIP), обычный текст
    static let bookFiles: [UTType] = [.epub, .fictionBook, .zip, .plainText]
}

extension Book {
    var hasTranslation: Bool { translationData != nil }

    /// Главы перевода; пусто — перевода нет
    var translationChapters: [BookChapter] {
        translationData.flatMap { try? JSONDecoder().decode([BookChapter].self, from: $0) } ?? []
    }

    var alignment: BookAlignment? {
        alignmentData.flatMap { try? JSONDecoder().decode(BookAlignment.self, from: $0) }
    }

    /// nil — убрать перевод
    func setTranslation(_ chapters: [BookChapter]?) {
        guard let chapters else {
            translationData = nil
            alignmentData = nil
            return
        }
        translationData = try? JSONEncoder().encode(chapters)
        alignmentData = try? JSONEncoder().encode(ParallelText.align(self.chapters, translation: chapters))
    }
}
