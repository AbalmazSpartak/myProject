import Foundation
import SwiftData

/// Каталог бесплатных книг Project Gutenberg (книги — общественное достояние): поиск и загрузка EPUB.
/// Официальный каталог OPDS — без ключей и регистрации. Когда gutenberg.org на техработах — список из Gutendex,
/// а файлы с официального зеркала gutenberg.pglaf.org
nonisolated enum GutenbergCatalog {
    /// Сайт ответил ошибкой сервера (5xx) — у них техработы или сбой, интернет у пользователя в порядке
    struct ServerDown: Error {}

    struct Entry: Identifiable, Hashable, Sendable {
        let id: Int
        let title: String
        let author: String

        /// С зеркала: на основном сайте обложки пропадают вместе с ним
        var coverURL: URL? { URL(string: "https://gutenberg.pglaf.org/cache/epub/\(id)/pg\(id).cover.medium.jpg") }
        /// Без картинок — легче, читалка всё равно показывает только текст
        var epubURL: URL? { URL(string: "https://www.gutenberg.org/ebooks/\(id).epub.noimages") }
        /// Тот же файл на официальном зеркале
        var mirrorEPUBURL: URL? { URL(string: "https://gutenberg.pglaf.org/cache/epub/\(id)/pg\(id).epub") }
    }

    private static let userAgent = "WordLearner/1.0 (iOS)"

    /// Пустой запрос — самые скачиваемые книги
    static func search(_ query: String) async throws -> [Entry] {
        do {
            return try await searchOPDS(query)
        } catch {
            // Основной сайт не ответил — тот же каталог из Gutendex; не вышло и там — ошибка основного сайта
            if let entries = try? await searchGutendex(query) { return entries }
            throw error
        }
    }

    private static func searchOPDS(_ query: String) async throws -> [Entry] {
        var components = URLComponents(string: "https://www.gutenberg.org/ebooks/search.opds/")
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        components?.queryItems = trimmed.isEmpty
            ? [URLQueryItem(name: "sort_order", value: "downloads")]
            : [URLQueryItem(name: "query", value: trimmed)]
        guard let url = components?.url else { return [] }
        let xml = String(decoding: try await fetch(url), as: UTF8.self)
        return entries(in: xml)
    }

    /// Gutendex — независимая копия каталога Gutenberg с поиском и «популярными»
    private static func searchGutendex(_ query: String) async throws -> [Entry] {
        var components = URLComponents(string: "https://gutendex.com/books/")
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        components?.queryItems = trimmed.isEmpty
            ? [URLQueryItem(name: "sort", value: "popular")]
            : [URLQueryItem(name: "search", value: trimmed)]
        guard let url = components?.url else { return [] }
        let data = try await fetch(url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { throw URLError(.cannotParseResponse) }
        return results.compactMap { book in
            guard let id = book["id"] as? Int, let title = book["title"] as? String else { return nil }
            // «Carroll, Lewis» → «Lewis Carroll»
            let author = ((book["authors"] as? [[String: Any]])?.first?["name"] as? String).map { name in
                name.split(separator: ",", maxSplits: 1).reversed()
                    .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
            } ?? ""
            return Entry(id: id, title: title, author: author)
        }
    }

    static func downloadBook(_ entry: Entry) async throws -> ParsedBook {
        guard let url = entry.epubURL else { throw URLError(.badURL) }
        let data: Data
        do {
            data = try await fetch(url)
        } catch {
            // Основной сайт лежит — тот же файл с зеркала; не вышло и там — ошибка основного сайта
            guard let mirror = entry.mirrorEPUBURL, let copy = try? await fetch(mirror) else { throw error }
            data = copy
        }
        let title = entry.title
        // Разбор книги — секунда-другая, не на главном потоке
        var book = try await Task.detached(priority: .userInitiated) {
            try BookParser.parseEPUB(data, fallbackTitle: title)
        }.value
        if book.author.isEmpty { book.author = entry.author }
        if book.cover == nil, let coverURL = entry.coverURL {
            book.cover = try? await fetch(coverURL)
        }
        return book
    }

    /// Книги — записи с адресом /ebooks/<номер>.opds; записи «Авторы», «Темы» пропускаем
    private static func entries(in xml: String) -> [Entry] {
        EPUBDocument.allMatches("<entry>[\\s\\S]*?</entry>", in: xml).compactMap { entry in
            guard let idText = EPUBDocument.firstMatch("<id>[^<]*/ebooks/(\\d+)\\.opds</id>", in: entry),
                  let id = Int(idText),
                  let title = EPUBDocument.firstMatch("<title>([\\s\\S]*?)</title>", in: entry) else { return nil }
            // В списке популярных вместо автора бывает «80943 downloads» — такое не показываем
            let content = EPUBDocument.firstMatch("<content[^>]*>([\\s\\S]*?)</content>", in: entry) ?? ""
            let author = content.range(of: "^\\d+ downloads$", options: .regularExpression) == nil ? content : ""
            return Entry(id: id, title: HTMLText.decoded(title), author: HTMLText.decoded(author))
        }
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode >= 500 { throw ServerDown() }
        guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}

extension GutenbergCatalog {
    /// Понятная причина для пользователя: техработы у Gutenberg — не «проверьте интернет»
    static func failureText(_ error: Error, action: String) -> String {
        if error is ServerDown {
            return "Project Gutenberg сейчас недоступен — у них техработы. Интернет в порядке. \(action) можно будет позже."
        }
        return "Нет связи с Project Gutenberg. Проверьте интернет и попробуйте ещё раз."
    }

    /// Текст-заглушка для книги, добавленной ради живой озвучки, пока Gutenberg не отвечал
    static func placeholder(title: String, author: String) -> ParsedBook {
        ParsedBook(title: title, author: author, cover: nil, chapters: [
            BookChapter(title: title, paragraphs: [
                "Текст этой книги ещё не скачан: Project Gutenberg не отвечал.",
                "Живой голос уже можно слушать. Текст загрузится сам, когда сайт заработает, — или нажмите «Загрузить текст» на странице книги.",
            ])
        ])
    }
}

extension Book {
    /// Скачать настоящий текст вместо заглушки; false — Gutenberg пока не отвечает
    @MainActor
    func loadPendingText() async throws {
        guard isTextPending, let gutenbergID else { return }
        let parsed = try await GutenbergCatalog.downloadBook(.init(id: gutenbergID, title: title, author: author))
        chaptersData = (try? JSONEncoder().encode(parsed.chapters)) ?? Data()
        paragraphCount = parsed.chapters.reduce(0) { $0 + $1.paragraphs.count }
        if coverData == nil { coverData = parsed.cover }
        if author.isEmpty { author = parsed.author }
        position = 0
        furthest = 0
        isTextPending = false
        try? modelContext?.save()
    }
}
