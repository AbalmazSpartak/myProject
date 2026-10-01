import Foundation
import SwiftData

/// Свой словарь пользователя (например, слова из отсканированного текста).
/// В отличие от темы (Category), слово может состоять в нескольких словарях и не уходит из своей темы.
@Model
final class WordList {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Word.lists)
    var words: [Word] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
