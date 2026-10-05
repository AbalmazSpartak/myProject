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
