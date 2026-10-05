import Foundation
import SwiftData

/// Книга в разделе «Книги»: главы уже разобраны при добавлении, читалка открывает их сразу
@Model
final class Book {
    var id: UUID = UUID()
    var title: String
    var author: String
    var addedAt: Date = Date()
    var lastOpenedAt: Date?
    /// Номер книги в каталоге Project Gutenberg — чтобы не скачать её второй раз
    var gutenbergID: Int?
    @Attribute(.externalStorage) var coverData: Data?
    /// Главы — JSON массива BookChapter
    @Attribute(.externalStorage) var chaptersData: Data
    var paragraphCount: Int
    /// Где остановились: номер абзаца от начала книги
    var position: Int = 0

    init(_ parsed: ParsedBook, gutenbergID: Int? = nil) {
        title = parsed.title
        author = parsed.author
        coverData = parsed.cover
        chaptersData = (try? JSONEncoder().encode(parsed.chapters)) ?? Data()
        paragraphCount = parsed.chapters.reduce(0) { $0 + $1.paragraphs.count }
        self.gutenbergID = gutenbergID
    }

    var chapters: [BookChapter] {
        (try? JSONDecoder().decode([BookChapter].self, from: chaptersData)) ?? []
    }

    /// Прочитано, от 0 до 1
    var progress: Double {
        paragraphCount > 0 ? min(1, Double(position) / Double(paragraphCount)) : 0
    }
}
