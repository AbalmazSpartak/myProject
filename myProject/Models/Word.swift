import Foundation
import SwiftData

enum FSRSState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

enum FSRSRating: Int {
    case again = 1 // Снова (Забыл)
    case hard = 2  // Трудно
    case good = 3  // Хорошо
    case easy = 4  // Легко
}

enum CEFRLevel: String, Codable, CaseIterable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
}

@Model
class Word {
    var english: String
    var russian: String
    var transcription: String
    var example: String = ""
    var category: Category?
    var isMistake: Bool = false
    var cefrLevel: String = "A1"
    var partOfSpeech: String = ""   // n., v., adj., prep. …
    var tags: String = ""           // доп. теги из мастер-базы через запятую (Oxford …)
    var isCustom: Bool = false      // добавлено пользователем — пересев базы не трогает
    var lists: [WordList] = []      // свои словари пользователя, в которых состоит слово
    
    // MARK: - FSRS параметры
    var state: FSRSState = FSRSState.new
    var difficulty: Double = 0.0
    var stability: Double = 0.0
    var dueDate: Date = Date()
    var reps: Int = 0
    var lapses: Int = 0
    var lastReview: Date? = nil

    // MARK: - Картинка из интернета (кэш)
    @Attribute(.externalStorage) var imageData: Data? = nil
    var isImageHidden: Bool = false
    var imageNotFound: Bool = false   // поиск ничего не дал — повторно не ищем
    var imageVariant: Int = 0         // номер кандидата, растёт при «обновить»

    init(english: String, russian: String, transcription: String = "", example: String = "", category: Category? = nil, cefrLevel: String = "A1", partOfSpeech: String = "", tags: String = "", isCustom: Bool = false) {
        self.english = english
        self.russian = russian
        self.transcription = transcription
        self.example = example
        self.category = category
        self.cefrLevel = cefrLevel
        self.partOfSpeech = partOfSpeech
        self.tags = tags
        self.isCustom = isCustom
    }
}

// MARK: - Форматирование для показа

extension Word {
    /// Транскрипция храним без скобок; старые записи могут быть в [..] или /../
    static func bareTranscription(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]/"))
    }

    var displayTranscription: String {
        let bare = Word.bareTranscription(transcription)
        return bare.isEmpty ? "" : "/\(bare)/"
    }

    /// Пример без разметки — для озвучки
    var plainExample: String {
        example.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "")
    }

    /// Пример, разрезанный по первому выделенному слову: "I eat an <b>apple</b>." → ("I eat an ", "apple", ".")
    var clozeParts: (before: String, answer: String, after: String)? {
        guard let open = example.range(of: "<b>"),
              let close = example.range(of: "</b>", range: open.upperBound..<example.endIndex) else {
            return nil
        }
        let answer = String(example[open.upperBound..<close.lowerBound])
        guard !answer.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let strip = { (s: Substring) in String(s).replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "") }
        return (strip(example[..<open.lowerBound]), answer, strip(example[close.upperBound...]))
    }

    /// Пример с целевым словом, выделенным жирным (в базе — <b>слово</b>)
    var attributedExample: AttributedString {
        Word.attributedExample(example)
    }

    static func attributedExample(_ example: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(example)
        while let open = rest.range(of: "<b>"),
              let close = rest.range(of: "</b>", range: open.upperBound..<rest.endIndex) {
            result += AttributedString(String(rest[..<open.lowerBound]))
            var bold = AttributedString(String(rest[open.upperBound..<close.lowerBound]))
            bold.inlinePresentationIntent = .stronglyEmphasized
            result += bold
            rest = rest[close.upperBound...]
        }
        result += AttributedString(String(rest))
        return result
    }
}

extension ModelContext {
    /// Все слова одним запросом. Экраны берут слова так при открытии, а не через @Query:
    /// тот перечитывает ~3000 слов при каждой перерисовке — 0,6 с и больше на любое нажатие.
    func fetchAllWords() -> [Word] {
        (try? fetch(FetchDescriptor<Word>())) ?? []
    }
}
