import Foundation
@preconcurrency import UserNotifications

/// Ежедневное напоминание позаниматься (Профиль → ⚙️ → «Напоминание»).
/// Мягкое, без чисел и сроков: занятия должны приносить удовольствие, а не быть работой с дедлайнами
enum DailyReminder {
    static let enabledKey = "reminder_enabled"
    /// Время напоминания — секунды от полуночи
    static let timeKey = "reminder_time"
    static let defaultTime = 19 * 3600

    /// По фразе на день недели — так текст каждый день разный
    private static let messages = [
        "Пара слов на английском? ☕️",
        "Пять минут для новых слов — и день прожит не зря",
        "Слова скучают по вам 🙂",
        "Небольшая разминка для памяти?",
        "Время узнать что-нибудь новое",
        "Новое слово в копилку? 📚",
        "Минутка английского — самое время"
    ]

    private static var identifiers: [String] {
        (1...7).map { "daily-reminder-\($0)" }
    }

    /// Спрашивает разрешение на уведомления; false — пользователь отказал
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Повторяющиеся напоминания на каждый день недели в заданное время
    static func schedule(at secondsFromMidnight: Int) {
        cancel()
        let center = UNUserNotificationCenter.current()
        for (weekday, identifier) in zip(1...7, identifiers) {
            let content = UNMutableNotificationContent()
            content.title = "WordLearner"
            content.body = messages[(weekday - 1) % messages.count]
            content.sound = .default

            var time = DateComponents()
            time.weekday = weekday
            time.hour = secondsFromMidnight / 3600
            time.minute = secondsFromMidnight % 3600 / 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger), withCompletionHandler: nil)
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
