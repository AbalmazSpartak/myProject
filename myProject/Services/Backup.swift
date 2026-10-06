import Foundation
import SwiftData

/// Резервная копия: прогресс слов, свои слова и словари, профиль, статистика, настройки,
/// темы «Сообщества» и (по желанию) книги и аудио. Один JSON-файл — его можно сохранить в iCloud Drive,
/// Google Drive или на iPhone через «Файлы»
nonisolated struct BackupFile: Codable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var createdAt = Date()
    var includesMedia: Bool
    var words: [WordRecord]
    var lists: [ListRecord]
    var categories: [String]
    var profile: ProfileRecord?
    var topics: [TopicRecord]
    var books: [BookRecord]
    /// Настройки приложения и общие с виджетом (статистика, серия) — как есть, в формате plist
    var settings: Data
    var sharedSettings: Data

    struct WordRecord: Codable, Sendable {
        var english: String
        var russian: String
        var partOfSpeech: String
        var transcription: String
        var example: String
        var cefrLevel: String
        var tags: String
        var categoryName: String?
        var isCustom: Bool
        var isMistake: Bool
        var isImageHidden: Bool
        var state: Int
        var difficulty: Double
        var stability: Double
        var dueDate: Date
        var reps: Int
        var lapses: Int
        var lastReview: Date?

        var key: String { [english, partOfSpeech, russian].joined(separator: "|") }
    }

    struct ListRecord: Codable, Sendable {
        var id: UUID
        var name: String
        var createdAt: Date
        var frequencies: [String: Int]
        var wordKeys: [String]
    }

    struct ProfileRecord: Codable, Sendable {
        var name: String
        var avatar: Data?
        var flashcardsEnRuCorrect: Int, flashcardsEnRuTotal: Int
        var flashcardsRuEnCorrect: Int, flashcardsRuEnTotal: Int
        var quizEnRuCorrect: Int, quizEnRuTotal: Int
        var quizRuEnCorrect: Int, quizRuEnTotal: Int
        var tetrisHighScore: Int
    }

    struct TopicRecord: Codable, Sendable {
        var id: UUID
        var section: String
        var title: String
        var text: String
        var words: [TopicWord]
        var createdAt: Date
        var blocksData: Data
        var savedAt: Date?
        var clips: [ClipRecord]
    }

    struct ClipRecord: Codable, Sendable {
        var id: UUID
        var data: Data
        var fileExtension: String
    }

    struct BookRecord: Codable, Sendable {
        var id: UUID
        var title: String
        var author: String
        var addedAt: Date
        var lastOpenedAt: Date?
        var gutenbergID: Int?
        var cover: Data?
        var chaptersData: Data
        var position: Int
    }

    /// Что в копии — для подтверждения перед восстановлением
    var summary: String {
        let learned = words.filter { $0.reps > 0 }.count
        var parts = ["слов с прогрессом: \(learned)", "своих слов: \(words.filter(\.isCustom).count)",
                     "словарей: \(lists.count)", "тем: \(topics.count)"]
        if includesMedia { parts.append("книг: \(books.count)") }
        return parts.joined(separator: ", ")
    }
}

enum BackupError: LocalizedError {
    case unreadable, newerVersion

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Это не резервная копия WordLearner или файл повреждён."
        case .newerVersion: return "Копия сделана в более новой версии приложения — обновите приложение."
        }
    }
}

@MainActor
enum Backup {
    /// Настройки приложения, которые входят в копию. Служебные (хэш словаря, версии картинок) — нет:
    /// после восстановления приложение пересчитает их само
    private static let settingsKeys = [
        "app_theme", "translation_mode", "show_word_images", Haptics.enabledKey, MainMenuLayout.storageKey,
        ReaderSettings.themeKey, ReaderSettings.fontSizeKey, ReaderSettings.fontKey, ReaderSettings.spacingKey,
        ReaderSettings.customTextKey, ReaderSettings.customBackgroundKey, "scan_select_learning",
        DailyReminder.enabledKey, DailyReminder.timeKey,
        SpeechSettings.accentKey, SpeechSettings.rateKey, SpeechSettings.autoSpeakKey,
        DailyNewWords.limitKey, "new_words_day", "new_words_count", SessionLength.key, StudyScope.storageKey,
    ]
    /// Общие с виджетом: оценки по дням, серия дней
    private static let sharedKeys = ["daily_study_ratings", "daily_study_totals", "streak_days", "streak_best", StudyScope.storageKey]

    // MARK: - Создание

    static func make(context: ModelContext, includeMedia: Bool) -> BackupFile {
        let allWords = context.fetchAllWords()
        // Встроенные слова без прогресса и правок в копию не нужны — они есть в приложении
        let words = allWords.filter { $0.isCustom || $0.reps > 0 || $0.isMistake || $0.isImageHidden || !$0.lists.isEmpty }
            .map(record)
        let lists = ((try? context.fetch(FetchDescriptor<WordList>())) ?? []).map { list in
            BackupFile.ListRecord(id: list.id, name: list.name, createdAt: list.createdAt, frequencies: list.frequencies,
                                  wordKeys: list.words.map(AppGroup.key(of:)))
        }
        let categories = ((try? context.fetch(FetchDescriptor<Category>())) ?? []).map(\.name)
        // Профилей в базе бывает несколько (создавались при первом открытии экранов) — берём тот, где больше данных
        let profile = ((try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])
            .max { ($0.totalAnswers + $0.tetrisHighScore) < ($1.totalAnswers + $1.tetrisHighScore) }
            .map { p in
            BackupFile.ProfileRecord(
                name: p.name, avatar: p.avatarData,
                flashcardsEnRuCorrect: p.flashcardsEnRuCorrect, flashcardsEnRuTotal: p.flashcardsEnRuTotal,
                flashcardsRuEnCorrect: p.flashcardsRuEnCorrect, flashcardsRuEnTotal: p.flashcardsRuEnTotal,
                quizEnRuCorrect: p.quizEnRuCorrect, quizEnRuTotal: p.quizEnRuTotal,
                quizRuEnCorrect: p.quizRuEnCorrect, quizRuEnTotal: p.quizRuEnTotal,
                tetrisHighScore: p.tetrisHighScore)
        }
        let topics = ((try? context.fetch(FetchDescriptor<CommunityTopic>())) ?? []).filter(\.isMine).map { topic in
            BackupFile.TopicRecord(
                id: topic.id, section: topic.section, title: topic.title, text: topic.text, words: topic.words,
                createdAt: topic.createdAt, blocksData: topic.blocksData, savedAt: topic.savedAt,
                clips: includeMedia ? topic.audioClips.map { .init(id: $0.id, data: $0.data, fileExtension: $0.fileExtension) } : [])
        }
        let books = includeMedia ? ((try? context.fetch(FetchDescriptor<Book>())) ?? []).map { book in
            BackupFile.BookRecord(id: book.id, title: book.title, author: book.author, addedAt: book.addedAt,
                                  lastOpenedAt: book.lastOpenedAt, gutenbergID: book.gutenbergID, cover: book.coverData,
                                  chaptersData: book.chaptersData, position: book.position)
        } : []
        return BackupFile(includesMedia: includeMedia, words: words, lists: lists, categories: categories, profile: profile,
                          topics: topics, books: books,
                          settings: plist(from: .standard, keys: settingsKeys),
                          sharedSettings: plist(from: AppGroup.defaults, keys: sharedKeys))
    }

    private static func record(_ word: Word) -> BackupFile.WordRecord {
        BackupFile.WordRecord(
            english: word.english, russian: word.russian, partOfSpeech: word.partOfSpeech,
            transcription: word.transcription, example: word.example, cefrLevel: word.cefrLevel, tags: word.tags,
            categoryName: word.category?.name, isCustom: word.isCustom, isMistake: word.isMistake,
            isImageHidden: word.isImageHidden, state: word.state.rawValue, difficulty: word.difficulty,
            stability: word.stability, dueDate: word.dueDate, reps: word.reps, lapses: word.lapses, lastReview: word.lastReview)
    }

    private static func plist(from defaults: UserDefaults, keys: [String]) -> Data {
        var values: [String: Any] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) { values[key] = value }
        }
        return (try? PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)) ?? Data()
    }

    nonisolated static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    nonisolated static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: data) else { throw BackupError.unreadable }
        guard backup.version <= BackupFile.currentVersion else { throw BackupError.newerVersion }
        return backup
    }

    static func fileName(for date: Date = Date()) -> String {
        "WordLearner-\(date.formatted(.iso8601.year().month().day()))"
    }

    // MARK: - Восстановление: текущее заменяется тем, что в копии

    /// Перед заменой текущие данные сохраняются в «Документы» приложения — на случай, если копия окажется не той
    static func restore(_ backup: BackupFile, context: ModelContext) throws {
        let safety = make(context: context, includeMedia: true)
        if let data = try? encode(safety) {
            let url = URL.documentsDirectory.appending(path: "Перед восстановлением \(fileName()).json")
            try? data.write(to: url)
        }

        // 1. Убираем своё: свои слова, словари, свои темы, книги; у встроенных слов — сбрасываем прогресс
        for word in context.fetchAllWords() {
            if word.isCustom {
                context.delete(word)
            } else {
                resetProgress(word)
            }
        }
        for list in (try? context.fetch(FetchDescriptor<WordList>())) ?? [] { context.delete(list) }
        for topic in ((try? context.fetch(FetchDescriptor<CommunityTopic>())) ?? []).filter(\.isMine) { context.delete(topic) }
        if backup.includesMedia {
            for book in (try? context.fetch(FetchDescriptor<Book>())) ?? [] { context.delete(book) }
        }

        // 2. Темы-папки: недостающие создаём
        var categories = Dictionary(((try? context.fetch(FetchDescriptor<Category>())) ?? []).map { ($0.name, $0) },
                                    uniquingKeysWith: { first, _ in first })
        for name in backup.categories where categories[name] == nil {
            let category = Category(name: name)
            context.insert(category)
            categories[name] = category
        }

        // 3. Слова: встроенным — прогресс, свои — заново
        var byKey: [String: Word] = [:]
        for word in context.fetchAllWords() where !word.isCustom { byKey[AppGroup.key(of: word)] = word }
        for record in backup.words {
            let word: Word
            if !record.isCustom, let existing = byKey[record.key] {
                word = existing
            } else {
                word = Word(english: record.english, russian: record.russian, transcription: record.transcription,
                            example: record.example, cefrLevel: record.cefrLevel, partOfSpeech: record.partOfSpeech,
                            tags: record.tags, isCustom: true)
                context.insert(word)
                byKey[record.key] = word
            }
            if let name = record.categoryName { word.category = categories[name] }
            word.isMistake = record.isMistake
            word.isImageHidden = record.isImageHidden
            word.state = FSRSState(rawValue: record.state) ?? .new
            word.difficulty = record.difficulty
            word.stability = record.stability
            word.dueDate = record.dueDate
            word.reps = record.reps
            word.lapses = record.lapses
            word.lastReview = record.lastReview
        }

        // 4. Словари — с теми же id: на них ссылается выбор словарей для изучения
        for record in backup.lists {
            let list = WordList(name: record.name)
            list.id = record.id
            list.createdAt = record.createdAt
            list.frequencies = record.frequencies
            context.insert(list)
            for key in record.wordKeys {
                if let word = byKey[key], !word.lists.contains(where: { $0.id == list.id }) { word.lists.append(list) }
            }
        }

        // 5. Профиль
        if let record = backup.profile {
            apply(record, to: UserProfile.ensureSingle(in: context))
        }


        // 6. Свои темы «Сообщества» и их записи
        for record in backup.topics {
            let topic = CommunityTopic(section: record.section, title: record.title, blocks: [], words: record.words)
            topic.id = record.id
            topic.text = record.text
            topic.createdAt = record.createdAt
            topic.blocksData = record.blocksData
            topic.savedAt = record.savedAt
            topic.isMine = true
            context.insert(topic)
            for clipRecord in record.clips {
                let clip = TopicAudioClip(id: clipRecord.id, data: clipRecord.data, fileExtension: clipRecord.fileExtension)
                context.insert(clip)
                clip.topic = topic
            }
        }

        // 7. Книги — с местом чтения
        for record in backup.books {
            let chapters = (try? JSONDecoder().decode([BookChapter].self, from: record.chaptersData)) ?? []
            let book = Book(ParsedBook(title: record.title, author: record.author, cover: record.cover, chapters: chapters),
                            gutenbergID: record.gutenbergID)
            book.id = record.id
            book.addedAt = record.addedAt
            book.lastOpenedAt = record.lastOpenedAt
            book.position = record.position
            context.insert(book)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        // 8. Настройки и статистика — после того как данные сохранены
        apply(backup.settings, to: .standard)
        apply(backup.sharedSettings, to: AppGroup.defaults)
        WordCache.shared.invalidateDictionaryIndex()
    }

    private static func apply(_ record: BackupFile.ProfileRecord, to profile: UserProfile) {
        profile.name = record.name
        profile.avatarData = record.avatar
        profile.flashcardsEnRuCorrect = record.flashcardsEnRuCorrect
        profile.flashcardsEnRuTotal = record.flashcardsEnRuTotal
        profile.flashcardsRuEnCorrect = record.flashcardsRuEnCorrect
        profile.flashcardsRuEnTotal = record.flashcardsRuEnTotal
        profile.quizEnRuCorrect = record.quizEnRuCorrect
        profile.quizEnRuTotal = record.quizEnRuTotal
        profile.quizRuEnCorrect = record.quizRuEnCorrect
        profile.quizRuEnTotal = record.quizRuEnTotal
        profile.tetrisHighScore = record.tetrisHighScore
    }

    private static func resetProgress(_ word: Word) {
        word.isMistake = false
        word.state = .new
        word.difficulty = 0
        word.stability = 0
        word.dueDate = Date()
        word.reps = 0
        word.lapses = 0
        word.lastReview = nil
        word.lists = []
    }

    private static func apply(_ data: Data, to defaults: UserDefaults) {
        guard let values = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return }
        for (key, value) in values { defaults.set(value, forKey: key) }
    }
}
