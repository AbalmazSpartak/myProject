import Foundation
import SwiftData

/// Общая папка приложения и виджета: база слов и настройки, которые нужны обоим
enum AppGroup {
    nonisolated static let id = "group.com.personalteam.myProject"

    /// Настройки, общие с виджетом. Без доступа к группе — обычные настройки приложения
    nonisolated static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    /// Все модели базы. Виджет открывает базу с той же схемой, иначе SwiftData посчитает её другой моделью
    static let schema = Schema([
        Word.self, Category.self, UserProfile.self, WordList.self,
        CommunityTopic.self, TopicAudioClip.self, Book.self
    ])

    /// База в общей папке; nil — группа недоступна (например, не подписано с App Group)
    static var sharedStoreURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)?
            .appending(path: "Library/Application Support/default.store")
    }

    /// Где база лежала до виджета — в папке самого приложения
    static var appStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    // MARK: - Слова, изменённые виджетом

    private static let changedWordsKey = "widget_changed_words"

    /// Ключ слова для виджета и журнала изменений
    static func key(of word: Word) -> String {
        [word.english, word.partOfSpeech, word.russian].joined(separator: "|")
    }

    /// Виджет оценил слово — приложение перечитает его из базы, прежде чем сохранять своё
    static func markChangedByWidget(_ word: Word) {
        var keys = defaults.stringArray(forKey: changedWordsKey) ?? []
        keys.append(key(of: word))
        defaults.set(keys, forKey: changedWordsKey)
    }

    static func takeWordsChangedByWidget() -> [String] {
        let keys = defaults.stringArray(forKey: changedWordsKey) ?? []
        if !keys.isEmpty { defaults.removeObject(forKey: changedWordsKey) }
        return keys
    }

    /// Слово по ключу «english|часть речи|перевод»
    static func word(forKey key: String, in context: ModelContext) -> Word? {
        let parts = key.components(separatedBy: "|")
        guard parts.count == 3 else { return nil }
        let english = parts[0], partOfSpeech = parts[1], russian = parts[2]
        var descriptor = FetchDescriptor<Word>(predicate: #Predicate {
            $0.english == english && $0.partOfSpeech == partOfSpeech && $0.russian == russian
        })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
