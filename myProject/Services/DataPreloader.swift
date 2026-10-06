import Foundation
import SwiftData
import CryptoKit

@MainActor
final class DataPreloader {
    /// Отпечаток words.csv, загруженного в базу: изменился файл — сливаем изменения при запуске
    private static let bundledHashKey = "bundled_words_hash"
    /// Темы прошлой загруженной версии: так переименованную тему отличаем от папки пользователя
    private static let bundledTopicsKey = "bundled_topics"

    /// Первый запуск — грузим words.csv целиком; файл обновился — сливаем, сохраняя прогресс и свои слова
    static func syncBundledWords(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "csv"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard UserDefaults.standard.string(forKey: bundledHashKey) != hash else { return }

        let dtos = WordCSVParser.parse(text)
        let isEmpty = ((try? context.fetchCount(FetchDescriptor<Word>())) ?? 0) == 0
        if isEmpty {
            insertBundledWords(dtos, context: context)
        } else {
            merge(dtos, context: context)
        }

        // Обновление words.csv могло поменять написание и темы слов
        WordCache.shared.invalidateDictionaryIndex()
        do {
            try context.save()
            UserDefaults.standard.set(hash, forKey: bundledHashKey)
            UserDefaults.standard.set(Array(Set(dtos.map(\.categoryName))), forKey: bundledTopicsKey)
        } catch {
            print("Ошибка загрузки словаря: \(error)")
        }
    }

    private static func insertBundledWords(_ dtos: [WordDTO], context: ModelContext) {
        var categories = CategoryCache(context: context)
        for dto in dtos {
            insertWord(from: dto, category: categories.category(named: dto.categoryName), context: context)
        }
    }

    // MARK: - Слияние обновлённого words.csv

    private static func merge(_ dtos: [WordDTO], context: ModelContext) {
        let allWords = context.fetchAllWords()
        let customWords = allWords.filter(\.isCustom)
        var remaining = Dictionary(grouping: allWords.filter { !$0.isCustom }, by: key)
        var categories = CategoryCache(context: context)
        // Темы из таблицы (новой и прошлой версии); свои папки пользователя синхронизация не трогает и не удаляет.
        // До первой синхронизации прошлых тем не знаем — считаем темами все папки со словами из базы
        let previousTopics = UserDefaults.standard.stringArray(forKey: bundledTopicsKey)
            ?? allWords.filter { !$0.isCustom }.compactMap { $0.category?.name }
        let topicNames = Set(dtos.map(\.categoryName)).union(previousTopics)
        var touchedTopics: [Category] = []

        // Сначала точное совпадение (слово + часть речи + перевод)
        var matched: [(Word, WordDTO)] = []
        var unmatched: [WordDTO] = []
        for dto in dtos {
            if let word = remaining[key(dto)]?.popLast() {
                matched.append((word, dto))
            } else {
                unmatched.append(dto)
            }
        }
        // Затем без перевода, если у слова одно значение и там и там: правка перевода в таблице не сбрасывает прогресс
        var leftovers = Dictionary(grouping: remaining.values.joined(), by: looseKey)
        let unmatchedByLooseKey = Dictionary(grouping: unmatched, by: looseKey)
        var newDTOs: [WordDTO] = []
        for dto in unmatched {
            let loose = looseKey(dto)
            if unmatchedByLooseKey[loose]?.count == 1, leftovers[loose]?.count == 1, let word = leftovers[loose]?.popLast() {
                matched.append((word, dto))
            } else {
                newDTOs.append(dto)
            }
        }

        // Совпавшие: обновляем текст, прогресс FSRS, ошибки и картинка остаются
        for (word, dto) in matched {
            word.english = dto.english
            word.russian = dto.russian
            word.transcription = dto.transcription
            word.example = dto.example
            word.cefrLevel = dto.cefrLevel
            word.partOfSpeech = dto.partOfSpeech
            word.tags = dto.tags
            // Слово, которое пользователь перенёс в свою папку, там и остаётся
            let isInTopic = word.category.map { topicNames.contains($0.name) } ?? true
            let category = categories.category(named: dto.categoryName)
            if isInTopic, word.category?.id != category?.id {
                if let old = word.category { touchedTopics.append(old) }
                word.category = category
            }
        }

        // Новые слова базы. Если такое же слово уже добавлено вручную — объединяем:
        // словари и прогресс переходят к слову из базы, своя копия удаляется
        var customByWord = Dictionary(grouping: customWords) { $0.english.lowercased() }
        for dto in newDTOs {
            let word = insertWord(from: dto, category: categories.category(named: dto.categoryName), context: context)
            let candidates = customByWord[dto.english.lowercased()] ?? []
            guard let custom = candidates.first(where: { $0.partOfSpeech == dto.partOfSpeech })
                    ?? candidates.first(where: { $0.partOfSpeech.isEmpty }) else { continue }
            customByWord[dto.english.lowercased()]?.removeAll { $0 === custom }
            absorb(custom, into: word)
            context.delete(custom)
        }

        // Убранные из таблицы: с прогрессом или в своём словаре — оставляем как своё слово, иначе удаляем
        for word in leftovers.values.joined() {
            if word.reps > 0 || !word.lists.isEmpty {
                word.isCustom = true
            } else {
                if let old = word.category, topicNames.contains(old.name) { touchedTopics.append(old) }
                context.delete(word)
            }
        }

        // Темы из прошлой версии таблицы, которые опустели после переименования или удаления слов
        for category in touchedTopics where !category.isDeleted && category.words.allSatisfy(\.isDeleted) {
            context.delete(category)
        }
    }

    /// Переносит со своего слова на слово из базы словари и прогресс
    private static func absorb(_ custom: Word, into word: Word) {
        for list in custom.lists where !word.lists.contains(where: { $0.id == list.id }) {
            word.lists.append(list)
        }
        word.state = custom.state
        word.difficulty = custom.difficulty
        word.stability = custom.stability
        word.dueDate = custom.dueDate
        word.reps = custom.reps
        word.lapses = custom.lapses
        word.lastReview = custom.lastReview
        word.isMistake = custom.isMistake
        word.imageData = custom.imageData
        word.isImageHidden = custom.isImageHidden
        word.imageNotFound = custom.imageNotFound
        word.imageVariant = custom.imageVariant
    }

    private static func key(_ word: Word) -> String { "\(looseKey(word))|\(word.russian)" }
    private static func key(_ dto: WordDTO) -> String { "\(looseKey(dto))|\(dto.russian)" }
    private static func looseKey(_ word: Word) -> String { "\(word.english.lowercased())|\(word.partOfSpeech)" }
    private static func looseKey(_ dto: WordDTO) -> String { "\(dto.english.lowercased())|\(dto.partOfSpeech)" }

    @discardableResult
    private static func insertWord(from dto: WordDTO, category: Category?, context: ModelContext) -> Word {
        // Регистр не меняем: April, I и имена собственные пишутся с заглавной
        let word = Word(
            english: dto.english,
            russian: dto.russian,
            transcription: dto.transcription,
            example: dto.example,
            category: category,
            cefrLevel: dto.cefrLevel,
            partOfSpeech: dto.partOfSpeech,
            tags: dto.tags
        )
        context.insert(word)
        return word
    }

    /// Темы по имени: существующие берём из базы, недостающие создаём
    private struct CategoryCache {
        private var byName: [String: Category]
        private let context: ModelContext

        init(context: ModelContext) {
            self.context = context
            let existing = (try? context.fetch(FetchDescriptor<Category>())) ?? []
            byName = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        }

        mutating func category(named name: String) -> Category? {
            guard !name.isEmpty, name != "Общий словарь" else { return nil }
            if let cached = byName[name] { return cached }
            let category = Category(name: name)
            context.insert(category)
            byName[name] = category
            return category
        }
    }
}

// MARK: - Сброс картинок

extension DataPreloader {
    /// Версия источников картинок (WordImageService). Поменялись источники — увеличить:
    /// при запуске скачанные картинки сотрутся и загрузятся заново. 2 — без Flickr
    private static let imageSourcesVersion = 2
    private static let imageSourcesVersionKey = "image_sources_version"

    /// Стирает скачанные картинки и отметки «не найдено»; скрытые пользователем картинки остаются скрытыми
    static func resetImagesIfSourcesChanged(context: ModelContext) {
        guard UserDefaults.standard.integer(forKey: imageSourcesVersionKey) < imageSourcesVersion else { return }
        let descriptor = FetchDescriptor<Word>(predicate: #Predicate { word in
            word.imageData != nil || word.imageNotFound || word.imageVariant != 0
        })
        for word in (try? context.fetch(descriptor)) ?? [] {
            word.imageData = nil
            word.imageNotFound = false
            word.imageVariant = 0
        }
        do {
            try context.save()
            UserDefaults.standard.set(imageSourcesVersion, forKey: imageSourcesVersionKey)
        } catch {
            print("Ошибка сброса картинок: \(error)")
        }
    }
}
#if DEBUG
extension DataPreloader {
    /// Удаляет встроенные слова и пустые категории и заново грузит words.csv.
    /// Слова пользователя (isCustom) и профиль не трогает.
    static func forceReloadBundledWords(context: ModelContext) {
        let allWords = (try? context.fetch(FetchDescriptor<Word>())) ?? []
        for word in allWords where !word.isCustom { context.delete(word) }

        let allCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        for category in allCategories where !category.words.contains(where: \.isCustom) {
            context.delete(category)
        }

        try? context.save()
        UserDefaults.standard.removeObject(forKey: bundledHashKey)
        syncBundledWords(context: context)
    }
}
#endif
