import Foundation
import SwiftData

/// Слово в теме сообщества: только пара «английский — русский», в словарь попадает по кнопке «Добавить»
struct TopicWord: Codable, Hashable, Identifiable {
    var id = UUID()
    var english: String
    var russian: String
}

/// Тема сообщества: раздел («Английский по кино», «Грамматика» …), заголовок, текст и слова.
/// Пока хранится только на этом телефоне; общие для всех темы появятся с CloudKit
@Model
final class CommunityTopic {
    var id: UUID = UUID()
    var section: String
    var title: String
    var text: String
    var words: [TopicWord] = []
    var createdAt: Date = Date()

    init(section: String, title: String, text: String, words: [TopicWord]) {
        self.section = section
        self.title = title
        self.text = text
        self.words = words
    }
}

enum CommunitySections {
    /// Разделы, которые есть всегда — даже без тем; свои разделы появляются вместе с первой темой в них
    static let builtIn = ["Английский по кино", "Подборки слов"]

    /// Встроенные — первыми, свои — по алфавиту
    static func all(from topics: [CommunityTopic]) -> [String] {
        let custom = Set(topics.map(\.section)).subtracting(builtIn)
        return builtIn + custom.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

// MARK: - Слова темы → в свой словарь

@MainActor
extension CommunityTopic {
    /// Слова темы попадают в свой словарь с названием темы (тот же, если такой уже есть).
    /// Слово из базы с тем же переводом добавляется ссылкой, иначе — своим словом
    @discardableResult
    func addToDictionary(_ items: [TopicWord], context: ModelContext) -> WordList {
        let list = targetList(context: context)
        let allWords = context.fetchAllWords()
        for item in items {
            let english = item.english.trimmingCharacters(in: .whitespaces)
            let russian = item.russian.trimmingCharacters(in: .whitespaces)
            guard !english.isEmpty, !russian.isEmpty else { continue }

            let sameEnglish = allWords.filter { $0.english.caseInsensitiveCompare(english) == .orderedSame }
            if let existing = sameEnglish.first(where: { Self.translation(russian, matches: $0.russian) }) {
                if !existing.lists.contains(where: { $0.id == list.id }) {
                    existing.lists.append(list)
                }
            } else {
                // Другое значение известного слова — берём его уровень; совсем новое слово — A1
                let word = Word(english: english, russian: russian,
                                cefrLevel: sameEnglish.first?.cefrLevel ?? CEFRLevel.a1.rawValue,
                                partOfSpeech: sameEnglish.first?.partOfSpeech ?? "", isCustom: true)
                context.insert(word)
                word.lists.append(list)
            }
        }
        try? context.save()
        return list
    }

    /// Слово уже есть в словаре этой темы
    func isAdded(_ item: TopicWord, lists: [WordList]) -> Bool {
        guard let list = Self.list(named: title, in: lists) else { return false }
        return list.words.contains {
            $0.english.caseInsensitiveCompare(item.english.trimmingCharacters(in: .whitespaces)) == .orderedSame
                && Self.translation(item.russian.trimmingCharacters(in: .whitespaces), matches: $0.russian)
        }
    }

    private func targetList(context: ModelContext) -> WordList {
        let lists = (try? context.fetch(FetchDescriptor<WordList>())) ?? []
        if let existing = Self.list(named: title, in: lists) { return existing }
        let list = WordList(name: title.trimmingCharacters(in: .whitespaces))
        context.insert(list)
        return list
    }

    private static func list(named name: String, in lists: [WordList]) -> WordList? {
        let name = name.trimmingCharacters(in: .whitespaces)
        return lists.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
    }

    /// «оправдывать» совпадает с «оправдывать, обосновывать»: сверяем с каждым вариантом перевода; «ё» = «е»
    private static func translation(_ russian: String, matches stored: String) -> Bool {
        let wanted = normalized(russian)
        return stored.split(separator: ",").contains { normalized(String($0)) == wanted }
    }

    private static func normalized(_ russian: String) -> String {
        russian.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "ё", with: "е")
    }
}
