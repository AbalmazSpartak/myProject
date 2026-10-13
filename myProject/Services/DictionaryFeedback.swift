import Foundation
import SwiftData

/// Сигналы для улучшения встроенного словаря — анонимно, без имени и почты:
/// edit — пользователь поправил слово из базы, context — добавил слово из текста (в каком значении),
/// missing — слова нет в базе, hard — слово упорно не запоминается. Очередь — как у «Сообщить об ошибке»
enum DictionarySignals {
    /// Настройки → «Помогать улучшать словарь»; по умолчанию включено
    static let enabledKey = "improve_dictionary"

    struct Signal: Codable {
        var id = UUID().uuidString
        var install = DictionarySignals.installID
        let kind: String
        let word: String
        let partOfSpeech: String
        var field = ""
        var old = ""
        var new = ""
        var sentence = ""
    }

    static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }

    /// Случайный номер установки — чтобы считать, сколько разных людей предложили одно и то же. Ни с кем не связан
    static var installID: String {
        if let id = UserDefaults.standard.string(forKey: "install_id") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "install_id")
        return id
    }

    private static let queueKey = "dictionary_signals_queue"
    private static let endpoint = OnlineRaceManager.baseURL.appending(path: "signals")

    static func record(_ signal: Signal) {
        guard isEnabled else { return }
        // Очередь не растёт бесконечно, если интернета долго нет
        save(Array((load() + [signal]).suffix(300)))
        Task { await flush() }
    }

    /// Правка слова из базы: что было и что стало, по полям
    static func recordEdit(_ word: Word, original: [String: String]) {
        let current = fields(of: word)
        for (field, old) in original where current[field] != old {
            record(Signal(kind: "edit", word: original["english"] ?? word.english, partOfSpeech: original["partOfSpeech"] ?? word.partOfSpeech,
                          field: field, old: old, new: current[field] ?? ""))
            DictionaryPatch.markEdited(english: original["english"] ?? word.english, partOfSpeech: original["partOfSpeech"] ?? word.partOfSpeech,
                                       russian: original["russian"] ?? word.russian, field: field)
        }
    }

    /// Слово — 3 раза «Снова»: возможно, перевод неудачный или неоднозначный. Отправляется один раз на слово
    static func recordHardIfNeeded(_ word: Word) {
        guard !word.isCustom, word.lapses == 3 else { return }
        record(Signal(kind: "hard", word: word.english, partOfSpeech: word.partOfSpeech, field: "russian", old: word.russian))
    }

    static func fields(of word: Word) -> [String: String] {
        ["english": word.english, "russian": word.russian, "transcription": word.transcription, "example": word.example,
         "cefrLevel": word.cefrLevel, "partOfSpeech": word.partOfSpeech]
    }

    static func flush() async {
        let pending = load()
        guard !pending.isEmpty else { return }
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let batch = Array(pending.prefix(50))
        request.httpBody = try? JSONEncoder().encode(batch)
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        let sent = Set(batch.map(\.id))
        save(load().filter { !sent.contains($0.id) })
        if load().count > 0 { await flush() }
    }

    private static func load() -> [Signal] {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return [] }
        return (try? JSONDecoder().decode([Signal].self, from: data)) ?? []
    }

    private static func save(_ signals: [Signal]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(signals), forKey: queueKey)
    }
}

/// Патч словаря: одобренные правки встроенных слов приходят с сервера без обновления приложения.
/// Применяется при каждом запуске (после words.csv) — повторно безопасно. Свою правку пользователя патч не перезаписывает
enum DictionaryPatch {
    struct Entry: Codable {
        let version: Int
        let word: String
        let part_of_speech: String
        let match_russian: String
        let field: String
        let value: String
    }

    private static let entriesKey = "dictionary_patch_entries"
    private static let editedKey = "dictionary_user_edited"
    private static let lastCheckKey = "dictionary_patch_checked"
    private static let endpoint = OnlineRaceManager.baseURL.appending(path: "patch")

    /// Скачать новые правки (не чаще раза в 6 часов) и применить все
    @MainActor
    static func sync(context: ModelContext) async {
        var entries = load()
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 6 * 3600 {
            let since = entries.map(\.version).max() ?? 0
            var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "since", value: String(since))]
            if let url = components.url, let (data, response) = try? await URLSession.shared.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let fresh = try? JSONDecoder().decode(Response.self, from: data) {
                entries += fresh.entries
                save(entries)
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            }
        }
        apply(entries, context: context)
    }

    private struct Response: Decodable { let entries: [Entry] }

    /// Правка — слову из базы с тем же написанием, частью речи и переводом, который был до правки
    @MainActor
    static func apply(_ entries: [Entry], context: ModelContext) {
        guard !entries.isEmpty else { return }
        let edited = Set(UserDefaults.standard.stringArray(forKey: editedKey) ?? [])
        var changed = false
        for entry in entries.sorted(by: { $0.version < $1.version }) {
            let english = entry.word, pos = entry.part_of_speech, match = entry.match_russian
            let descriptor = FetchDescriptor<Word>(predicate: #Predicate {
                !$0.isCustom && $0.english == english && $0.partOfSpeech == pos && (match == "" || $0.russian == match)
            })
            for word in (try? context.fetch(descriptor)) ?? [] {
                guard !edited.contains(editKey(english, pos, word.russian, entry.field)) else { continue }
                switch entry.field {
                case "russian": if word.russian != entry.value { word.russian = entry.value; changed = true }
                case "transcription": if word.transcription != entry.value { word.transcription = entry.value; changed = true }
                case "example": if word.example != entry.value { word.example = entry.value; changed = true }
                case "cefrLevel": if word.cefrLevel != entry.value { word.cefrLevel = entry.value; changed = true }
                case "partOfSpeech": if word.partOfSpeech != entry.value { word.partOfSpeech = entry.value; changed = true }
                default: break
                }
            }
        }
        if changed { try? context.save() }
    }

    /// Пользователь сам поправил поле — патч его не трогает
    static func markEdited(english: String, partOfSpeech: String, russian: String, field: String) {
        var edited = UserDefaults.standard.stringArray(forKey: editedKey) ?? []
        edited.append(editKey(english, partOfSpeech, russian, field))
        UserDefaults.standard.set(Array(Set(edited)), forKey: editedKey)
    }

    private static func editKey(_ english: String, _ pos: String, _ russian: String, _ field: String) -> String {
        "\(english.lowercased())|\(pos)|\(russian)|\(field)"
    }

    private static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: entriesKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private static func save(_ entries: [Entry]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: entriesKey)
    }
}
