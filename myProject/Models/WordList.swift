import Foundation
import SwiftData

/// Свой словарь пользователя (например, слова из отсканированного текста).
/// В отличие от темы (Category), слово может состоять в нескольких словарях и не уходит из своей темы.
@Model
final class WordList {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Word.lists)
    var words: [Word] = []

    /// Сколько раз слово встретилось в файле, из которого создан словарь (ключ — WordList.frequencyKey).
    /// Новые слова такого словаря идут на изучение первыми — от самых частых
    var frequencies: [String: Int] = [:]

    static func frequencyKey(_ word: Word) -> String {
        word.english.lowercased()
    }

    /// Частота слова в словарях из файлов; 0 — слово не из файла
    static func frequency(of word: Word) -> Int {
        let key = frequencyKey(word)
        return word.lists.reduce(0) { max($0, $1.frequencies[key] ?? 0) }
    }

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
}
