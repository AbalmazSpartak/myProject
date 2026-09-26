import Foundation
import SwiftData

@MainActor
final class DataPreloader {
    static func preloadSampleWords(context: ModelContext) {
        let descriptor = FetchDescriptor<Word>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }
        
        guard let url = Bundle.main.url(forResource: "sample_words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        do {
            let dtoWords = try JSONDecoder().decode([WordDTO].self, from: data)
            var categoryCache: [String: Category] = [:]
            
            for dto in dtoWords {
                let cleanEnglish = dto.english.lowercased()
                
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
                
                let newWord = Word(
                    english: cleanEnglish,
                    russian: dto.russian,
                    transcription: dto.transcription,
                    example: dto.example,
                    category: category
                )
                context.insert(newWord)
            }
            try context.save()
        } catch {
            print("Ошибка предзагрузки: \(error)")
        }
    }
}
