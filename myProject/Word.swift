import Foundation
import SwiftData

@Model
final class Word {
    var id: UUID
    var english: String
    var russian: String
    var example: String // <-- ДОБАВИЛИ ПОЛЕ ДЛЯ ПРИМЕРА ФРАЗЫ
    
    init(english: String, russian: String, example: String = "") {
        self.id = UUID()
        self.english = english
        self.russian = russian
        self.example = example
    }
}

// Обновляем стартовый набор слов красивыми примерами фраз
let sampleWords = [
    Word(english: "Apple", russian: "Яблоко", example: "I eat a fresh apple every morning."),
    Word(english: "Book", russian: "Книга", example: "This book has a very interesting story."),
    Word(english: "Cat", russian: "Кот", example: "The sleeping cat is very warm and fluffy."),
    Word(english: "Dog", russian: "Собака", example: "My dog loves running in the big park."),
    Word(english: "House", russian: "Дом", example: "We live in a beautiful white house.")
]
