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

    /// Слова в порядке первого появления в тексте; повторы складываются в `count`
    static func extract(from raw: String) -> [ExtractedWord] {
        let text = cleaned(raw)
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        let sentences = sentenceTokenizer.tokens(for: text.startIndex..<text.endIndex)

        var order: [String] = []
        var found: [String: ExtractedWord] = [:]
        // Слова идут по порядку — предложение ищем, сдвигаясь вперёд, а не перебором всего текста на каждое слово
        var sentenceIndex = 0
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, range in
            guard let tag, !names.contains(tag) else { return true }
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
                lemma = (lemmaTag?.rawValue ?? String(text[range])).lowercased()
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
                order.append(lemma)
            }
            return true
        }
        return order.compactMap { found[$0] }
    }

    /// Словарная форма и часть речи слова, на которое нажали в тексте: «ran» в предложении → «run», «v.»
    static func lemma(of word: String, at range: Range<String.Index>, in sentence: String) -> (lemma: String, partOfSpeech: String) {
        if let contraction = contractionLemma(word) { return (contraction, "modal v.") }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = sentence
        tagger.setLanguage(.english, range: sentence.startIndex..<sentence.endIndex)
        let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased()
        let lexical = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass).0
        let partOfSpeech = lexical.flatMap { partsOfSpeech[$0] } ?? ""
        return (lemma.flatMap { isWordLike($0) ? $0 : nil } ?? word.lowercased(), partOfSpeech)
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
