import Foundation

/// Глава книги для читалки: заголовок и абзацы простым текстом
nonisolated struct BookChapter: Codable, Hashable, Sendable {
    var title: String
    var paragraphs: [String]
}

/// Книга после разбора файла: всё, что нужно библиотеке и читалке
nonisolated struct ParsedBook: Sendable {
    var title: String
    var author: String
    var cover: Data?
    var chapters: [BookChapter]
}

/// EPUB: ZIP с главами в XHTML; порядок глав, название, автор и обложка — в файле .opf
nonisolated struct EPUBDocument {
    let archive: ZipArchive
    /// Пути глав в порядке книги (spine); без оглавления — все XHTML по имени
    let chapterPaths: [String]
    let title: String?
    let author: String?
    private let coverPath: String?

    init?(data: Data) {
        guard let archive = ZipArchive(data: data) else { return nil }
        self.archive = archive
        let fallback = archive.entries.map(\.name)
            .filter { ["xhtml", "html", "htm"].contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        guard let container = archive.contents(of: "META-INF/container.xml").map({ String(decoding: $0, as: UTF8.self) }),
              let opfPath = Self.attribute("full-path", in: container),
              let opf = archive.contents(of: opfPath).map({ String(decoding: $0, as: UTF8.self) }) else {
            chapterPaths = fallback
            title = nil
            author = nil
            coverPath = nil
            return
        }
        let base = (opfPath as NSString).deletingLastPathComponent
        var manifest: [String: String] = [:]
        var cover: String?
        for tag in Self.allMatches("<item\\b[^>]*>", in: opf) {
            guard let id = Self.attribute("id", in: tag), let href = Self.attribute("href", in: tag) else { continue }
            let decoded = href.removingPercentEncoding ?? href
            let path = base.isEmpty ? decoded : (base as NSString).appendingPathComponent(decoded)
            manifest[id] = path
            if Self.attribute("properties", in: tag)?.contains("cover-image") == true { cover = path }
        }
        // Обложка в EPUB 2 — <meta name="cover" content="id">
        if cover == nil,
           let meta = Self.allMatches("<meta\\b[^>]*name\\s*=\\s*[\"']cover[\"'][^>]*>", in: opf).first,
           let id = Self.attribute("content", in: meta) {
            cover = manifest[id]
        }
        let spine = Self.allMatches("<itemref\\b[^>]*>", in: opf)
            .compactMap { Self.attribute("idref", in: $0) }
            .compactMap { manifest[$0] }
        chapterPaths = spine.isEmpty ? fallback : spine
        title = Self.element("dc:title", in: opf)
        author = Self.element("dc:creator", in: opf)
        coverPath = cover
    }

    var cover: Data? { coverPath.flatMap { archive.contents(of: $0) } }

    func html(at path: String) -> String? {
        archive.contents(of: path).map { String(decoding: $0, as: UTF8.self) }
    }

    // MARK: - Разбор XML регулярками: для .opf этого хватает

    static func attribute(_ name: String, in tag: String) -> String? {
        firstMatch("\\b\(name)\\s*=\\s*[\"']([^\"']+)[\"']", in: tag)
    }

    private static func element(_ name: String, in xml: String) -> String? {
        firstMatch("<\(name)\\b[^>]*>([\\s\\S]*?)</\(name)>", in: xml)
            .map { HTMLText.plain($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    static func allMatches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }
}

/// HTML → текст: без тегов, стилей и скриптов, с расшифровкой частых сущностей
nonisolated enum HTMLText {
    static func plain(_ html: String) -> String {
        decoded(html
            .replacingOccurrences(of: "<(script|style|head)[^>]*>[\\s\\S]*?</\\1>", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression))
    }

    /// Абзацы: конец абзаца, заголовка, пункта списка или <br> — граница; переносы строк внутри абзаца — пробелы
    static func paragraphs(_ html: String) -> [String] {
        let marked = html
            .replacingOccurrences(of: "<(script|style|head)[^>]*>[\\s\\S]*?</\\1>", with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</(p|div|h[1-6]|li|blockquote|tr|pre)>|<br\\s*/?>", with: "\u{1}", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return decoded(marked)
            .components(separatedBy: "\u{1}")
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func decoded(_ text: String) -> String {
        text.replacingOccurrences(of: "&nbsp;|&#160;", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&#39;|&apos;|&rsquo;|&lsquo;|&#8217;|&#8216;|&#x2019;", with: "'", options: .regularExpression)
            .replacingOccurrences(of: "&quot;|&ldquo;|&rdquo;|&#8220;|&#8221;", with: "\"", options: .regularExpression)
            .replacingOccurrences(of: "&mdash;|&#8212;", with: "—", options: .regularExpression)
            .replacingOccurrences(of: "&ndash;|&#8211;", with: "–", options: .regularExpression)
            .replacingOccurrences(of: "&hellip;|&#8230;", with: "…", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

/// Книга из файла: .epub — по главам книги, .txt — по строкам «Chapter …» или частями
nonisolated enum BookParser {
    enum ParseError: Error {
        case unreadable, empty
    }

    /// Абзацев в части, если в тексте нет глав
    private static let partSize = 150

    static func parse(_ url: URL) throws -> ParsedBook {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let fileName = url.deletingPathExtension().lastPathComponent
        let book = url.pathExtension.lowercased() == "epub"
            ? try parseEPUB(data, fallbackTitle: fileName)
            : try parseText(data, title: fileName)
        guard !book.chapters.isEmpty else { throw ParseError.empty }
        return book
    }

    static func parseEPUB(_ data: Data, fallbackTitle: String) throws -> ParsedBook {
        guard let epub = EPUBDocument(data: data) else { throw ParseError.unreadable }
        var chapters: [BookChapter] = []
        for path in epub.chapterPaths {
            guard let html = epub.html(at: path) else { continue }
            let paragraphs = HTMLText.paragraphs(html)
            // Глава без английских слов (обложка, пустая страница) не нужна
            guard paragraphs.contains(where: { $0.contains(where: \.isLetter) }) else { continue }
            let heading = EPUBDocument.firstMatch("<h[1-3][^>]*>([\\s\\S]*?)</h[1-3]>", in: html)
                .map { HTMLText.plain($0).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
            let title = (heading?.isEmpty == false ? heading : nil) ?? "Глава \(chapters.count + 1)"
            chapters.append(BookChapter(title: title, paragraphs: paragraphs))
        }
        guard !chapters.isEmpty else { throw ParseError.empty }
        return ParsedBook(title: epub.title ?? fallbackTitle, author: epub.author ?? "", cover: epub.cover, chapters: chapters)
    }

    /// Абзацы — через пустую строку; строки внутри абзаца (жёсткие переносы, как в книгах Gutenberg) склеиваем
    static func parseText(_ data: Data, title: String) throws -> ParsedBook {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) else {
            throw ParseError.unreadable
        }
        let paragraphs = text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Есть строки «Chapter …» — делим по ним, нет — частями по partSize абзацев
        let usesHeadings = paragraphs.contains(where: isHeading)
        var chapters: [BookChapter] = []
        var current = BookChapter(title: "", paragraphs: [])
        for paragraph in paragraphs {
            let heading = usesHeadings && isHeading(paragraph)
            if heading || (!usesHeadings && current.paragraphs.count >= partSize) {
                if !current.paragraphs.isEmpty { chapters.append(current) }
                current = BookChapter(title: heading ? paragraph : "", paragraphs: heading ? [] : [paragraph])
            } else {
                current.paragraphs.append(paragraph)
            }
        }
        if !current.paragraphs.isEmpty { chapters.append(current) }
        for index in chapters.indices where chapters[index].title.isEmpty {
            chapters[index].title = "Часть \(index + 1)"
        }
        return ParsedBook(title: title, author: "", cover: nil, chapters: chapters)
    }

    private static func isHeading(_ paragraph: String) -> Bool {
        paragraph.count < 80
            && paragraph.range(of: "^(chapter|book|part|section)\\b", options: [.regularExpression, .caseInsensitive]) != nil
    }
}
