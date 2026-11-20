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
    /// Дальше всего дочитано: номер абзаца от начала книги. Не уменьшается, когда вернулись к началу, — по нему «Герои и места» не открывают спойлеров
    var furthest: Int = 0
    /// Перевод книги, добавленный пользователем: главы — JSON массива BookChapter
    @Attribute(.externalStorage) var translationData: Data?
    /// Какие абзацы перевода стоят под каждым абзацем книги — JSON BookAlignment
    @Attribute(.externalStorage) var alignmentData: Data?
    /// Закладки — JSON массива BookBookmark
    var bookmarksData: Data?
    /// Заметки — JSON массива BookNote: выделенная фраза и описание
    var notesData: Data?
    /// Вместо текста — заглушка: книгу добавили ради живой озвучки, пока Project Gutenberg не отвечал
    var isTextPending: Bool = false

    /// JSON глав — для большой книги тяжёлый, поэтому `make` делает его в фоне
    nonisolated static func encodeChapters(_ chapters: [BookChapter]) -> Data {
        (try? JSONEncoder().encode(chapters)) ?? Data()
    }

    /// Книга из разобранного текста; главы кодируются в фоне, главный поток не ждёт
    static func make(_ parsed: ParsedBook, gutenbergID: Int? = nil) async -> Book {
        let data = await Task.detached(priority: .userInitiated) { encodeChapters(parsed.chapters) }.value
        return Book(parsed, chaptersData: data, gutenbergID: gutenbergID)
    }

    convenience init(_ parsed: ParsedBook, gutenbergID: Int? = nil) {
        self.init(parsed, chaptersData: Book.encodeChapters(parsed.chapters), gutenbergID: gutenbergID)
    }

    init(_ parsed: ParsedBook, chaptersData: Data, gutenbergID: Int? = nil) {
        title = parsed.title
        author = parsed.author
        coverData = parsed.cover
        self.chaptersData = chaptersData
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
