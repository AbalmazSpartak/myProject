import Foundation

/// Перевод новых слов словаря из книги ИИ (Claude Haiku на сервере wordlearner-ai): по предложению из книги —
/// значение именно в нём, словарная форма, часть речи и вид слова (обычное, диалект, имя…).
/// На проверке 300 слов «Гекльберри Финна» — 97% верно (переводчик iOS — 69%). На сервер уходят слово,
/// предложение и случайный номер установки; уже переведённое кем-то — из общего кэша, бесплатно
enum BookWordsAI {
    /// Как переводить новые слова: "" — спрашивать, "ai" — ИИ, "apple" — встроенный переводчик
    static let choiceKey = "book_words_translator"

    nonisolated struct Item: Encodable, Sendable {
        let word: String
        let pos: String
        /// Предложение из книги, слово выделено <b>…</b>
        let sentence: String
    }

    nonisolated struct Entry: Decodable, Sendable {
        let lemma: String
        let pos: String
        let ru: String
        /// word | dialect | name | junk | function
        let kind: String
        let note: String

        /// Имя, обрывок или служебное слово — в словарь для учёбы не нужно
        var isStudyWord: Bool { kind == "word" || kind == "dialect" }
    }

    nonisolated enum Problem: Sendable {
        /// Дневной запас перевода ИИ кончился
        case limit
        /// Нет сети или сервер не ответил
        case failed
    }

    private nonisolated struct Request: Encodable {
        let install: String
        let items: [Item]
    }

    private nonisolated struct Response: Decodable {
        let items: [Entry?]
    }

    static let batchSize = 50
    private static let parallel = 4

    /// Переводит всё, что успеет; progress — сколько слов обработано. Непереведённое (сеть, лимит) — нет в ответе
    static func translate(_ items: [(id: String, item: Item)], progress: @MainActor (Int) -> Void) async
        -> (entries: [String: Entry], problem: Problem?) {
        let install = DictionarySignals.installID
        let batches = stride(from: 0, to: items.count, by: batchSize).map { Array(items[$0..<min($0 + batchSize, items.count)]) }
        var entries: [String: Entry] = [:]
        var problem: Problem?
        var done = 0
        // Волнами по несколько пачек: книга — десятки пачек, по одной было бы долго
        for start in stride(from: 0, to: batches.count, by: parallel) {
            let wave = batches[start..<min(start + parallel, batches.count)]
            let results = await withTaskGroup(of: (batch: [(id: String, item: Item)], result: Result<[Entry?], ProblemError>).self) { group in
                for batch in wave {
                    group.addTask { (batch, await send(batch.map(\.item), install: install)) }
                }
                var collected: [(batch: [(id: String, item: Item)], result: Result<[Entry?], ProblemError>)] = []
                for await result in group { collected.append(result) }
                return collected
            }
            for (batch, result) in results {
                switch result {
                case .success(let answers):
                    for (index, answer) in answers.enumerated() where index < batch.count {
                        if let answer { entries[batch[index].id] = answer }
                    }
                case .failure(let error):
                    problem = error.problem == .limit ? .limit : (problem ?? .failed)
                }
                done += batch.count
            }
            progress(done)
            // Запас кончился — остальное переведёт встроенный переводчик
            if problem == .limit { break }
        }
        return (entries, problem)
    }

    private nonisolated struct ProblemError: Error {
        let problem: Problem
    }

    private nonisolated static func send(_ items: [Item], install: String) async -> Result<[Entry?], ProblemError> {
        var request = URLRequest(url: CloudContext.baseURL.appending(path: "words"), timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Request(install: install, items: items))
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .failure(ProblemError(problem: .failed)) }
        if status == 429, String(decoding: data, as: UTF8.self).contains("\"limit\"") { return .failure(ProblemError(problem: .limit)) }
        guard status == 200, let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            return .failure(ProblemError(problem: .failed))
        }
        return .success(decoded.items)
    }
}
