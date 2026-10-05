import Foundation

/// Оценки слов по дням (профиль: график «Снова / Трудно / Хорошо / Легко»).
/// Хранится последние 7 дней: день → слово → оценка; одно слово за день считается один раз, по первой оценке.
/// «Всего» — счётчики за всё время, растут вместе с днями
enum DailyStudy {
    static let days = 7
    private static let storageKey = "daily_study_ratings"
    private static let totalsKey = "daily_study_totals"
    /// До оценок хранились только вспомненные слова, без оценки, — на графике их нет, хранилище удаляется
    private static let legacyKey = "daily_study_words"

    struct Day: Identifiable {
        let date: Date
        let counts: [FSRSRating: Int]
        var id: Date { date }

        func count(_ rating: FSRSRating) -> Int { counts[rating] ?? 0 }
    }

    /// Ответ в тренировке. Карточки для запоминания передают свою оценку,
    /// остальные режимы: верно — «Хорошо», ошибка — «Снова»
    static func record(_ word: Word, rating: FSRSRating, now: Date = Date()) {
        moveToAppGroup()
        var stored = load()
        let today = key(for: now)
        var words = stored[today] ?? [:]
        let wordKey = [word.english, word.partOfSpeech, word.russian].joined(separator: "|")
        guard words[wordKey] == nil else { return }
        words[wordKey] = rating.rawValue
        stored[today] = words
        // Старше недели — не нужно
        let kept = Set(recentDates(now: now).map(key(for:)))
        stored = stored.filter { kept.contains($0.key) }
        AppGroup.defaults.set(stored, forKey: storageKey)

        var totals = loadTotals()
        totals[String(rating.rawValue), default: 0] += 1
        AppGroup.defaults.set(totals, forKey: totalsKey)
    }

    /// Последние 7 дней, сегодняшний последним
    static func recent(now: Date = Date()) -> [Day] {
        UserDefaults.standard.removeObject(forKey: legacyKey)
        moveToAppGroup()
        let stored = load()
        return recentDates(now: now).reversed().map { date in
            let dayKey = key(for: date)
            let rated = stored[dayKey] ?? [:]
            var counts: [FSRSRating: Int] = [:]
            for raw in rated.values {
                if let rating = FSRSRating(rawValue: raw) { counts[rating, default: 0] += 1 }
            }
            return Day(date: date, counts: counts)
        }
    }

    /// Сколько слов получили каждую оценку за всё время
    static func totals() -> [FSRSRating: Int] {
        var result: [FSRSRating: Int] = [:]
        for (raw, count) in loadTotals() {
            if let value = Int(raw), let rating = FSRSRating(rawValue: value) { result[rating] = count }
        }
        return result
    }

    /// Оценки хранились в настройках приложения; теперь — в общих с виджетом, чтобы его ответы попадали в график
    private static func moveToAppGroup() {
        let old = UserDefaults.standard
        guard AppGroup.defaults != old else { return }
        for key in [storageKey, totalsKey] {
            guard let value = old.object(forKey: key) else { continue }
            if AppGroup.defaults.object(forKey: key) == nil { AppGroup.defaults.set(value, forKey: key) }
            old.removeObject(forKey: key)
        }
    }

    private static func load() -> [String: [String: Int]] {
        AppGroup.defaults.dictionary(forKey: storageKey) as? [String: [String: Int]] ?? [:]
    }

    private static func loadTotals() -> [String: Int] {
        AppGroup.defaults.dictionary(forKey: totalsKey) as? [String: Int] ?? [:]
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

extension FSRSRating: CaseIterable {
    static let allCases: [FSRSRating] = [.again, .hard, .good, .easy]

    var title: String {
        switch self {
        case .again: return "Снова"
        case .hard: return "Трудно"
        case .good: return "Хорошо"
        case .easy: return "Легко"
        }
    }
}
