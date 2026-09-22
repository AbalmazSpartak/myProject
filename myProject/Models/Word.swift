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
