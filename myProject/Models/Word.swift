import Foundation
import SwiftData

enum FSRSState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

enum FSRSRating: Int {
    case again = 1 // Снова (Забыл)
    case hard = 2  // Трудно
    case good = 3  // Хорошо
    case easy = 4  // Легко
}

@Model
class Word {
    var english: String
    var russian: String
    var transcription: String
    var example: String = ""
    var category: Category?
    var isMistake: Bool = false
    
    // MARK: - FSRS параметры
    var state: FSRSState = FSRSState.new
    var difficulty: Double = 0.0
    var stability: Double = 0.0
    var dueDate: Date = Date()
    var reps: Int = 0
    var lapses: Int = 0
    var lastReview: Date? = nil

    init(english: String, russian: String, transcription: String = "", example: String = "", category: Category? = nil) {
        self.english = english
        self.russian = russian
        self.transcription = transcription
        self.example = example
        self.category = category
    }
}
