import Foundation

// Разбирает CSV мастер-базы:
// Word,PoS,IPA,Translation,Example,Level,Topic,Tags
// Строка заголовков необязательна. Поля с запятыми — в двойных кавычках ("" внутри = кавычка).
enum WordCSVParser {
    static func parse(_ text: String) -> [WordDTO] {
        var rows = parseRows(text)
        if let first = rows.first?.first, first.lowercased() == "word" {
            rows.removeFirst()
        }

        return rows.compactMap { fields in
            func field(_ index: Int) -> String {
                index < fields.count ? fields[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            }
            let english = field(0)
            let russian = field(3)
            guard !english.isEmpty, !russian.isEmpty else { return nil }

            let level = field(5).uppercased()
            return WordDTO(
                english: english,
                partOfSpeech: field(1),
                transcription: Word.bareTranscription(field(2)),
                russian: russian,
                example: field(4),
                cefrLevel: CEFRLevel(rawValue: level) != nil ? level : "A1",
                categoryName: field(6),
                tags: field(7)
            )
        }
    }

    // MARK: - RFC 4180

    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = text.makeIterator()
        var pending: Character? = nil

        func endRow() {
            row.append(field)
            field = ""
            if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
            row = []
        }

        while let c = pending ?? chars.next() {
            pending = nil
            if inQuotes {
                if c == "\"" {
                    let next = chars.next()
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        pending = next
                    }
                } else {
                    field.append(c)
                }
                continue
            }
            switch c {
            // Кавычка открывает поле только в его начале; иначе это обычный символ,
            // чтобы забытая открывающая кавычка не склеила следующие строки
            case "\"" where field.isEmpty: inQuotes = true
            case ",": row.append(field); field = ""
            case "\n", "\r\n", "\r": endRow()   // "\r\n" в Swift — один Character
            case "\u{FEFF}": break                 // BOM от Excel
            default: field.append(c)
            }
        }
        endRow()
        return rows
    }
}
