import Foundation

/// Слова, отложенные для тренировки «Произнеси» — из карточки слова в читалке.
/// Хранятся просто строками: слово из книги может не быть в словаре
enum PronunciationQueue {
    struct Entry: Codable, Equatable {
        let english: String
        var russian: String
        var transcription: String
    }

    private static let key = "speak_saved_words"

    static func entries() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    private static func save(_ entries: [Entry]) {
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) }
    }

    static func contains(_ english: String) -> Bool {
        entries().contains { $0.english.caseInsensitiveCompare(english) == .orderedSame }
    }

    static func add(_ english: String, russian: String, transcription: String) {
        var list = entries()
        guard !list.contains(where: { $0.english.caseInsensitiveCompare(english) == .orderedSame }) else { return }
        list.append(Entry(english: english, russian: russian, transcription: transcription))
        save(list)
    }

    static func remove(_ english: String) {
        save(entries().filter { $0.english.caseInsensitiveCompare(english) != .orderedSame })
    }
}
