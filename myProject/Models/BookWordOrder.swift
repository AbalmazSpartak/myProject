import Foundation

/// Порядок слов книги в карточках: сначала те, которым пора на повторение, затем новые, затем остальные вперемешку
enum BookWordOrder {
    static func ordered(_ words: [Word], now: Date = Date()) -> [Word] {
        let due = words.filter { $0.state != .new && $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
        let fresh = words.filter { $0.state == .new }.shuffled()
        let rest = words.filter { $0.state != .new && $0.dueDate > now }.shuffled()
        return due + fresh + rest
    }
}
