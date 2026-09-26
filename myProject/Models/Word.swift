import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    
    @Relationship(deleteRule: .cascade, inverse: \Word.category)
    var words: [Word] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

// Добавьте эти перечисления вне класса или в отдельный файл
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

    init(english: String, russian: String, transcription: String = "",example: String = "", category: Category? = nil) {
        self.english = english
        self.russian = russian
        self.transcription = transcription
        self.example = example
        self.category = category
    }
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = "Студент"
    
    // Статистика: Карточки для запоминания
    var flashcardsEnRuCorrect: Int = 0
    var flashcardsEnRuTotal: Int = 0
    var flashcardsRuEnCorrect: Int = 0
    var flashcardsRuEnTotal: Int = 0
    
    // Статистика: Викторина
    var quizEnRuCorrect: Int = 0
    var quizEnRuTotal: Int = 0
    var quizRuEnCorrect: Int = 0
    var quizRuEnTotal: Int = 0
    
    // Рекорд Тетриса
    var tetrisHighScore: Int = 0
    
    @Attribute(.externalStorage) var avatarData: Data?
    
    // Вычисляемые общие показатели
    var totalAnswers: Int {
        flashcardsEnRuTotal + flashcardsRuEnTotal + quizEnRuTotal + quizRuEnTotal
    }
    
    var correctAnswers: Int {
        flashcardsEnRuCorrect + flashcardsRuEnCorrect + quizEnRuCorrect + quizRuEnCorrect
    }
    
    init(
        name: String = "Студент",
        flashcardsEnRuCorrect: Int = 0, flashcardsEnRuTotal: Int = 0,
        flashcardsRuEnCorrect: Int = 0, flashcardsRuEnTotal: Int = 0,
        quizEnRuCorrect: Int = 0, quizEnRuTotal: Int = 0,
        quizRuEnCorrect: Int = 0, quizRuEnTotal: Int = 0,
        tetrisHighScore: Int = 0,
        avatarData: Data? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.flashcardsEnRuCorrect = flashcardsEnRuCorrect
        self.flashcardsEnRuTotal = flashcardsEnRuTotal
        self.flashcardsRuEnCorrect = flashcardsRuEnCorrect
        self.flashcardsRuEnTotal = flashcardsRuEnTotal
        self.quizEnRuCorrect = quizEnRuCorrect
        self.quizEnRuTotal = quizEnRuTotal
        self.quizRuEnCorrect = quizRuEnCorrect
        self.quizRuEnTotal = quizRuEnTotal
        self.tetrisHighScore = tetrisHighScore
        self.avatarData = avatarData
    }
}

