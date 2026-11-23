import Foundation
import PDFKit
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// PDF → книга для читалки: текст по страницам собирается в абзацы, главы — из оглавления PDF,
/// а без него — частями, как у .txt. Сканы без текстового слоя распознаются через Vision (OCR)
nonisolated enum PDFBook {
    enum Failure: Error {
        case locked, noText
    }

    /// Ход распознавания скана: сколько страниц готово и сколько всего (для строки прогресса)
    typealias Progress = @Sendable (_ page: Int, _ total: Int) -> Void

    static func parse(_ url: URL, progress: Progress? = nil) throws -> ParsedBook {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url) else { throw BookParser.ParseError.unreadable }
        if document.isLocked { throw Failure.locked }

        let fileName = url.deletingPathExtension().lastPathComponent
        let title = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String)
            .flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? fileName
        let author = (document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String) ?? ""

        var pageTexts = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        // Скан без текстового слоя: страницы — картинки, текст распознаёт Vision на устройстве
        if !pageTexts.contains(where: { $0.contains(where: \.isLetter) }) { pageTexts = recognizedPages(document, progress: progress) }
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

    /// Распознавание текста (OCR) у скана: каждая страница рисуется в картинку, Vision читает строки
    private static func recognizedPages(_ document: PDFDocument, progress: Progress?) -> [String] {
        let total = document.pageCount
        progress?(0, total)
        return (0..<total).map { index in
            let text = autoreleasepool { document.page(at: index).map(recognizedText) ?? "" }
            progress?(index + 1, total)
            return text
        }
    }

    private static func recognizedText(on page: PDFPage) -> String {
        let box = page.bounds(for: .mediaBox)
        guard box.width > 0, box.height > 0 else { return "" }
        // Длинная сторона ~2400 пикселей: мельче Vision хуже читает, крупнее — дольше без пользы
        let scale = 2400 / max(box.width, box.height)
        let width = Int(box.width * scale), height = Int(box.height * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return "" }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { return "" }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        let wanted = ["en-US", "ru-RU"]
        if let supported = try? request.supportedRecognitionLanguages() {
            request.recognitionLanguages = wanted.filter(supported.contains)
        }
        guard (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil else { return "" }
        let lines = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        return lines.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
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
            // Заголовок главы уже есть в названии: первый абзац-повтор убираем
            let trimmed = body.first.map { dropsAsTitle($0, title: start.title) } == true ? Array(body.dropFirst()) : body
            chapters.append(BookChapter(title: start.title.isEmpty ? "Глава \(chapters.count + 1)" : start.title, paragraphs: trimmed))
        }
        return chapters
    }

    /// Строки страниц → абзацы: перенос по слогам склеивается, строки одного абзаца — в одну, номера страниц отбрасываются.
    /// Абзац кончается там, где строка закончила предложение и короче обычной
    static func paragraphs(from pageTexts: [String]) -> [String] {
        let rawLines = pageTexts.flatMap { $0.components(separatedBy: .newlines) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        // Обычная длина строки считается без «колонок одной строкой», иначе короткие строки примут за заголовки
        let lengths = rawLines.map(\.count).filter { $0 > 0 && $0 <= longLine }.sorted()
        let usual = lengths.isEmpty ? 80 : lengths[min(lengths.count - 1, Int(Double(lengths.count) * 0.9))]
        let lines = rawLines.flatMap(splitLongLine)
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

    private static let longLine = 600

    private static func dropsAsTitle(_ paragraph: String, title: String) -> Bool {
        func key(_ text: String) -> String {
            text.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let a = key(paragraph)
        return !a.isEmpty && a == key(title)
    }

    /// Колонки некоторых PDF приходят одной очень длинной строкой без переводов строки:
    /// режем её по предложениям на куски примерно по 450 знаков, между кусками — граница абзаца
    private static func splitLongLine(_ line: String) -> [String] {
        guard line.count > longLine else { return [line] }
        let sentences = line.replacingOccurrences(of: "(?<=[.!?…])\\s+(?=[\"“A-ZА-ЯЁ])", with: "\n", options: .regularExpression)
            .components(separatedBy: "\n")
        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            if !current.isEmpty, current.count + sentence.count > 450 {
                chunks.append(current)
                current = ""
            }
            current += current.isEmpty ? sentence : " " + sentence
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.flatMap { [$0, ""] }
    }

    private static func endsSentence(_ line: String) -> Bool {
        guard let last = line.last else { return false }
        return ".!?…”\"’)".contains(last)
    }
}
