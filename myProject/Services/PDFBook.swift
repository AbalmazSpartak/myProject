import Foundation
import PDFKit
#if canImport(UIKit)
import UIKit
#endif

/// PDF → книга для читалки: текст по страницам собирается в абзацы, главы — из оглавления PDF,
/// а без него — частями, как у .txt. Сканы без текстового слоя не читаются (в них только картинки)
nonisolated enum PDFBook {
    enum Failure: Error {
        case locked, noText
    }

    static func parse(_ url: URL) throws -> ParsedBook {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url) else { throw BookParser.ParseError.unreadable }
        if document.isLocked { throw Failure.locked }

        let fileName = url.deletingPathExtension().lastPathComponent
        let title = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)
            .flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? fileName
        let author = (document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String) ?? ""

        let pageTexts = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        guard pageTexts.contains(where: { $0.contains(where: \.isLetter) }) else { throw Failure.noText }

        var chapters = outlineChapters(document, pageTexts: pageTexts)
        if chapters.count < 2 {
            let text = paragraphs(from: pageTexts).joined(separator: "\n\n")
            chapters = try BookParser.parseText(Data(text.utf8), title: title).chapters
        }
        chapters = BookCleanup.clean(chapters, title: title, author: author)
        guard !chapters.isEmpty else { throw Failure.noText }

        #if canImport(UIKit)
        let cover = document.page(at: 0)?.thumbnail(of: CGSize(width: 360, height: 520), for: .mediaBox).jpegData(compressionQuality: 0.8)
        #else
        let cover: Data? = nil
        #endif
        return ParsedBook(title: title, author: author, cover: cover, chapters: chapters)
    }

    /// Главы по верхнему уровню оглавления PDF: от страницы главы до страницы следующей
    private static func outlineChapters(_ document: PDFDocument, pageTexts: [String]) -> [BookChapter] {
        guard let root = document.outlineRoot, root.numberOfChildren > 0 else { return [] }
        var starts: [(title: String, page: Int)] = []
        for index in 0..<root.numberOfChildren {
            guard let child = root.child(at: index), let label = child.label,
                  let page = child.destination?.page else { continue }
            starts.append((label.trimmingCharacters(in: .whitespacesAndNewlines), document.index(for: page)))
        }
        starts = starts.sorted { $0.page < $1.page }.reduce(into: []) { result, item in
            if result.last?.page != item.page { result.append(item) }
        }
        guard starts.count >= 2 else { return [] }
        var chapters: [BookChapter] = []
        for (number, start) in starts.enumerated() {
            let end = number + 1 < starts.count ? starts[number + 1].page : pageTexts.count
            guard start.page < end, start.page < pageTexts.count else { continue }
            let body = paragraphs(from: Array(pageTexts[start.page..<min(end, pageTexts.count)]))
            guard body.contains(where: { $0.contains(where: \.isLetter) }) else { continue }
            chapters.append(BookChapter(title: start.title.isEmpty ? "Глава \(chapters.count + 1)" : start.title, paragraphs: body))
        }
        return chapters
    }

    /// Строки страниц → абзацы: перенос по слогам склеивается, строки одного абзаца — в одну, номера страниц отбрасываются.
    /// Абзац кончается там, где строка закончила предложение и короче обычной
    static func paragraphs(from pageTexts: [String]) -> [String] {
        let lines = pageTexts.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let lengths = lines.map(\.count).filter { $0 > 0 }.sorted()
        let usual = lengths.isEmpty ? 80 : lengths[min(lengths.count - 1, Int(Double(lengths.count) * 0.9))]
        var result: [String] = []
        var current = ""
        func flush() {
            let text = current.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty { result.append(text) }
            current = ""
        }
        for line in lines {
            if line.isEmpty { flush(); continue }
            // Номер страницы одной строкой
            if line.count <= 4, line.allSatisfy(\.isNumber) { continue }
            if current.hasSuffix("-"), !current.hasSuffix(" -") {
                current.removeLast()
                current += line
            } else {
                current += current.isEmpty ? line : " " + line
            }
            // Короткая строка без точки в начале абзаца — заголовок («Chapter One»): отдельным абзацем
            if current == line, line.count < Int(Double(usual) * 0.5), !endsSentence(line), !line.hasSuffix(",") { flush(); continue }
            if endsSentence(line), line.count < Int(Double(usual) * 0.8) { flush() }
        }
        flush()
        return result
    }

    private static func endsSentence(_ line: String) -> Bool {
        guard let last = line.last else { return false }
        return ".!?…”\"’)".contains(last)
    }
}
