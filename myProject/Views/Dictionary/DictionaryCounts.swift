import Foundation
import SwiftData

/// Счётчики разделов Словаря — запомненные запросы «сколько», без чтения самих слов
@MainActor
enum DictionaryCounts {
    /// «Общий» — слова без темы: свои и из книг
    static func general(in context: ModelContext) -> Int {
        StudyWords.cachedCount("словарь|общий", #Predicate<Word> { $0.category == nil }, in: context)
    }

    static func mistakes(in context: ModelContext) -> Int {
        StudyWords.count(#Predicate<Word> { $0.isMistake }, in: context)
    }

    static func category(_ category: Category, in context: ModelContext) -> Int {
        let catID = category.id
        return StudyWords.cachedCount("словарь|\(catID)", #Predicate<Word> { $0.category?.id == catID }, in: context)
    }

    /// Встроенные словари основной базы: Oxford 5000 (весь или один уровень) и наши дополнения
    static func builtIn(_ item: DictionaryFilter, in context: ModelContext) -> Int {
        let oxford = StudyScope.oxfordTag
        switch item {
        case .oxford(let level?):
            return StudyWords.cachedCount("словарь|oxford|\(level)",
                                          #Predicate<Word> { !$0.isCustom && $0.tags == oxford && $0.cefrLevel == level }, in: context)
        case .oxford(nil):
            return StudyWords.cachedCount("словарь|oxford", #Predicate<Word> { !$0.isCustom && $0.tags == oxford }, in: context)
        case .extra:
            return StudyWords.cachedCount("словарь|extra", #Predicate<Word> { !$0.isCustom && $0.tags != oxford }, in: context)
        default:
            return 0
        }
    }

    /// «1 слово», «2 слова», «5 слов»
    static func words(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        let noun: String
        if (11...14).contains(lastTwo) {
            noun = "слов"
        } else {
            switch last {
            case 1: noun = "слово"
            case 2...4: noun = "слова"
            default: noun = "слов"
            }
        }
        return "\(count.formatted()) \(noun)"
    }

    /// «1 карточку», «2 карточки», «5 карточек» — после «посмотрели»
    static func cards(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        let noun: String
        if (11...14).contains(lastTwo) {
            noun = "карточек"
        } else {
            switch last {
            case 1: noun = "карточку"
            case 2...4: noun = "карточки"
            default: noun = "карточек"
            }
        }
        return "\(count.formatted()) \(noun)"
    }
}
