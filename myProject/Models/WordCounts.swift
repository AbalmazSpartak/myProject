import Foundation

/// Счётчики для меню фильтров тренировок. Считаются одним проходом по словам после загрузки и ответа,
/// а не фильтром всей базы на каждую тему и уровень при каждой перерисовке.
struct WordCounts {
    private var byCategory: [UUID: Int] = [:]
    private var byLevel: [String: Int] = [:]
    private(set) var mistakes = 0
    /// Новые слова и слова, которым пора на повторение по FSRS
    private(set) var due = 0

    init() {}

    init(_ words: [Word], now: Date = Date()) {
        for word in words {
            if let id = word.category?.id { byCategory[id, default: 0] += 1 }
            byLevel[word.cefrLevel, default: 0] += 1
            if word.isMistake { mistakes += 1 }
            if word.state == .new || word.dueDate <= now { due += 1 }
        }
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
