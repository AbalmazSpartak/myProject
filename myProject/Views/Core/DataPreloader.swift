import Foundation
import SwiftData

@MainActor
final class DataPreloader {
    static func preloadSampleWords(context: ModelContext) {
        let descriptor = FetchDescriptor<Word>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }

        insertBundledWords(context: context)
    }

    /// Загружает встроенный словарь из words.csv (мастер-база)
    private static func insertBundledWords(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "csv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }

        let existingCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        var categoryCache = Dictionary(existingCategories.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        for dto in WordCSVParser.parse(text) {
            let category: Category?
            if dto.categoryName.isEmpty || dto.categoryName == "Общий словарь" {
                category = nil
            } else if let cached = categoryCache[dto.categoryName] {
                category = cached
            } else {
                let newCategory = Category(name: dto.categoryName)
                context.insert(newCategory)
                categoryCache[dto.categoryName] = newCategory
                category = newCategory
            }

            // Регистр не меняем: April, I и имена собственные пишутся с заглавной
            let newWord = Word(
                english: dto.english,
                russian: dto.russian,
                transcription: dto.transcription,
                example: dto.example,
                category: category,
                cefrLevel: dto.cefrLevel,
                partOfSpeech: dto.partOfSpeech,
                tags: dto.tags
            )
            context.insert(newWord)
        }

        do {
            try context.save()
        } catch {
            print("Ошибка предзагрузки: \(error)")
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
        insertBundledWords(context: context)
    }
}
#endif
