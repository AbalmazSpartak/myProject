import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    
    // Связь: при удалении категории все слова в ней удалятся автоматически
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
    var transcription: String // Новое поле для транскрипции
    
    // Опциональная связь: если category == nil, слово лежит в Общем словаре
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

// Обновим базовые слова для первого запуска, добавив транскрипцию
let sampleWords = [
    Word(english: "apple", russian: "яблоко", example: "I eat a fresh apple every morning.", transcription: "[ˈæpl]"),
    Word(english: "book", russian: "книга", example: "This book has a very interesting story.", transcription: "[bʊk]"),
    Word(english: "cat", russian: "кот", example: "The sleeping cat is very warm and fluffy.", transcription: "[kæt]"),
    Word(english: "dog", russian: "собака", example: "My dog loves running in the big park.", transcription: "[dɔːɡ]"),
    Word(english: "house", russian: "дом", example: "We live in a beautiful white house.", transcription: "[haʊs]")
]

