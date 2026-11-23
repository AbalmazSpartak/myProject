import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Импорт книги из файла: EPUB, FB2, TXT и PDF — и из кнопки «Добавить», и из «Открыть в…» других приложений
nonisolated enum BookImport {
    /// Какие файлы приложение берёт как книги
    static func isBookFile(_ url: URL) -> Bool {
        ["epub", "fb2", "zip", "txt", "text", "pdf"].contains(url.pathExtension.lowercased())
    }

    static func parse(_ url: URL) throws -> ParsedBook {
        url.pathExtension.lowercased() == "pdf" ? try PDFBook.parse(url) : try BookParser.parse(url)
    }

    /// Понятное объяснение, почему файл не открылся
    static func message(for error: Error) -> String {
        switch error {
        case PDFBook.Failure.locked:
            return "PDF защищён паролем. Снимите защиту и добавьте его снова."
        case PDFBook.Failure.noText:
            return "В этом PDF нет текста, и распознать его по картинкам страниц не получилось. Попробуйте файл получше качеством или PDF с выделяемым текстом."
        default:
            return "Не получилось открыть книгу. Подходят .epub без защиты (например, не из Apple Books), .fb2, .txt и .pdf с текстом."
        }
    }
}

extension UTType {
    /// Файлы, из которых получается книга: EPUB, FB2 (и FB2 в ZIP), обычный текст, PDF
    static let readableBookFiles: [UTType] = [.epub, .fictionBook, .zip, .plainText, .pdf]
}
