import SwiftUI
import SwiftData
@preconcurrency import Translation

/// Слово из текста и, если есть, такое же слово из базы
struct ScanCandidate: Identifiable {
    let extracted: ExtractedWord
    /// nil — слова в базе нет, это новое слово
    let existing: Word?

    var id: String { extracted.id }
}

enum ScanMatcher {
    /// Ищет слово в базе по словарной форме, затем по форме из текста; при нескольких значениях — с той же частью речи
    static func match(_ found: [ExtractedWord], in words: [Word]) -> [ScanCandidate] {
        let index = Dictionary(grouping: words) { $0.english.lowercased() }
        return found.map { item in
            let matches = index[item.lemma] ?? index[item.surface.lowercased()] ?? []
            let best = matches.first { $0.partOfSpeech == item.partOfSpeech } ?? matches.first
            return ScanCandidate(extracted: item, existing: best)
        }
    }
}

/// Шаг 3: выбрать слова для нового словаря. Новым словам перевод подставляет встроенный переводчик iOS
struct ScanResultsView: View {
    let candidates: [ScanCandidate]
    var onSave: (WordList) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [WordList]

    @State private var listName = "Скан " + Date.now.formatted(.dateTime.day().month(.wide))
    @State private var selected: Set<String>
    @State private var translations: [String: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translationState = TranslationState.idle
    /// «Отмечать слова, которые уже учу» — запоминается для следующих сканов
    @AppStorage(Self.selectLearningKey) private var selectLearning = false
    private static let selectLearningKey = "scan_select_learning"

    private enum TranslationState {
        case idle, translating, done, failed
    }

    /// Новых слов нет в базе (A1–B2), поэтому скорее всего они сложнее; уровень можно поправить в правке слова
    private let newWordLevel = CEFRLevel.c1.rawValue

    init(candidates: [ScanCandidate], onSave: @escaping (WordList) -> Void) {
        self.candidates = candidates
        self.onSave = onSave
        // По умолчанию отмечены новые слова и слова из базы, которые ещё не начали учить,
        // а с «Отмечать слова, которые уже учу» — все найденные
        let selectLearning = UserDefaults.standard.bool(forKey: Self.selectLearningKey)
        _selected = State(initialValue: Set(candidates.filter { selectLearning || !Self.isLearning($0) }.map(\.id)))
    }

    /// Слово из базы, которое уже начали учить (хотя бы раз оценили в карточках)
    private static func isLearning(_ candidate: ScanCandidate) -> Bool {
        candidate.existing.map { $0.state != .new } ?? false
    }

    private var newWords: [ScanCandidate] {
        candidates.filter { $0.existing == nil }
    }

    /// Сложные слова сверху
    private var knownWords: [ScanCandidate] {
        candidates.filter { $0.existing != nil }.sorted { levelRank($0) > levelRank($1) }
    }

    private var missingTranslations: Int {
        newWords.filter { selected.contains($0.id) && translation(for: $0).isEmpty }.count
    }

    private var canSave: Bool {
        !selected.isEmpty && missingTranslations == 0 && !listName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        List {
            Section {
                TextField("Название", text: $listName)
            } header: {
                Text("Новый словарь")
            } footer: {
                if let existing = existingList {
                    Text("Словарь «\(existing.name)» уже есть — слова добавятся в него (\(existing.words.count) сейчас).")
                }
            }
            if candidates.contains(where: Self.isLearning) {
                Section {
                    Toggle("Отмечать слова, которые уже учу", isOn: $selectLearning)
                        .onChange(of: selectLearning) { _, isOn in
                            // Меняем галочки только у уже изучаемых слов — отметки остальных не трогаем
                            let ids = Set(candidates.filter(Self.isLearning).map(\.id))
                            if isOn { selected.formUnion(ids) } else { selected.subtract(ids) }
                        }
                } footer: {
                    Text("Тогда в словарь из текста сразу попадут все его слова. Настройка запоминается для следующих сканов.")
                }
            }
            if !newWords.isEmpty {
                Section {
                    ForEach(newWords) { newWordRow($0) }
                } header: {
                    sectionHeader("Новые слова", items: newWords)
                } footer: {
                    Text(newWordsFooter)
                }
            }
            if !knownWords.isEmpty {
                Section {
                    ForEach(knownWords) { knownWordRow($0) }
                } header: {
                    sectionHeader("Уже есть в базе", items: knownWords)
                } footer: {
                    Text(selectLearning
                         ? "Из базы слово попадёт в словарь, оставаясь в своей теме и со своим прогрессом."
                         : "Слова, которые вы уже учите, не отмечены. Из базы слово попадёт в словарь, оставаясь в своей теме.")
                }
            }
        }
        .navigationTitle("Найдено слов: \(candidates.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить (\(selected.count))", action: save)
                    .bold()
                    .disabled(!canSave)
            }
        }
        .translationTask(translationConfig) { session in
            await translate(with: session)
        }
        .onAppear {
            if !newWords.isEmpty, translationConfig == nil {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "ru")
                )
            }
        }
    }

    // MARK: - Строки

    private func sectionHeader(_ title: String, items: [ScanCandidate]) -> some View {
        let allOn = items.allSatisfy { selected.contains($0.id) }
        return HStack {
            Text("\(title) — \(items.count)")
            Spacer()
            Button(allOn ? "Снять все" : "Выбрать все") {
                let ids = Set(items.map(\.id))
                if allOn { selected.subtract(ids) } else { selected.formUnion(ids) }
            }
            .font(.caption)
            .textCase(nil)
        }
    }

    private var newWordsFooter: String {
        switch translationState {
        case .translating:
            return "Перевожу встроенным переводчиком iOS…"
        case .failed:
            return "Переводчик недоступен — введите перевод вручную или снимите галочку."
        case .idle, .done:
            return missingTranslations > 0
                ? "Введите перевод для отмеченных слов или снимите галочку."
                : "Перевод автоматический, без учёта контекста — проверьте его. Пример взят из вашего текста."
        }
    }

    private func newWordRow(_ candidate: ScanCandidate) -> some View {
        let word = candidate.extracted
        return HStack(alignment: .top, spacing: 12) {
            checkbox(for: candidate)
            VStack(alignment: .leading, spacing: 4) {
                titleLine(english: word.lemma, partOfSpeech: word.partOfSpeech, count: word.count)
                TextField(translationState == .translating ? "переводится…" : "перевод", text: translationBinding(for: candidate))
                    .foregroundStyle(.secondary)
                Text(Word.attributedExample(word.example))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private func knownWordRow(_ candidate: ScanCandidate) -> some View {
        let word = candidate.existing!
        return HStack(alignment: .top, spacing: 12) {
            checkbox(for: candidate)
            VStack(alignment: .leading, spacing: 4) {
                titleLine(english: word.english, partOfSpeech: word.partOfSpeech, count: candidate.extracted.count)
                Text(word.russian)
                    .foregroundStyle(.secondary)
                if word.state != .new {
                    Text("уже учите")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            Text(word.cefrLevel)
                .font(.caption.bold())
                .foregroundStyle(.indigo)
        }
    }

    private func titleLine(english: String, partOfSpeech: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(english).font(.headline)
            Text(partOfSpeech).font(.subheadline).italic().foregroundStyle(.secondary)
            if count > 1 {
                Text("×\(count)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func checkbox(for candidate: ScanCandidate) -> some View {
        let isOn = selected.contains(candidate.id)
        return Button {
            selected.formSymmetricDifference([candidate.id])
        } label: {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .scaledFont(size: 22)
                .foregroundStyle(isOn ? Color.teal : Color.gray.opacity(0.5))
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Перевод

    private func translation(for candidate: ScanCandidate) -> String {
        (translations[candidate.id] ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func translationBinding(for candidate: ScanCandidate) -> Binding<String> {
        Binding(get: { translations[candidate.id] ?? "" }, set: { translations[candidate.id] = $0 })
    }

    private func translate(with session: TranslationSession) async {
        translationState = .translating
        // Глагол переводим с «to», иначе переводчик часто выдаёт существительное (run → «бег»)
        let sources = newWords.map { candidate in
            let word = candidate.extracted
            return (id: candidate.id, text: word.partOfSpeech == "v." ? "to \(word.lemma)" : word.lemma)
        }
        let requests = Self.translationRequests(sources)
        do {
            let responses = try await session.translations(from: requests)
            for response in responses {
                guard let id = response.clientIdentifier, (translations[id] ?? "").isEmpty else { continue }
                translations[id] = Self.cleanedTranslation(response.targetText)
            }
            translationState = .done
        } catch {
            translationState = .failed
        }
    }

    /// Запросы собираем вне главного потока: так Swift 6 разрешает передать их в переводчик
    nonisolated private static func translationRequests(_ sources: [(id: String, text: String)]) -> [TranslationSession.Request] {
        sources.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id) }
    }

    /// «Маяк.» → «маяк», «чтобы бежать» → «бежать»
    private static func cleanedTranslation(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if text.lowercased().hasPrefix("чтобы ") {
            text = String(text.dropFirst("чтобы ".count))
        }
        guard let first = text.first, text.dropFirst().contains(where: \.isLowercase) || text.count == 1 else { return text }
        return first.lowercased() + text.dropFirst()
    }

    // MARK: - Сохранение

    private func levelRank(_ candidate: ScanCandidate) -> Int {
        CEFRLevel.allCases.firstIndex { $0.rawValue == candidate.existing?.cefrLevel } ?? 0
    }

    /// Словарь с таким же названием (без учёта регистра) — новые слова добавляются в него, а не во второй такой же
    private var existingList: WordList? {
        let name = listName.trimmingCharacters(in: .whitespaces)
        return lists.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
    }

    private func save() {
        let list: WordList
        if let existing = existingList {
            list = existing
        } else {
            list = WordList(name: listName.trimmingCharacters(in: .whitespaces))
            modelContext.insert(list)
        }
        for candidate in candidates where selected.contains(candidate.id) {
            if let word = candidate.existing {
                // Слово уже в этом словаре — второй раз не добавляем
                if !word.lists.contains(where: { $0.id == list.id }) {
                    word.lists.append(list)
                }
            } else {
                let item = candidate.extracted
                let word = Word(
                    english: item.lemma,
                    russian: translation(for: candidate),
                    example: item.example,
                    cefrLevel: newWordLevel,
                    partOfSpeech: item.partOfSpeech,
                    isCustom: true
                )
                modelContext.insert(word)
                word.lists.append(list)
            }
        }
        try? modelContext.save()
        onSave(list)
    }
}
