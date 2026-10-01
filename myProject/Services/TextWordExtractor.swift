import Foundation
import NaturalLanguage

/// Слово, найденное в тексте (скан камерой, фото или вставленный текст)
struct ExtractedWord: Identifiable, Hashable, Sendable {
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
/// Имена, названия, числа и служебные слова отбрасываются.
enum TextWordExtractor {
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
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, range in
            guard let tag, !names.contains(tag), let pos = partsOfSpeech[tag] else { return true }
            let surface = String(text[range])
            guard isWordLike(surface) else { return true }

            let lemmaTag = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0
            let lemma = (lemmaTag?.rawValue ?? surface).lowercased()
            guard isWordLike(lemma), !skipped.contains(lemma) else { return true }

            if found[lemma] != nil {
                found[lemma]?.count += 1
            } else {
                let sentence = sentences.first { $0.contains(range.lowerBound) } ?? range
                found[lemma] = ExtractedWord(lemma: lemma, surface: surface, partOfSpeech: pos,
                                             example: example(in: text, sentence: sentence, word: range), count: 1)
                order.append(lemma)
            }
            return true
        }
        return order.compactMap { found[$0] }
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
