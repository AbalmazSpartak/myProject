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

enum CEFRLevel: String, Codable, CaseIterable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
}

@Model
class Word {
    var english: String
    var russian: String
    var transcription: String
    var example: String = ""
    var category: Category?
    var isMistake: Bool = false
    var cefrLevel: String = "A1"
    
    // MARK: - FSRS параметры
    var state: FSRSState = FSRSState.new
    var difficulty: Double = 0.0
    var stability: Double = 0.0
    var dueDate: Date = Date()
    var reps: Int = 0
    var lapses: Int = 0
    var lastReview: Date? = nil

    // MARK: - Картинка из интернета (кэш)
    @Attribute(.externalStorage) var imageData: Data? = nil
    var isImageHidden: Bool = false
    var imageNotFound: Bool = false   // поиск ничего не дал — повторно не ищем
    var imageVariant: Int = 0         // номер кандидата, растёт при «обновить»

    init(english: String, russian: String, transcription: String = "", example: String = "", category: Category? = nil, cefrLevel: String = "A1") {
        self.english = english
        self.russian = russian
        self.transcription = transcription
        self.example = example
        self.category = category
        self.cefrLevel = cefrLevel
    }
}
