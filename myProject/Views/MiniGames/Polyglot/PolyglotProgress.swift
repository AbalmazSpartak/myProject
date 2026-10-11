import Foundation

/// Баллы и освоение уроков «Полиглота». Хранится одной JSON-строкой в UserDefaults (входит в резервную копию);
/// экраны читают её через @AppStorage(PolyglotProgress.storageKey) и обновляются сами
struct PolyglotProgress: Equatable {
    static let storageKey = "polyglot_progress"

    /// Освоение считается по последним раундам: старые неудачи со временем не тянут вниз
    static let roundsForMastery = 3
    static let pointsPerCorrect = 10
    /// Бонус за каждые `streakStep` верных ответов подряд
    static let streakBonus = 5
    static let streakStep = 5

    struct Round: Codable, Equatable {
        var correct: Int
        var total: Int
    }

    struct Lesson: Codable, Equatable {
        var recentRounds: [Round] = []
        var bestPoints = 0
        var points = 0

        /// Доля верных с первого раза в последних раундах; nil — урок ещё не проходили
        var mastery: Double? {
            let total = recentRounds.reduce(0) { $0 + $1.total }
            guard total > 0 else { return nil }
            return Double(recentRounds.reduce(0) { $0 + $1.correct }) / Double(total)
        }

        var level: Level? { mastery.map(Level.init(mastery:)) }
    }

    enum Level: Int, Comparable {
        case acquaintance, practice, confident, mastered

        init(mastery: Double) {
            switch mastery {
            case ..<0.4: self = .acquaintance
            case ..<0.7: self = .practice
            case ..<0.9: self = .confident
            default: self = .mastered
            }
        }

        var title: String {
            switch self {
            case .acquaintance: return "Знакомство"
            case .practice: return "Практика"
            case .confident: return "Уверенно"
            case .mastered: return "Освоено"
            }
        }

        /// ☆☆☆ … ★★★
        var stars: String {
            String(repeating: "★", count: rawValue) + String(repeating: "☆", count: 3 - rawValue)
        }

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var lessons: [String: Lesson] = [:]

    var totalPoints: Int { lessons.values.reduce(0) { $0 + $1.points } }

    func lesson(_ number: Int) -> Lesson { lessons[String(number)] ?? Lesson() }

    /// Записать пройденный раунд урока
    mutating func record(lesson number: Int, correct: Int, total: Int, points: Int) {
        var lesson = lesson(number)
        lesson.recentRounds = Array((lesson.recentRounds + [Round(correct: correct, total: total)]).suffix(Self.roundsForMastery))
        lesson.bestPoints = max(lesson.bestPoints, points)
        lesson.points += points
        lessons[String(number)] = lesson
    }

    /// Баллы за верный ответ: `streak` — сколько верных подряд вместе с этим
    static func points(forCorrectAnswerWithStreak streak: Int) -> Int {
        pointsPerCorrect + (streak % streakStep == 0 ? streakBonus : 0)
    }

    /// 1 балл, 2 балла, 5 баллов
    static func pointsNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "баллов" }
        switch last {
        case 1: return "балл"
        case 2...4: return "балла"
        default: return "баллов"
        }
    }
}

// Хранение в @AppStorage одной JSON-строкой. Кодируется словарь уроков, а не сам тип:
// у RawRepresentable стандартное Codable пишет rawValue и зациклилось бы
extension PolyglotProgress: RawRepresentable {
    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let lessons = try? JSONDecoder().decode([String: Lesson].self, from: data) else { return nil }
        self.init(lessons: lessons)
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(lessons) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
