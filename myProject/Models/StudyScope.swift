import Foundation

/// Какие слова выбраны для изучения (Настройки → Словари).
/// Слово попадает в изучение, если включены и его уровень, и часть речи, и тема.
/// Храним выключенное, чтобы новые уровни и темы из обновлений словаря были включены по умолчанию.
struct StudyScope: Equatable {
    static let storageKey = "study_scope"

    enum Dimension {
        case level, partOfSpeech, topic
    }

    var disabledLevels: Set<String> = []
    var disabledPartsOfSpeech: Set<String> = []
    var disabledTopics: Set<String> = []
    var includeCustomWords = true

    /// `ignoring` — проверить слово без одного из фильтров (для счётчиков в настройках)
    func includes(_ word: Word, ignoring dimension: Dimension? = nil) -> Bool {
        // Свои слова пользователя управляются одной галочкой «Мои слова»
        if word.isCustom { return includeCustomWords }
        if dimension != .level, disabledLevels.contains(word.cefrLevel) { return false }
        if dimension != .partOfSpeech, disabledPartsOfSpeech.contains(Self.partOfSpeechGroup(of: word)) { return false }
        if dimension != .topic, disabledTopics.contains(Self.topic(of: word)) { return false }
        return true
    }

    var isEverythingEnabled: Bool {
        disabledLevels.isEmpty && disabledPartsOfSpeech.isEmpty && disabledTopics.isEmpty && includeCustomWords
    }

    // MARK: - Группы

    static func topic(of word: Word) -> String {
        word.category?.name ?? ""
    }

    /// Части речи из мастер-базы, объединённые в понятные группы
    static let partOfSpeechGroups: [(name: String, tags: Set<String>)] = [
        ("Существительные", ["n."]),
        ("Глаголы", ["v.", "modal v.", "phr. v."]),
        ("Прилагательные", ["adj."]),
        ("Наречия", ["adv."]),
        ("Местоимения", ["pron."]),
        ("Предлоги", ["prep."]),
        ("Союзы", ["conj."]),
        ("Определители и артикли", ["det.", "art."]),
        ("Числительные", ["num."]),
        ("Частицы", ["part."]),
        ("Междометия", ["excl.", "exclam."]),
        ("Фразы и выражения", ["phr."])
    ]

    /// Пустая строка — часть речи не указана; такие слова фильтр по части речи не отсекает
    static func partOfSpeechGroup(of word: Word) -> String {
        let tag = word.partOfSpeech.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty else { return "" }
        return partOfSpeechGroups.first { $0.tags.contains(tag) }?.name ?? tag
    }

    static func partOfSpeechOrder(_ group: String) -> Int {
        partOfSpeechGroups.firstIndex { $0.name == group } ?? partOfSpeechGroups.count
    }
}

// Хранение в @AppStorage одной JSON-строкой
extension StudyScope: RawRepresentable {
    private struct Stored: Codable {
        var disabledLevels: [String]
        var disabledPartsOfSpeech: [String]
        var disabledTopics: [String]
        var includeCustomWords: Bool
    }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            return nil
        }
        self.init(
            disabledLevels: Set(stored.disabledLevels),
            disabledPartsOfSpeech: Set(stored.disabledPartsOfSpeech),
            disabledTopics: Set(stored.disabledTopics),
            includeCustomWords: stored.includeCustomWords
        )
    }

    var rawValue: String {
        let stored = Stored(
            disabledLevels: disabledLevels.sorted(),
            disabledPartsOfSpeech: disabledPartsOfSpeech.sorted(),
            disabledTopics: disabledTopics.sorted(),
            includeCustomWords: includeCustomWords
        )
        guard let data = try? JSONEncoder().encode(stored) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
