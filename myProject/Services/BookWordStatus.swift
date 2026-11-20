import Foundation
import SwiftData
import NaturalLanguage

/// Статус слова в тексте книги. Считается по словарю человека: слово не в словаре — статуса нет, страница не пестрит
nonisolated enum BookWordStatus: Int, Sendable {
    /// В словаре, ещё не выучено
    case learning
    /// Выучено: слово повторяется уверенно
    case learned
}

/// Слепок статусов: слово (строчными) → статус. Собирается один раз на главу и передаётся в фон
nonisolated struct BookWordStatusSnapshot: Sendable {
    let statuses: [String: BookWordStatus]

    var isEmpty: Bool { statuses.isEmpty }

    /// Статус по написанию в тексте или по словарной форме («walked» → «walk»)
    func status(surface: String, lemma: String?) -> BookWordStatus? {
        if let found = statuses[surface.lowercased()] { return found }
        if let lemma, let found = statuses[lemma.lowercased()] { return found }
        // Запасной путь без теггера: walked → walk, dogs → dog, stopped → stop, studies → study, making → make
        for base in Self.baseCandidates(of: surface.lowercased()) {
            if let found = statuses[base] { return found }
        }
        return nil
    }

    /// Возможные словарные формы по окончанию. Проверяются по словарю человека, поэтому лишние варианты ничего не окрашивают
    static func baseCandidates(of word: String) -> [String] {
        var result: [String] = []
        func cut(_ suffix: String, add: String = "") {
            guard word.hasSuffix(suffix), word.count > suffix.count + 1 else { return }
            let stem = String(word.dropLast(suffix.count)) + add
            result.append(stem)
            // stopped → stopp → stop
            if let last = stem.last, stem.count > 3, stem.dropLast().last == last, !"aeiou".contains(last) { result.append(String(stem.dropLast())) }
        }
        cut("ies", add: "y")
        cut("ied", add: "y")
        cut("es")
        cut("s")
        cut("ed")
        cut("ed", add: "e")
        cut("d")
        cut("ing")
        cut("ing", add: "e")
        cut("ly")
        cut("er")
        cut("est")
        return result
    }

    /// Словарные формы слов абзаца по началу слова в тексте. Теггер iOS идёт по всему абзацу сразу — это быстрее, чем по слову
    static func lemmas(in text: String) -> [Int: String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var result: [Int: String] = [:]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if let lemma = tag?.rawValue.lowercased() {
                result[NSRange(range, in: text).location] = lemma
            }
            return true
        }
        return result
    }

    /// Слово в словаре — «учу», пока не дошло до устойчивых повторений (состояние «повторение»)
    @MainActor
    static func make(in context: ModelContext) -> BookWordStatusSnapshot {
        let descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.isCustom || $0.reps > 0 || $0.isMistake || !$0.lists.isEmpty })
        var statuses: [String: BookWordStatus] = [:]
        for word in (try? context.fetch(descriptor)) ?? [] {
            let key = word.english.lowercased()
            // Одно написание — несколько значений: «выучено», только если выучены все, что в словаре
            let status: BookWordStatus = word.state == .review ? .learned : .learning
            if let existing = statuses[key] {
                statuses[key] = (existing == .learned && status == .learned) ? .learned : .learning
            } else {
                statuses[key] = status
            }
        }
        return BookWordStatusSnapshot(statuses: statuses)
    }
}
