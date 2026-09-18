import Foundation
import SwiftData

@Model
final class Word {
    var id: UUID
    var english: String
    var russian: String
    
    init(english: String, russian: String) {
        self.id = UUID()
        self.english = english
        self.russian = russian
    }
}

// Стартовый набор слов, если база данных пуста
let sampleWords = [
    Word(english: "Apple", russian: "Яблоко"),
    Word(english: "Book", russian: "Книга"),
    Word(english: "Cat", russian: "Кот"),
    Word(english: "Dog", russian: "Собака"),
    Word(english: "House", russian: "Дом")
]
