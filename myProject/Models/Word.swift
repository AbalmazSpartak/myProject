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
    
    var category: Category?
    
    init(english: String, russian: String, example: String = "", transcription: String = "", category: Category? = nil) {
        self.id = UUID()
        self.english = english
        self.russian = russian
        self.example = example
        self.transcription = transcription
        self.category = category
    }
}

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var correctAnswers: Int
    var totalAnswers: Int
    
    // Новое поле: бинарные данные фотографии профиля
    @Attribute(.externalStorage) var avatarData: Data?
    
    init(name: String = "Студент", correctAnswers: Int = 0, totalAnswers: Int = 0) {
        self.id = UUID()
        self.name = name
        self.correctAnswers = correctAnswers
        self.totalAnswers = totalAnswers
    }
}

