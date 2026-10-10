import Foundation
import NaturalLanguage

/// Слово, найденное в тексте (скан камерой, фото или вставленный текст)
nonisolated struct ExtractedWord: Identifiable, Hashable, Sendable {
    /// Словарная форма: running → run, children → child
    let lemma: String
    /// Как слово встретилось в тексте впервые
    let surface: String
    /// n., v., adj., adv. — как в мастер-базе
    let partOfSpeech: String
    /// Предложение из текста, где слово выделено <b>…</b> — готовый пример для карточки
    let example: String
    var count: Int

    var id: String { lemma }
    /// Выражение из нескольких слов: give up, a lot of
    var isPhrase: Bool { lemma.contains(" ") }
}

/// Выражение из базы, которое ищется в тексте целиком: «give up», «a lot of», «ice cream»
nonisolated struct PhrasePattern: Sendable {
    let text: String
    let partOfSpeech: String
}

/// Выделяет из текста знаменательные слова (существительные, глаголы, прилагательные, наречия).
/// Имена, названия, числа и служебные слова отбрасываются. Работает и вне главного потока — для больших файлов
nonisolated enum TextWordExtractor {
    private static let partsOfSpeech: [NLTag: String] = [
        .noun: "n.", .verb: "v.", .adjective: "adj.", .adverb: "adv."
    ]
    private static let names: Set<NLTag> = [.personalName, .placeName, .organizationName]
    /// Вспомогательные слова, которые теггер считает глаголами и наречиями, — учить их из текста незачем
    private static let skipped: Set<String> = ["be", "have", "do", "not"]
    private static let maxExampleLength = 220

    /// Убирает следы распознавания: перенос со знаком «-» в конце строки, переводы строк, двойные пробелы
    static func cleaned(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-\n", with: "")
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Слова и выражения в порядке первого появления в тексте; повторы складываются в `count`.
    /// Слова, вошедшие в найденное выражение (gave в «gave up»), отдельно не считаются
    static func extract(from raw: String, phrases: [PhrasePattern] = []) -> [ExtractedWord] {
        var text = cleaned(raw)
        guard !text.isEmpty else { return [] }
        // Обложка, коробка, вывеска — всё заглавными: иначе каждое слово сочтётся сокращением вроде USA и пропустится
        if isMostlyUppercase(text) { text = text.lowercased() }

        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        let sentences = sentenceTokenizer.tokens(for: text.startIndex..<text.endIndex)

        var found: [String: ExtractedWord] = [:]
        var firstSeen: [String: String.Index] = [:]
        var consumed = Set<String.Index>()

        if !phrases.isEmpty {
            let textTokens = Self.tokens(of: text, sentences: sentences)
            for match in findPhrases(phrases, in: textTokens) {
                for index in match.tokens { consumed.insert(textTokens[index].range.lowerBound) }
                let key = normalized(match.phrase.text)
                if found[key] != nil {
                    found[key]?.count += 1
                    continue
                }
                let sentence = sentences.first { $0.contains(match.range.lowerBound) && match.range.upperBound <= $0.upperBound } ?? match.range
                found[key] = ExtractedWord(lemma: key, surface: String(text[match.range]), partOfSpeech: match.phrase.partOfSpeech,
                                           example: example(in: text, sentence: sentence, word: match.range), count: 1)
                firstSeen[key] = match.range.lowerBound
            }
        }

        // Слова идут по порядку — предложение ищем, сдвигаясь вперёд, а не перебором всего текста на каждое слово
        var sentenceIndex = 0
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, range in
            guard let tag, !names.contains(tag), !consumed.contains(range.lowerBound) else { return true }
            var range = range
            let lemma: String
            let pos: String
            if let contraction = contraction(at: range, in: text) {
                // «can't» теггер режет на «ca» + «n't» — берём слово целиком
                range = range.lowerBound..<contraction.end
                lemma = contraction.word
                pos = "modal v."
            } else {
                guard let lexical = partsOfSpeech[tag], isWordLike(String(text[range])) else { return true }
                let lemmaTag = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0
                lemma = correctedLemma(String(text[range])) ?? (lemmaTag?.rawValue ?? String(text[range])).lowercased()
                pos = lexical
                guard isWordLike(lemma), !skipped.contains(lemma) else { return true }
            }
            let surface = String(text[range])

            if found[lemma] != nil {
                found[lemma]?.count += 1
            } else {
                while sentenceIndex < sentences.count, sentences[sentenceIndex].upperBound <= range.lowerBound {
                    sentenceIndex += 1
                }
                let sentence = sentenceIndex < sentences.count && sentences[sentenceIndex].contains(range.lowerBound)
                    ? sentences[sentenceIndex] : range
                found[lemma] = ExtractedWord(lemma: lemma, surface: surface, partOfSpeech: pos,
                                             example: example(in: text, sentence: sentence, word: range), count: 1)
                firstSeen[lemma] = range.lowerBound
            }
            return true
        }
        return found.values.sorted { firstSeen[$0.lemma]! < firstSeen[$1.lemma]! }
    }

    // MARK: - Выражения

    /// Слово текста для поиска выражений: как написано и словарная форма, в нижнем регистре
    private struct Token {
        let surface: String
        let lemma: String
        let range: Range<String.Index>
        let sentence: Int
    }

    private struct PhraseMatch {
        let phrase: PhrasePattern
        /// От первого до последнего слова выражения в тексте, вместе со словами в разрыве
        let range: Range<String.Index>
        /// Номера слов выражения в списке токенов
        let tokens: [Int]
    }

    /// Частицы, которые отрываются от глагола: turn it off, pick the kids up
    private static let separableParticles: Set<String> = [
        "up", "down", "off", "on", "out", "in", "back", "away", "over", "around", "through", "along", "apart"
    ]
    /// Притяжательные слова в выражениях взаимозаменяемы: do your best — do my best, change her mind
    private static let possessives: Set<String> = ["my", "your", "his", "her", "its", "our", "their"]
    /// Сколько слов может стоять между глаголом и частицей
    private static let maxGap = 3

    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    /// Все слова текста подряд, со служебными; выражения ищутся только внутри одного предложения
    private static func tokens(of text: String, sentences: [Range<String.Index>]) -> [Token] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var result: [Token] = []
        var sentence = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            while sentence < sentences.count, sentences[sentence].upperBound <= range.lowerBound {
                sentence += 1
            }
            let surface = normalized(String(text[range]))
            let lemma = correctedLemma(surface) ?? tag.map { normalized($0.rawValue) } ?? surface
            result.append(Token(surface: surface, lemma: lemma, range: range, sentence: sentence))
            return true
        }
        return result
    }

    /// Сначала все возможные совпадения, потом выбор без пересечений: длинные выражения раньше коротких
    /// (look forward to раньше look forward), при равной длине устойчивое выражение раньше фразового глагола
    /// (в «went on holiday» — on holiday, а не go on), дальше — что раньше в тексте
    private static func findPhrases(_ phrases: [PhrasePattern], in tokens: [Token]) -> [PhraseMatch] {
        let patterns = phrases
            .map { (phrase: $0, words: Self.tokens(of: $0.text, sentences: [])) }
            .filter { $0.words.count >= 2 }
        var byFirstWord: [String: [Int]] = [:]
        for (index, pattern) in patterns.enumerated() {
            for key in Set([pattern.words[0].surface, pattern.words[0].lemma]) {
                byFirstWord[key, default: []].append(index)
            }
        }

        var candidates: [(pattern: Int, positions: [Int])] = []
        for start in tokens.indices {
            let first = tokens[start]
            for index in Set((byFirstWord[first.surface] ?? []) + (byFirstWord[first.lemma] ?? [])) {
                if let positions = match(patterns[index], at: start, in: tokens) {
                    candidates.append((index, positions))
                }
            }
        }
        candidates.sort { a, b in
            let lengthA = patterns[a.pattern].words.count, lengthB = patterns[b.pattern].words.count
            if lengthA != lengthB { return lengthA > lengthB }
            let verbA = patterns[a.pattern].phrase.partOfSpeech == "phr. v.", verbB = patterns[b.pattern].phrase.partOfSpeech == "phr. v."
            if verbA != verbB { return !verbA }
            return a.positions[0] < b.positions[0]
        }

        var used = Set<Int>()
        var matches: [PhraseMatch] = []
        for candidate in candidates where used.isDisjoint(with: candidate.positions) {
            used.formUnion(candidate.positions)
            let positions = candidate.positions
            matches.append(PhraseMatch(phrase: patterns[candidate.pattern].phrase,
                                       range: tokens[positions[0]].range.lowerBound..<tokens[positions[positions.count - 1]].range.upperBound,
                                       tokens: positions))
        }
        return matches.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Номера слов текста, составивших выражение, или nil. Разрыв допускается только между фразовым глаголом и его частицей
    private static func match(_ pattern: (phrase: PhrasePattern, words: [Token]), at start: Int, in tokens: [Token]) -> [Int]? {
        let words = pattern.words
        let separable = pattern.phrase.partOfSpeech == "phr. v." && separableParticles.contains(words[1].surface)
        var positions = [start]
        var next = start + 1
        for (offset, word) in words.enumerated().dropFirst() {
            let gap = offset == 1 && separable ? maxGap : 0
            var found: Int?
            var index = next
            while index < tokens.count, index - next <= gap, tokens[index].sentence == tokens[start].sentence {
                if matches(tokens[index], word) {
                    found = index
                    break
                }
                index += 1
            }
            guard let found else { return nil }
            positions.append(found)
            next = found + 1
        }
        return positions
    }

    /// gave ↔ give, is ↔ 's, my ↔ your
    private static func matches(_ token: Token, _ word: Token) -> Bool {
        if possessives.contains(word.surface) { return possessives.contains(token.surface) }
        return token.surface == word.surface || token.lemma == word.surface || token.lemma == word.lemma
    }

    /// Словарная форма и часть речи слова, на которое нажали в тексте: «ran» в предложении → «run», «v.»
    static func lemma(of word: String, at range: Range<String.Index>, in sentence: String) -> (lemma: String, partOfSpeech: String) {
        if let contraction = contractionLemma(word) { return (contraction, "modal v.") }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = sentence
        tagger.setLanguage(.english, range: sentence.startIndex..<sentence.endIndex)
        let lemma = correctedLemma(word) ?? tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased()
        let lexical = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0
        let partOfSpeech = lexical.flatMap { partsOfSpeech[$0] } ?? ""
        return (lemma.flatMap { isWordLike($0) ? $0 : nil } ?? word.lowercased(), partOfSpeech)
    }

    /// Формы, которые теггер iOS приводит к словарной форме неверно: broke → «brake», fell и felt остаются как есть.
    /// dice теггер сводит к die — а в базе die только «умирать»
    private static let lemmaCorrections = [
        "broke": "break", "broken": "break", "fell": "fall", "found": "find", "saw": "see", "felt": "feel", "dice": "dice"
    ]

    /// Почти все буквы заглавные — текст набран капсом, а не состоит из сокращений
    private static func isMostlyUppercase(_ text: String) -> Bool {
        let letters = text.filter(\.isLetter)
        guard letters.count >= 4 else { return false }
        return Double(letters.filter(\.isUppercase).count) >= Double(letters.count) * 0.8
    }

    private static func correctedLemma(_ surface: String) -> String? {
        lemmaCorrections[surface.lowercased()]
    }

    /// Обрывки сокращений, на которые теггер режет «can't», «won't», «shan't», и слово, которым они станут
    private static let contractions = ["ca": "can't", "wo": "won't", "sha": "shall"]

    /// «ca» прямо перед «n't» (или «n’t») — это «can't»: возвращает слово и конец сокращения в тексте
    private static func contraction(at range: Range<String.Index>, in text: String) -> (word: String, end: String.Index)? {
        guard let word = contractions[text[range].lowercased()] else { return nil }
        let rest = text[range.upperBound...]
        for ending in ["n't", "n’t"] where rest.lowercased().hasPrefix(ending) {
            return (word, text.index(range.upperBound, offsetBy: ending.count))
        }
        return nil
    }

    /// Нажатое в книге «can't» / «won't» — сразу словарная форма, а не обрывок «ca»
    static func contractionLemma(_ word: String) -> String? {
        let normalized = word.lowercased().replacingOccurrences(of: "’", with: "'")
        switch normalized {
        case "can't": return "can't"
        case "won't": return "won't"
        case "shan't": return "shall"
        default: return nil
        }
    }

    /// Только латинские буквы (и дефис внутри), минимум 2 буквы, не аббревиатура вроде USA.
    /// Апостроф отсекает обрывки сокращений: n't, 're, 's
    private static func isWordLike(_ token: String) -> Bool {
        guard token.count >= 2, let first = token.first, first.isLetter else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-")
        guard token.unicodeScalars.allSatisfy(allowed.contains) else { return false }
        return token != token.uppercased()
    }

    /// Предложение с выделенным словом; слишком длинное обрезается вокруг слова
    private static func example(in text: String, sentence: Range<String.Index>, word: Range<String.Index>) -> String {
        var before = String(text[sentence.lowerBound..<word.lowerBound])
        var after = String(text[word.upperBound..<sentence.upperBound])
        let half = maxExampleLength / 2
        if before.count > half {
            before = "…" + before.suffix(half).drop { !$0.isWhitespace }
        }
        if after.count > half {
            after = after.prefix(half).reversed().drop { !$0.isWhitespace }.reversed().map(String.init).joined() + "…"
        }
        return (before + "<b>" + String(text[word]) + "</b>" + after).trimmingCharacters(in: .whitespaces)
    }
}
