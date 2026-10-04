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
    /// Сам запрос тоже дорогой (SwiftData собирает каждое слово заново: ~0,5 с в симуляторе, секунды на телефоне),
    /// поэтому слова один раз загружаются в WordCache, а дальше берутся оттуда
    func fetchAllWords(sortBy: [SortDescriptor<Word>] = []) -> [Word] {
        let words = WordCache.shared.words(in: self)
        return sortBy.isEmpty ? words : words.sorted(using: sortBy)
    }
}

/// Слова основного контекста в памяти. Это те же объекты, что в базе: прогресс, ошибки, картинки меняются в них сразу.
/// Заново из базы — только когда слова добавили или удалили (сохранение с новыми или удалёнными словами)
@MainActor
final class WordCache {
    static let shared = WordCache()

    private var words: [Word]?
    /// Контекст, для которого собран кэш; у других контекстов — обычный запрос
    private weak var context: ModelContext?
    private var observer: NSObjectProtocol?

    private init() {}

    func words(in context: ModelContext) -> [Word] {
        // Несохранённые новые или удалённые слова — кэш их не знает, читаем из контекста как есть
        let hasPendingWordChanges = context.insertedModelsArray.contains { $0 is Word }
            || context.deletedModelsArray.contains { $0 is Word }
        // Число слов в базе — страховка, если кто-то спросит слова раньше, чем дойдёт уведомление о сохранении (1 мс)
        if let words, self.context === context, !hasPendingWordChanges,
           (try? context.fetchCount(FetchDescriptor<Word>())) == words.count {
            return words.filter { !$0.isDeleted }
        }
        let fetched = (try? context.fetch(FetchDescriptor<Word>())) ?? []
        if self.context !== context {
            guard self.context == nil else { return fetched } // второй контекст не кэшируем
            self.context = context
            observe(context)
        }
        words = hasPendingWordChanges ? nil : fetched
        return fetched
    }

    private func observe(_ context: ModelContext) {
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: .main) { notification in
            let changed = [ModelContext.NotificationKey.insertedIdentifiers, .deletedIdentifiers].contains { key in
                let identifiers = notification.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
                return identifiers.contains { $0.entityName == "Word" }
            }
            guard changed else { return }
            MainActor.assumeIsolated { WordCache.shared.words = nil }
        }
    }
}
