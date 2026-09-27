import Foundation
import SwiftData

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
