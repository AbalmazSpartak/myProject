import Foundation

/// Каталог бесплатных книг Project Gutenberg (книги — общественное достояние): поиск и загрузка EPUB.
/// Официальный каталог OPDS — без ключей и регистрации
nonisolated enum GutenbergCatalog {
    struct Entry: Identifiable, Hashable, Sendable {
        let id: Int
        let title: String
        let author: String

        var coverURL: URL? { URL(string: "https://www.gutenberg.org/cache/epub/\(id)/pg\(id).cover.medium.jpg") }
        /// Без картинок — легче, читалка всё равно показывает только текст
        var epubURL: URL? { URL(string: "https://www.gutenberg.org/ebooks/\(id).epub.noimages") }
    }

    private static let userAgent = "WordLearner/1.0 (iOS)"

    /// Пустой запрос — самые скачиваемые книги
    static func search(_ query: String) async throws -> [Entry] {
        var components = URLComponents(string: "https://www.gutenberg.org/ebooks/search.opds/")
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        components?.queryItems = trimmed.isEmpty
            ? [URLQueryItem(name: "sort_order", value: "downloads")]
            : [URLQueryItem(name: "query", value: trimmed)]
        guard let url = components?.url else { return [] }
        let xml = String(decoding: try await fetch(url), as: UTF8.self)
        return entries(in: xml)
    }

    static func downloadBook(_ entry: Entry) async throws -> ParsedBook {
        guard let url = entry.epubURL else { throw URLError(.badURL) }
        let data = try await fetch(url)
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
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}
