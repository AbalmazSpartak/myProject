import Foundation

/// Сообщения об ошибках во встроенных словах: очередь на телефоне и отправка на сервер «Гонки слов» (POST /report).
/// Нет интернета — сообщение ждёт в очереди и уходит при следующем открытии приложения
enum WordReports {
    /// Что не так в слове
    enum Field: String, CaseIterable, Identifiable, Codable {
        case translation, transcription, example, level, partOfSpeech, topic, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .translation: return "Перевод"
            case .transcription: return "Транскрипция"
            case .example: return "Пример"
            case .level: return "Уровень"
            case .partOfSpeech: return "Часть речи"
            case .topic: return "Тема"
            case .other: return "Другое"
            }
        }
    }

    struct Report: Codable, Identifiable {
        var id = UUID().uuidString
        var created = ISO8601DateFormatter().string(from: Date())
        let word: String
        let partOfSpeech: String
        let field: String
        let comment: String
        /// Как слово выглядит сейчас — чтобы было видно, что исправлять
        let current: [String: String]
        var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private static let queueKey = "word_reports_queue"
    private static let endpoint = OnlineRaceManager.baseURL.appending(path: "report")

    static func report(_ word: Word, field: Field, comment: String) -> Report {
        Report(word: word.english, partOfSpeech: word.partOfSpeech, field: field.rawValue,
               comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
               current: ["translation": word.russian, "transcription": word.transcription, "example": word.example,
                         "level": word.cefrLevel, "topic": word.category?.name ?? ""])
    }

    /// В очередь и сразу попытка отправить; true — ушло на сервер, false — ждёт интернета
    static func submit(_ report: Report) async -> Bool {
        save(load() + [report])
        await flush()
        return !load().contains { $0.id == report.id }
    }

    /// Отправить всё, что накопилось; отправленное убрать из очереди
    static func flush() async {
        for report in load() {
            guard await send(report) else { return }
            save(load().filter { $0.id != report.id })
        }
    }

    static var pendingCount: Int { load().count }

    private static func send(_ report: Report) async -> Bool {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(report)
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    private static func load() -> [Report] {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([Report].self, from: data)) ?? []
    }

    private static func save(_ reports: [Report]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(reports), forKey: queueKey)
    }
}
