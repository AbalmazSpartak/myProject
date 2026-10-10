import Foundation
import SwiftData

/// Слова для тренировок — запросами к базе, без чтения всех слов.
/// Все слова (10 000+ со словарями книг) SwiftData на iPhone 12 превращает в объекты ~2 с,
/// поэтому берём из базы только идентификаторы подходящих слов, а целиком читаем лишь те, что попадут в подход
@MainActor
enum StudyWords {
    // MARK: - Условия

    /// Слово выбрано для изучения — то же правило, что `StudyScope.includes(_:)`, но в виде запроса к базе
    static func scope(_ scope: StudyScope) -> Predicate<Word> {
        if !scope.enabledLists.isEmpty {
            let lists = Array(scope.enabledLists)
            return #Predicate<Word> { word in word.lists.contains { lists.contains($0.id) } }
        }
        let includeCustom = scope.includeCustomWords
        let levels = Array(scope.disabledLevels)
        let tags = disabledTags(scope)
        let topics = Array(scope.disabledTopics)
        // Слово без темы относится к теме "" — её тоже можно выключить
        let noTopicDisabled = scope.disabledTopics.contains("")
        return #Predicate<Word> { word in
            word.isCustom
                ? includeCustom
                : !levels.contains(word.cefrLevel)
                    && !tags.contains(word.partOfSpeech)
                    && (word.category.flatMap { topics.contains($0.name) } ?? noTopicDisabled) == false
        }
    }

    /// Части речи выключенных групп. Незнакомая часть речи — сама себе группа (как в `partOfSpeechGroup`)
    private static func disabledTags(_ scope: StudyScope) -> [String] {
        scope.disabledPartsOfSpeech.flatMap { group in
            StudyScope.partOfSpeechGroups.first { $0.name == group }.map { Array($0.tags) } ?? [group]
        }
    }

    /// Новое слово — ещё ни разу не оценивалось (у таких `state == .new`; перечисление в запросе SwiftData не поддерживает)
    static let isNew = #Predicate<Word> { $0.reps == 0 }

    /// Пора повторить: уже оценивалось и срок наступил
    static func isDue(now: Date) -> Predicate<Word> {
        #Predicate<Word> { $0.reps > 0 && $0.dueDate <= now }
    }

    static func all(_ predicates: Predicate<Word>...) -> Predicate<Word> {
        predicates.dropFirst().reduce(predicates.first ?? #Predicate<Word> { _ in true }) { combined, next in
            #Predicate<Word> { combined.evaluate($0) && next.evaluate($0) }
        }
    }

    // MARK: - Запросы

    static func count(_ predicate: Predicate<Word>, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor(predicate: predicate))) ?? 0
    }

    // MARK: - Запомненные счётчики

    /// Сколько слов в каждой теме и уровне: 117 тем — ~0,5 с запросов на iPhone 12, поэтому считаем один раз.
    /// Ответы в тренировках этих чисел не меняют; сбрасываем, когда слова добавили или удалили, поменяли тему или словарь
    private static var countCache: [String: Int] = [:]
    private static var countObserver: NSObjectProtocol?

    /// Условие строится, только если числа ещё нет: построение условия для 117 тем само по себе заметно
    static func cachedCount(_ key: String, _ predicate: @autoclosure () -> Predicate<Word>, in context: ModelContext) -> Int {
        observeSaves()
        if let cached = countCache[key] { return cached }
        let value = count(predicate(), in: context)
        countCache[key] = value
        return value
    }

    /// Сколько выбранных для изучения слов в теме (запомненное число)
    static func categoryCount(_ category: Category, scope: StudyScope, inScope: Predicate<Word>, in context: ModelContext) -> Int {
        let categoryID = category.id
        return cachedCount("тема|\(key(scope))|\(categoryID)",
                           all(inScope, #Predicate<Word> { $0.category?.id == categoryID }), in: context)
    }

    /// Досчитать числа тем порциями: 117 тем — ~0,5 с запросов на iPhone 12. Между порциями экран отвечает на нажатия,
    /// поэтому тренировка показывает первое слово сразу, а меню фильтра получает числа чуть позже
    static func warmCategoryCounts(scope: StudyScope, categories: [Category], in context: ModelContext) async {
        let inScope = Self.scope(scope)
        for (index, category) in categories.enumerated() {
            _ = categoryCount(category, scope: scope, inScope: inScope, in: context)
            // 4 темы (~20 мс) — и пауза в кадр: экран успевает перерисоваться и принять нажатие
            if index % 4 == 3 { try? await Task.sleep(for: .milliseconds(16)) }
        }
    }

    static func invalidateCounts() {
        countCache.removeAll()
    }

    /// Ключ выбранного для изучения — все настройки отсортированными строками.
    /// Не `rawValue`: в JSON порядок полей от раза к разу разный, и запомненное ни разу не находилось
    static func key(_ scope: StudyScope) -> String {
        [scope.disabledLevels.sorted().joined(separator: ","),
         scope.disabledPartsOfSpeech.sorted().joined(separator: ","),
         scope.disabledTopics.sorted().joined(separator: ","),
         scope.includeCustomWords ? "свои" : "",
         scope.enabledLists.map(\.uuidString).sorted().joined(separator: ",")].joined(separator: "|")
    }

    private static func observeSaves() {
        guard countObserver == nil else { return }
        countObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { notification in
            let info = notification.userInfo ?? [:]
            let ids = { (key: ModelContext.NotificationKey) in info[key.rawValue] as? [PersistentIdentifier] ?? [] }
            // Новые и удалённые слова, темы, словари; изменённые темы и словари — слово перенесли или добавили в словарь.
            // Изменённые слова не в счёт: так сохраняется каждый ответ в тренировке
            let added = (ids(.insertedIdentifiers) + ids(.deletedIdentifiers)).contains { ["Word", "Category", "WordList"].contains($0.entityName) }
            let moved = ids(.updatedIdentifiers).contains { ["Category", "WordList"].contains($0.entityName) }
            guard added || moved else { return }
            MainActor.assumeIsolated { invalidateCounts() }
        }
    }

    static func fetch(_ predicate: Predicate<Word>, sortBy: [SortDescriptor<Word>] = [], limit: Int? = nil,
                      in context: ModelContext) -> [Word] {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: sortBy)
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Случайные слова: идентификаторы всех подходящих (это быстро), из них — нужное число, и только они читаются целиком
    static func random(_ predicate: Predicate<Word>, limit: Int?, excluding excluded: Set<PersistentIdentifier> = [],
                       in context: ModelContext) -> [Word] {
        let ids = ((try? context.fetchIdentifiers(FetchDescriptor(predicate: predicate))) ?? [])
            .filter { !excluded.contains($0) }
            .shuffled()
        return models(limit.map { Array(ids.prefix($0)) } ?? ids, in: context)
    }

    /// Слова по идентификаторам одним запросом, в том же порядке
    static func models(_ ids: [PersistentIdentifier], in context: ModelContext) -> [Word] {
        guard !ids.isEmpty else { return [] }
        let found = fetch(#Predicate<Word> { ids.contains($0.persistentModelID) }, in: context)
        let byID = Dictionary(found.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    // MARK: - Подход тренировки

    /// Слова подхода — то же, что `TrainingFilter.sessionWords` + `SessionLength.limited`, но без чтения всей базы.
    /// `length` 0 — без ограничения
    static func session(_ filter: TrainingFilter, scope: StudyScope, newWordsAllowance: Int? = nil, length: Int,
                        now: Date = Date(), in context: ModelContext) -> [Word] {
        let inScope = Self.scope(scope)
        let limit = length > 0 ? length : nil
        switch filter {
        case .due:
            let reviews = fetch(all(inScope, isDue(now: now)), sortBy: [SortDescriptor(\.dueDate)], limit: limit, in: context)
            let room = limit.map { $0 - reviews.count } ?? Int.max
            let wanted = min(room, newWordsAllowance ?? Int.max)
            guard wanted > 0 else { return reviews }
            return reviews + newWords(all(inScope, isNew), count: wanted, in: context)
        case .all:
            return random(inScope, limit: limit, in: context)
        case .category(let category):
            let categoryID = category.id
            return random(all(inScope, #Predicate<Word> { $0.category?.id == categoryID }), limit: limit, in: context)
        case .mistakes:
            return random(all(inScope, #Predicate<Word> { $0.isMistake }), limit: limit, in: context)
        case .level(let level):
            let raw = level.rawValue
            return random(all(inScope, #Predicate<Word> { $0.cefrLevel == raw }), limit: limit, in: context)
        }
    }

    /// Новые слова в порядке `TrainingFilter.byLevel`: сначала из словарей, созданных из файла, — от самых частых в файле;
    /// дальше от простых уровней к сложным, внутри уровня вперемешку
    private static func newWords(_ predicate: Predicate<Word>, count: Int, in context: ModelContext) -> [Word] {
        var result: [Word] = []
        var taken = Set<PersistentIdentifier>()

        // Частоты из своих словарей: ключ — написание строчными (WordList.frequencyKey)
        let lists = ((try? context.fetch(FetchDescriptor<WordList>())) ?? []).filter { !$0.frequencies.isEmpty }
        if !lists.isEmpty {
            var frequency: [String: Int] = [:]
            for list in lists {
                for (key, value) in list.frequencies { frequency[key] = max(frequency[key] ?? 0, value) }
            }
            // С запасом: часть самых частых уже учится или не входит в выбранные для изучения
            let keys = frequency.sorted { $0.value > $1.value }.prefix(count * 20 + 200).map(\.key)
            let listIDs = lists.map(\.id)
            let fromFiles = fetch(all(predicate, #Predicate<Word> { word in
                keys.contains(word.english) && word.lists.contains { listIDs.contains($0.id) }
            }), in: context)
            for word in fromFiles.sorted(by: { WordList.frequency(of: $0) > WordList.frequency(of: $1) }).prefix(count) {
                result.append(word)
                taken.insert(word.persistentModelID)
            }
        }

        let known = CEFRLevel.allCases.map(\.rawValue)
        for level in known where result.count < count {
            result += random(all(predicate, #Predicate<Word> { $0.cefrLevel == level }), limit: count - result.count,
                             excluding: taken, in: context)
        }
        // Уровень не из списка (пустой или нестандартный) — в самом конце, как в byLevel
        if result.count < count {
            result += random(all(predicate, #Predicate<Word> { !known.contains($0.cefrLevel) }), limit: count - result.count,
                             excluding: taken, in: context)
        }
        return result
    }
}
