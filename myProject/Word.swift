import Foundation

struct Word: Identifiable {
    let id = UUID()
    let english: String
    let russian: String
}

let sampleWords: [Word] = [
    Word(english: "Apple", russian: "Яблоко"),
    Word(english: "Book", russian: "Книга"),
    Word(english: "Cat", russian: "Кот"),
    Word(english: "Dog", russian: "Собака"),
    Word(english: "House", russian: "Дом")
]
