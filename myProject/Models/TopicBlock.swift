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

/// Таблица: ячейки по строкам; шапкой можно сделать первую строку и первый столбец
struct TopicTable: Codable, Hashable {
    var cells: [[String]] = Array(repeating: Array(repeating: "", count: 3), count: 3)
    var hasHeaderRow = true
    var hasHeaderColumn = false

    static let rowRange = 1...15
    static let columnRange = 1...6

    var rows: Int { cells.count }
    var columns: Int { cells.first?.count ?? 0 }

    /// Новые ячейки пустые, лишние строки и столбцы отрезаются с конца
    mutating func resize(rows: Int, columns: Int) {
        cells = (0..<rows).map { row in
            (0..<columns).map { column in
                row < cells.count && column < cells[row].count ? cells[row][column] : ""
            }
        }
    }
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
