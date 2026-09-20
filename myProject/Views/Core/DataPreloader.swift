import Foundation
import SwiftData

@MainActor
final class DataPreloader {
    
    /// Наполняет SwiftData из встроенного JSON-файла, если база пуста
    static func preloadSampleWords(context: ModelContext) {
        // Оптимизация производительности №3: мгновенный fetchCount для проверки лимитов
        let descriptor = FetchDescriptor<Word>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else {
            return // База данных уже содержит слова. Защита от дублирования при перезапусках.
        }
        
        // Поиск файла "sample_words.json" в Bundle приложения
        guard let url = Bundle.main.url(forResource: "sample_words", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ Файл sample_words.json не найден в ресурсах приложения")
            return
        }
        
        do {
            // Быстрый системный парсинг без ручного разделения строк
            let dtoWords = try JSONDecoder().decode([WordDTO].self, from: data)
            
            // Кэш для категорий во избежание дублирования папок на диске
            var categoryCache: [String: Category] = [:]
            
            for dto in dtoWords {
                // Архитектурное требование: английские слова ВСЕГДА в нижнем регистре
                let cleanEnglish = dto.english.lowercased()
                
                // Проверяем категорию (папку) в кэше, либо создаем новую
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
                
                // Создание финальной SwiftData-карточки слова
                let newWord = Word(
                    english: cleanEnglish,
                    russian: dto.russian,
                    example: dto.example,
                    transcription: dto.transcription,
                    category: category
                )
                
                // Вставка в контекст
                context.insert(newWord)
            }
            
            // Фиксация изменений в локальной СУБД SQLite
            try context.save()
            print("✅ Успешно импортировано стартовых слов: \(dtoWords.count)")
            
        } catch {
            print("❌ Ошибка при декодировании или сохранении JSON: \(error)")
        }
    }
}
