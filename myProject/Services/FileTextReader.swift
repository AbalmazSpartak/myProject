import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Текст из файла для «Слов из текста»: .txt, субтитры .srt/.vtt, .pdf, .rtf, .html, книги .epub.
/// Работает вне главного потока — книга или сезон субтитров читаются секунды
nonisolated enum FileTextReader {
    /// Около толстой книги; дальше — обрезаем, чтобы разбор не тянулся минутами
    static let maxCharacters = 2_000_000

    static let allowedTypes: [UTType] = [
        .plainText, .text, .pdf, .rtf, .html, .epub,
        UTType(filenameExtension: "srt"), UTType(filenameExtension: "vtt")
    ].compactMap { $0 }

    struct Result: Sendable {
        let text: String
        /// Файл длиннее maxCharacters — взято начало
        let isTruncated: Bool
    }

    enum ReadError: Error {
        case unreadable
    }

    static func read(_ url: URL) throws -> Result {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }

        let raw: String
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let text = PDFDocument(url: url)?.string else { throw ReadError.unreadable }
            raw = text
        case "rtf":
            raw = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                         documentAttributes: nil).string
        case "epub":
            raw = try epubText(url)
        case "html", "htm":
            raw = strippedHTML(try plainText(url))
        case "srt", "vtt":
            raw = strippedSubtitles(try plainText(url))
        default:
            raw = try plainText(url)
        }
        let isTruncated = raw.count > maxCharacters
        return Result(text: isTruncated ? String(raw.prefix(maxCharacters)) : raw, isTruncated: isTruncated)
    }

    // MARK: - EPUB

    /// Книга EPUB — главы по порядку книги; книги с защитой (DRM, например из Apple Books) не читаются
    private static func epubText(_ url: URL) throws -> String {
        guard let epub = EPUBDocument(data: try Data(contentsOf: url)) else { throw ReadError.unreadable }
        var text = ""
        var length = 0
        for path in epub.chapterPaths {
            guard let html = epub.html(at: path) else { continue }
            let chapter = HTMLText.plain(html) + "\n"
            text += chapter
            length += chapter.count
            // Дальше всё равно обрежется — не распаковываем лишнее
            if length > maxCharacters { break }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadError.unreadable }
        return text
    }

    /// UTF-8, иначе кодировку угадывает система, иначе Windows-1252 (старые субтитры)
    private static func plainText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return text }
        var encoding = String.Encoding.utf8
        if let text = try? String(contentsOf: url, usedEncoding: &encoding) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        throw ReadError.unreadable
    }

    /// Номера реплик, тайминги «00:01:02,000 --> …», WEBVTT и теги <i>, {\an8} — не текст
    private static func strippedSubtitles(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { line in
                let line = line.trimmingCharacters(in: .whitespaces)
                return !line.isEmpty && !line.contains("-->") && !line.hasPrefix("WEBVTT") && Int(line) == nil
            }
            .map { $0.replacingOccurrences(of: "<[^>]+>|\\{[^}]*\\}", with: "", options: .regularExpression) }
            .joined(separator: "\n")
    }

    private static func strippedHTML(_ html: String) -> String {
        HTMLText.plain(html)
    }
}
