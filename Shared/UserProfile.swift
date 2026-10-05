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

// MARK: - Статистика ответов

extension UserProfile {
    enum TrainingStat {
        case flashcards   // карточки для запоминания и карточки ввода
        case quiz
    }

    /// Засчитывает ответ в статистику нужного режима и направления перевода
    func recordAnswer(_ stat: TrainingStat, translationMode: String, isCorrect: Bool) {
        let correct = isCorrect ? 1 : 0
        switch (stat, translationMode == "en_ru") {
        case (.flashcards, true):
            flashcardsEnRuTotal += 1
            flashcardsEnRuCorrect += correct
        case (.flashcards, false):
            flashcardsRuEnTotal += 1
            flashcardsRuEnCorrect += correct
        case (.quiz, true):
            quizEnRuTotal += 1
            quizEnRuCorrect += correct
        case (.quiz, false):
            quizRuEnTotal += 1
            quizRuEnCorrect += correct
        }
    }
}
