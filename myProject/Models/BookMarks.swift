import Foundation

/// Закладка в книге: абзац от начала книги, когда поставлена и заметка к ней
nonisolated struct BookBookmark: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var paragraph: Int
    var created = Date()
    var note = ""
}

extension Book {
    /// Закладки по порядку в книге
    var bookmarks: [BookBookmark] {
        get { bookmarksData.flatMap { try? JSONDecoder().decode([BookBookmark].self, from: $0) } ?? [] }
        set { bookmarksData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue.sorted { $0.paragraph < $1.paragraph }) }
    }
}

/// Заметка в книге: выделенная фраза, абзац от начала книги и описание читателя
nonisolated struct BookNote: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var paragraph: Int
    var text: String
    var note = ""
    var created = Date()
    /// Где выделенное стоит в абзаце (символы абзаца) — по нему страница подсвечивает заметку; у старых заметок нет
    var location: Int?
    var length: Int?
}

extension Book {
    /// Заметки по порядку в книге
    var notes: [BookNote] {
        get { notesData.flatMap { try? JSONDecoder().decode([BookNote].self, from: $0) } ?? [] }
        set { notesData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue.sorted { $0.paragraph < $1.paragraph }) }
    }
}
