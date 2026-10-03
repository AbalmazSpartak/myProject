import Foundation

/// Сколько разных слов вспомнено правильно по дням (профиль: «Слов за день»).
/// Хранится последние 7 дней: день → ключи слов, одно слово за день считается один раз
enum DailyStudy {
    static let days = 7
    private static let storageKey = "daily_study_words"

    struct Day: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    /// Правильный ответ в тренировке (карточки, карточки ввода, викторина, слово в контексте)
    static func recordCorrect(_ word: Word, now: Date = Date()) {
        var stored = load()
        let today = key(for: now)
        var words = stored[today] ?? []
        let wordKey = [word.english, word.partOfSpeech, word.russian].joined(separator: "|")
        guard !words.contains(wordKey) else { return }
        words.append(wordKey)
        stored[today] = words
        // Старше недели — не нужно
        let kept = Set(recentDates(now: now).map(key(for:)))
        stored = stored.filter { kept.contains($0.key) }
        UserDefaults.standard.set(stored, forKey: storageKey)
    }

    /// Последние 7 дней, сегодняшний последним
    static func recent(now: Date = Date()) -> [Day] {
        let stored = load()
        return recentDates(now: now).reversed().map { Day(date: $0, count: stored[key(for: $0)]?.count ?? 0) }
    }

    private static func load() -> [String: [String]] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [String]] ?? [:]
    }

    /// Сегодня и 6 дней до него, от сегодняшнего назад
    private static func recentDates(now: Date) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private static func key(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
