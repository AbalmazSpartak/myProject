import Foundation
import SwiftData

/// Блок темы сообщества. Тема собирается из блоков в любом порядке: подзаголовок, текст, таблица, аудио
struct TopicBlock: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case heading, text, table, audio

        var title: String {
            switch self {
            case .heading: return "Подзаголовок"
            case .text: return "Текст"
            case .table: return "Таблица"
            case .audio: return "Аудио"
            }
        }

        var icon: String {
            switch self {
            case .heading: return "textformat.size"
            case .text: return "text.alignleft"
            case .table: return "tablecells"
            case .audio: return "waveform"
            }
        }
    }

    /// Запись голосом — для авторов, готовый файл — для аудиоуроков, озвучка — услышать фразу целиком
    enum AudioSource: String, Codable, CaseIterable {
        case recording, file, speech

        var title: String {
            switch self {
            case .recording: return "Запись"
            case .file: return "Файл"
            case .speech: return "Озвучка"
            }
        }
    }

    var id = UUID()
    var kind: Kind
    /// Подзаголовок, текст или подпись к аудио
    var text = ""
    var table = TopicTable()
    var audioSource = AudioSource.recording
    /// Английский текст для озвучки (audioSource == .speech)
    var speechText = ""
    /// Запись или файл — TopicAudioClip.id
    var audioClipID: UUID?
    /// Имя прикреплённого файла — показать автору, что прикреплено
    var audioFileName = ""

    init(kind: Kind) {
        self.kind = kind
    }
}

/// Таблица: ячейки по строкам; шапкой можно сделать первую строку и столбец подписей (слева или справа).
/// Ячейки объединяются вправо и вниз, у каждой — свой цвет, курсив, выравнивание, вертикальный текст
struct TopicTable: Codable, Hashable {
    var cells: [[String]] = Array(repeating: Array(repeating: "", count: 3), count: 3)
    var hasHeaderRow = true
    var hasHeaderColumn = false
    /// Столбец подписей — последний, а не первый («Будущее», «Настоящее» справа)
    var labelsOnRight = false
    /// Стили и объединения — только у ячеек, где они отличаются от обычных; ключ — «строка:столбец»
    var styles: [String: TableCellStyle] = [:]

    static let rowRange = 1...15
    static let columnRange = 1...12

    init() {}

    var rows: Int { cells.count }
    var columns: Int { cells.first?.count ?? 0 }

    // MARK: - Стиль и шапка

    func style(row: Int, column: Int) -> TableCellStyle {
        styles[Self.key(row, column)] ?? TableCellStyle()
    }

    mutating func setStyle(_ style: TableCellStyle, row: Int, column: Int) {
        styles[Self.key(row, column)] = style == TableCellStyle() ? nil : style
    }

    func isHeader(row: Int, column: Int) -> Bool {
        (hasHeaderRow && row == 0)
            || (hasHeaderColumn && column == (labelsOnRight ? columns - 1 : 0))
    }

    // MARK: - Объединение

    struct Cell: Identifiable, Hashable {
        let row: Int
        let column: Int
        let style: TableCellStyle
        var id: String { TopicTable.key(row, column) }
    }

    /// Ячейки, которые видно: обычные и левые верхние у объединённых; спрятанные под объединением пропускаем
    var visibleCells: [Cell] {
        let covered = coveredCells
        return (0..<rows).flatMap { row in
            (0..<columns).compactMap { column in
                covered.contains(Self.key(row, column)) ? nil : Cell(row: row, column: column, style: style(row: row, column: column))
            }
        }
    }

    /// Ячейки под объединением (кроме левой верхней) — их текст не показывается, но хранится до «Разделить»
    private var coveredCells: Set<String> {
        var covered: Set<String> = []
        for (key, style) in styles where style.rowSpan > 1 || style.columnSpan > 1 {
            guard let (row, column) = Self.position(key) else { continue }
            for r in row..<min(row + style.rowSpan, rows) {
                for c in column..<min(column + style.columnSpan, columns) where r != row || c != column {
                    covered.insert(Self.key(r, c))
                }
            }
        }
        return covered
    }

    /// Свободна — не объединена сама и не спрятана под другим объединением
    private func isFree(_ row: Int, _ column: Int) -> Bool {
        let style = style(row: row, column: column)
        return style.rowSpan == 1 && style.columnSpan == 1 && !coveredCells.contains(Self.key(row, column))
    }

    func canMergeRight(row: Int, column: Int) -> Bool {
        let style = style(row: row, column: column)
        let next = column + style.columnSpan
        guard next < columns else { return false }
        return (row..<min(row + style.rowSpan, rows)).allSatisfy { isFree($0, next) }
    }

    func canMergeDown(row: Int, column: Int) -> Bool {
        let style = style(row: row, column: column)
        let next = row + style.rowSpan
        guard next < rows else { return false }
        return (column..<min(column + style.columnSpan, columns)).allSatisfy { isFree(next, $0) }
    }

    mutating func mergeRight(row: Int, column: Int) {
        guard canMergeRight(row: row, column: column) else { return }
        var style = style(row: row, column: column)
        style.columnSpan += 1
        setStyle(style, row: row, column: column)
    }

    mutating func mergeDown(row: Int, column: Int) {
        guard canMergeDown(row: row, column: column) else { return }
        var style = style(row: row, column: column)
        style.rowSpan += 1
        setStyle(style, row: row, column: column)
    }

    mutating func split(row: Int, column: Int) {
        var style = style(row: row, column: column)
        style.rowSpan = 1
        style.columnSpan = 1
        setStyle(style, row: row, column: column)
    }

    // MARK: - Размер

    /// Новые ячейки пустые, лишние строки и столбцы отрезаются с конца; объединения укорачиваются по краю
    mutating func resize(rows: Int, columns: Int) {
        cells = (0..<rows).map { row in
            (0..<columns).map { column in
                row < cells.count && column < cells[row].count ? cells[row][column] : ""
            }
        }
        var kept: [String: TableCellStyle] = [:]
        for (key, style) in styles {
            guard let (row, column) = Self.position(key), row < rows, column < columns else { continue }
            var style = style
            style.rowSpan = min(style.rowSpan, rows - row)
            style.columnSpan = min(style.columnSpan, columns - column)
            kept[key] = style
        }
        styles = kept
    }

    static func key(_ row: Int, _ column: Int) -> String { "\(row):\(column)" }

    private static func position(_ key: String) -> (Int, Int)? {
        let parts = key.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    // Таблицы первой версии — без labelsOnRight и styles
    private enum CodingKeys: String, CodingKey {
        case cells, hasHeaderRow, hasHeaderColumn, labelsOnRight, styles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cells = try container.decode([[String]].self, forKey: .cells)
        hasHeaderRow = try container.decode(Bool.self, forKey: .hasHeaderRow)
        hasHeaderColumn = try container.decode(Bool.self, forKey: .hasHeaderColumn)
        labelsOnRight = try container.decodeIfPresent(Bool.self, forKey: .labelsOnRight) ?? false
        styles = try container.decodeIfPresent([String: TableCellStyle].self, forKey: .styles) ?? [:]
    }
}

/// Оформление ячейки таблицы и её объединение с соседними
struct TableCellStyle: Codable, Hashable {
    enum Tone: String, Codable, CaseIterable {
        case normal, red, gray

        var title: String {
            switch self {
            case .normal: return "Обычный"
            case .red: return "Красный"
            case .gray: return "Серый"
            }
        }
    }

    enum Alignment: String, Codable, CaseIterable {
        case leading, center, trailing

        var title: String {
            switch self {
            case .leading: return "По левому краю"
            case .center: return "По центру"
            case .trailing: return "По правому краю"
            }
        }
    }

    var rowSpan = 1
    var columnSpan = 1
    var tone = Tone.normal
    var italic = false
    var alignment = Alignment.center
    /// Буквы друг под другом — подпись сбоку («Б у д у щ е е»)
    var vertical = false
}

/// Звук блока «Аудио» (запись или файл). Отдельной моделью — чтобы большие файлы лежали вне базы
@Model
final class TopicAudioClip {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data
    /// m4a, mp3 … — подсказка плееру
    var fileExtension: String
    var topic: CommunityTopic?

    init(id: UUID, data: Data, fileExtension: String) {
        self.id = id
        self.data = data
        self.fileExtension = fileExtension
    }
}
