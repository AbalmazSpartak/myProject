import Foundation

struct RaceWordPayload: Codable, Equatable, Identifiable {
    var id: String { english }
    let english: String
    let options: [String]
    let correctAnswer: String
}

// Простой конверт вместо Codable-enum с ассоциированными значениями —
// так надёжнее и проще отлаживать сетевые сообщения
struct RaceMessage: Codable, Equatable {
    var type: String            // "start", "progress", "finished"
    var playerName: String?
    var words: [RaceWordPayload]?
    var correctCount: Int?
    var finishTime: Double?
}

struct RacePlayer: Identifiable {
    let id: String               // displayName пира, уникален в рамках сессии
    var name: String
    var correctCount: Int = 0
    var finishTime: Double? = nil
    var isMe: Bool = false
}

enum RaceWordGenerator {
    static func generate(from words: [Word], count: Int = 10) -> [RaceWordPayload] {
        let pool = words.filter { !$0.russian.isEmpty }.shuffled()
        guard pool.count >= 4 else { return [] }
        let wordCount = min(count, pool.count)
        var generated: [RaceWordPayload] = []
        
        for word in pool.prefix(wordCount) {
            let correctAnswer = word.russian
            var otherAnswers = pool
                .map { $0.russian }
                .filter { $0.lowercased() != correctAnswer.lowercased() }
                .shuffled()
            var options = [correctAnswer]
            while options.count < 3 && !otherAnswers.isEmpty {
                let next = otherAnswers.removeFirst()
                if !options.contains(next) { options.append(next) }
            }
            generated.append(RaceWordPayload(english: word.english, options: options.shuffled(), correctAnswer: correctAnswer))
        }
        return generated
    }
}
