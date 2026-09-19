import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    
    // Связь: при удалении категории все слова в ней удалятся автоматически
    @Relationship(deleteRule: .cascade) var words: [Word] = []
    
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
    Word(english: "Apple", russian: "Яблоко", example: "I eat a fresh apple every morning.", transcription: "[ˈæpl]"),
    Word(english: "Book", russian: "Книга", example: "This book has a very interesting story.", transcription: "[bʊk]"),
    Word(english: "Cat", russian: "Кот", example: "The sleeping cat is very warm and fluffy.", transcription: "[kæt]"),
    Word(english: "Dog", russian: "Собака", example: "My dog loves running in the big park.", transcription: "[dɔːɡ]"),
    Word(english: "House", russian: "Дом", example: "We live in a beautiful white house.", transcription: "[haʊs]")
]

