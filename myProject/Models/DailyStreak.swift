import Foundation

/// «Серия дней»: сколько дней подряд выполнена дневная норма новых слов (при ∞ — хотя бы одно слово).
/// Пропущенный день тихо начинает серию заново, рекорд остаётся
enum DailyStreak {
    private static let daysKey = "streak_days"
    private static let bestKey = "streak_best"
    /// Больше года назад для серии не нужно
    private static let keptDays = 400

    /// Засчитывает сегодняшний день, если норма выполнена; вызывается после каждого нового слова
    /// и при открытии профиля — норму могли уменьшить ниже уже пройденного
    static func update(now: Date = Date()) {
        let defaults = UserDefaults.standard
        let limit = defaults.object(forKey: DailyNewWords.limitKey) as? Int ?? DailyNewWords.defaultLimit
        let introduced = DailyNewWords.introducedToday
        guard introduced >= max(limit, 1) else { return }

        var days = activeDays()
        let today = key(for: now)
        guard !days.contains(today) else { return }
        days.insert(today)
        let oldest = key(for: Calendar.current.date(byAdding: .day, value: -keptDays, to: now) ?? now)
        defaults.set(days.filter { $0 >= oldest }.sorted(), forKey: daysKey)
        defaults.set(max(best, current(now: now)), forKey: bestKey)
    }

    /// Дней подряд до сегодня; сегодня ещё не выполнено — серия держится со вчерашнего дня
    static func current(now: Date = Date()) -> Int {
        let days = activeDays()
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: now)
        if !days.contains(key(for: date)) {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        var count = 0
        while days.contains(key(for: date)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return count
    }

    static var best: Int { UserDefaults.standard.integer(forKey: bestKey) }

    /// Последние 7 дней, сегодняшний последним, и выполнена ли в них норма
    static func week(now: Date = Date()) -> [(date: Date, isDone: Bool)] {
        let calendar = Calendar.current
        let days = activeDays()
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (date, days.contains(key(for: date)))
        }
    }

    private static func activeDays() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: daysKey) ?? [])
    }

    /// «2026-10-05»: с нулями, чтобы строки сравнивались как даты
    private static func key(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
