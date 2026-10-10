import Foundation
import SwiftData

/// Счётчики для меню фильтров тренировок. Считаются одним проходом по словам после загрузки и ответа,
/// а не фильтром всей базы на каждую тему и уровень при каждой перерисовке.
struct WordCounts {
    private var byCategory: [UUID: Int] = [:]
    private var byLevel: [String: Int] = [:]
    private(set) var mistakes = 0
    /// Слова, которым пора на повторение по FSRS, и новые — не больше дневного остатка
    private(set) var due = 0

    init() {}

    init(_ words: [Word], newWordsAllowance: Int? = nil, now: Date = Date()) {
        var newWords = 0
        for word in words {
            if let id = word.category?.id { byCategory[id, default: 0] += 1 }
            byLevel[word.cefrLevel, default: 0] += 1
            if word.isMistake { mistakes += 1 }
            if word.state == .new {
                newWords += 1
            } else if word.dueDate <= now {
                due += 1
            }
        }
        due += newWordsAllowance.map { min($0, newWords) } ?? newWords
    }

    /// Счётчики запросами к базе, без чтения слов: темы и уровни — один раз при открытии тренировки
    init(scope: StudyScope, categories: [Category], newWordsAllowance: Int? = nil, now: Date = Date(), in context: ModelContext) {
        let inScope = StudyWords.scope(scope)
        let scopeKey = StudyWords.key(scope)
        for category in categories {
            let count = StudyWords.categoryCount(category, scope: scope, inScope: inScope, in: context)
            if count > 0 { byCategory[category.id] = count }
        }
        for level in CEFRLevel.allCases {
            let raw = level.rawValue
            byLevel[raw] = StudyWords.cachedCount("уровень|\(scopeKey)|\(raw)",
                                                  StudyWords.all(inScope, #Predicate<Word> { $0.cefrLevel == raw }), in: context)
        }
        refreshProgress(scope: scope, newWordsAllowance: newWordsAllowance, now: now, in: context)
    }

    /// После ответа меняются только ошибки и «На повторение» — три быстрых запроса вместо пересчёта всего
    mutating func refreshProgress(scope: StudyScope, newWordsAllowance: Int? = nil, now: Date = Date(), in context: ModelContext) {
        let inScope = StudyWords.scope(scope)
        mistakes = StudyWords.count(StudyWords.all(inScope, #Predicate<Word> { $0.isMistake }), in: context)
        let newWords = StudyWords.count(StudyWords.all(inScope, StudyWords.isNew), in: context)
        due = StudyWords.count(StudyWords.all(inScope, StudyWords.isDue(now: now)), in: context)
            + (newWordsAllowance.map { min($0, newWords) } ?? newWords)
    }

    func count(for category: Category) -> Int {
        byCategory[category.id, default: 0]
    }

    func count(level: CEFRLevel) -> Int {
        byLevel[level.rawValue, default: 0]
    }
}

extension Array where Element == Word {
    /// Неправильные варианты ответа: несколько случайных слов вместо перемешивания всей базы на каждый вопрос
    func randomWrongAnswers(_ count: Int, excluding correct: String, answer: (Word) -> String) -> [String] {
        var result: [String] = []
        var seen: Set<String> = [correct.lowercased()]
        var attempts = 0
        // Попыток с запасом: часть случайных слов совпадёт с уже выбранными
        while result.count < count, attempts < count * 20, let word = randomElement() {
            attempts += 1
            let option = answer(word)
            guard !option.isEmpty, seen.insert(option.lowercased()).inserted else { continue }
            result.append(option)
        }
        return result
    }
}
