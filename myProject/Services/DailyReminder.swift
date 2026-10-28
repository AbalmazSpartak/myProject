import Foundation
@preconcurrency import UserNotifications

/// Ежедневное напоминание позаниматься (Профиль → ⚙️ → «Напоминание»); в «Чтении» — почитать, с последней книгой.
/// Мягкое, без чисел и сроков: занятия должны приносить удовольствие, а не быть работой с дедлайнами
enum DailyReminder {
    static let enabledKey = "reminder_enabled"
    /// Время напоминания — секунды от полуночи
    static let timeKey = "reminder_time"
    static let defaultTime = 19 * 3600
    /// Последняя открытая книга — её называет напоминание в «Чтении»
    private static let bookTitleKey = "reminder_book_title"

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

    private static let readingMessages = [
        "Минутка для чтения? ☕️",
        "Самое время для хорошей книги",
        "Немного чтения для настроения 🙂",
        "Тихий час с книгой?",
        "Пара страниц — и день стал уютнее",
        "Почитаем? 📖",
        "Книга — лучший отдых"
    ]

    /// Через день — с названием последней книги, в остальные дни — общие фразы
    private static func message(weekday: Int) -> String {
        let index = (weekday - 1) % 7
        guard AppMode.current == .reading else { return messages[index % messages.count] }
        if index % 2 == 0, let title = UserDefaults.standard.string(forKey: bookTitleKey), !title.isEmpty {
            let withTitle = ["Продолжим «\(title)»? 📖", "«\(title)» ждёт вас на той же странице", "Ещё пара страниц «\(title)»?"]
            return withTitle[index / 2 % withTitle.count]
        }
        return readingMessages[index % readingMessages.count]
    }

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
            content.body = message(weekday: weekday)
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

    /// Напоминание включено — переставить: сменился режим или книга
    static func refresh() {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        schedule(at: UserDefaults.standard.object(forKey: timeKey) as? Int ?? defaultTime)
    }

    /// Открыта книга — в «Чтении» напоминание зовёт к ней
    static func rememberBook(_ title: String) {
        let short = shortTitle(title)
        guard UserDefaults.standard.string(forKey: bookTitleKey) != short else { return }
        UserDefaults.standard.set(short, forKey: bookTitleKey)
        if AppMode.current == .reading { refresh() }
    }

    /// Книгу удалили — о ней больше не напоминаем
    static func forgetBook(_ title: String) {
        guard UserDefaults.standard.string(forKey: bookTitleKey) == shortTitle(title) else { return }
        UserDefaults.standard.removeObject(forKey: bookTitleKey)
        if AppMode.current == .reading { refresh() }
    }

    /// «Frankenstein; Or, The Modern Prometheus» → «Frankenstein»: в уведомлении — без подзаголовка
    private static func shortTitle(_ title: String) -> String {
        let main = title.split(whereSeparator: { ";:".contains($0) }).first.map(String.init) ?? title
        let trimmed = main.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 40 ? String(trimmed.prefix(39)).trimmingCharacters(in: .whitespaces) + "…" : trimmed
    }
}
