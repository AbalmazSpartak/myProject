import Foundation

/// Сколько новых слов в день попадает в «На повторение» (профиль → «Выучено сегодня»)
enum DailyNewWords {
    /// 0 — без лимита
    static let limitKey = "new_words_per_day"
    static let defaultLimit = 20
    /// Готовые варианты в шторке; любое другое число задаётся карандашом, 0 — ∞
    static let limitOptions = [5, 7, 10, 15, 20, 30, 40, 60]

    private static let dayKey = "new_words_day"
    private static let countKey = "new_words_count"

    /// Сколько новых слов уже начато сегодня (впервые оценено в карточках); в полночь — заново
    static var introducedToday: Int {
        guard let day = UserDefaults.standard.object(forKey: dayKey) as? Date,
              Calendar.current.isDateInToday(day) else { return 0 }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static func recordIntroduced() {
        let count = introducedToday + 1
        UserDefaults.standard.set(Date(), forKey: dayKey)
        UserDefaults.standard.set(count, forKey: countKey)
        DailyStreak.update()
    }

    /// Сколько новых слов ещё можно начать сегодня; nil — без лимита
    static func allowance(limit: Int) -> Int? {
        limit > 0 ? max(0, limit - introducedToday) : nil
    }
}

/// Сколько слов в одном подходе тренировки (Настройки → «Слов за подход»)
enum SessionLength {
    /// 0 — все слова, по кругу без остановки
    static let key = "session_length"
    static let defaultValue = 20
    static let options = [10, 20, 50, 0]

    static func limited(_ words: [Word], to length: Int) -> [Word] {
        length > 0 ? Array(words.prefix(length)) : words
    }
}
