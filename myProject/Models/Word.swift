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

@Model
final class Word {
    var id: UUID
    var english: String
    var russian: String
    var example: String
    var transcription: String
    var isMistake: Bool = false // 👈 Новое поле для фиксации ошибок
    
    var category: Category?
    
    init(
        english: String,
        russian: String,
        example: String = "",
        transcription: String = "",
        category: Category? = nil,
        isMistake: Bool = false
    ) {
        self.id = UUID()
        self.english = english
        self.russian = russian
        self.example = example
        self.transcription = transcription
        self.category = category
        self.isMistake = isMistake
    }
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = "Студент"
    
    // Статистика: Карточки с вводом (с дефолтными значениями = 0)
    var flashcardsEnRuCorrect: Int = 0
    var flashcardsEnRuTotal: Int = 0
    var flashcardsRuEnCorrect: Int = 0
    var flashcardsRuEnTotal: Int = 0
    
    // Статистика: Викторина (с дефолтными значениями = 0)
    var quizEnRuCorrect: Int = 0
    var quizEnRuTotal: Int = 0
    var quizRuEnCorrect: Int = 0
    var quizRuEnTotal: Int = 0
    
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
        self.avatarData = avatarData
    }
}

