import Foundation
import SwiftData
import CryptoKit

/// Встроенный словарь «Интерфейс приложений»: слова с экранов телефона и приложений (Settings, Undo, Swipe).
/// Состав — interface_words.txt («слово|часть речи|перевод», как в words.csv); сами карточки живут в words.csv.
/// Словарь появляется сам один раз. Удалил пользователь — не возвращается; обновлённый файл дополняет оставшийся словарь
enum InterfaceDictionary {
    static let name = "Интерфейс приложений"
    private static let hashKey = "interface_dictionary_hash"
    private static let listIDKey = "interface_dictionary_id"

    /// Вызывать после DataPreloader.syncBundledWords: новые карточки из words.csv уже должны быть в базе
    static func sync(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "interface_words", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: hashKey) != hash else { return }

        let lists = (try? context.fetch(FetchDescriptor<WordList>())) ?? []
        let list: WordList
        if let id = defaults.string(forKey: listIDKey).flatMap(UUID.init(uuidString:)) {
            // После восстановления из копии у словаря новый id — узнаём его по названию
            let byID = lists.first { $0.id == id }
            guard let existing = byID ?? lists.first(where: { $0.name == name }) else {
                defaults.set(hash, forKey: hashKey)   // словарь удалён пользователем — не возвращаем
                return
            }
            list = existing
        } else {
            list = WordList.named(name, context: context)
        }

        let wanted = Set(entries(in: text))
        for word in context.fetchAllWords() where wanted.contains(key(word.english, word.partOfSpeech, word.russian)) {
            if !word.lists.contains(where: { $0.id == list.id }) {
                word.lists.append(list)
            }
        }
        do {
            try context.save()
            defaults.set(list.id.uuidString, forKey: listIDKey)
            defaults.set(hash, forKey: hashKey)
        } catch {
            print("Ошибка словаря «\(name)»: \(error)")
        }
    }

    /// Ключи слов из файла; строки с # и пустые пропускаем
    static func entries(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 3 else { return nil }
            return key(parts[0], parts[1], parts[2])
        }
    }

    static func key(_ english: String, _ partOfSpeech: String, _ russian: String) -> String {
        "\(english.lowercased())|\(partOfSpeech)|\(russian)"
    }
}
