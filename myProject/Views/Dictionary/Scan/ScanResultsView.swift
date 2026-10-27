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
    /// Выражения из базы (все записи из нескольких слов), которые сканер ищет в тексте целиком.
    /// У выражения с несколькими значениями (take off) — один образец; фразовый глагол важнее: только ему разрешён разрыв
    static func phrases(in words: [Word]) -> [PhrasePattern] {
        var byText: [String: PhrasePattern] = [:]
        for word in words {
            let text = word.english.trimmingCharacters(in: .whitespaces).lowercased()
            guard text.contains(" ") else { continue }
            if byText[text] == nil || word.partOfSpeech == "phr. v." {
                byText[text] = PhrasePattern(text: text, partOfSpeech: word.partOfSpeech)
            }
        }
        return Array(byText.values)
    }

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

/// Шаг 3: выбрать слова для нового словаря. Новым словам перевод подставляет ИИ по предложению из текста
/// (BookWordsAI) или встроенный переводчик iOS — что выбрал пользователь; не переведённое ИИ — встроенным
struct ScanResultsView: View {
    let candidates: [ScanCandidate]
    /// Слова из файла: словарь называется по файлу и запоминает частоту — новые слова учатся первыми, от частых
    let fileName: String?
    /// Пояснение к файлу: обрезан, взяты самые частые слова
    let note: String?
    /// Фото, с которого распознан текст, — сохраняется в словаре
    let photo: Data?
    var onSave: (WordList) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [WordList]

    @State private var listName = "Скан " + Date.now.formatted(.dateTime.day().month(.wide))
    @State private var selected: Set<String>
    @State private var translations: [String: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var translationState = TranslationState.idle
    /// Сколько новых слов уже переведено — для больших файлов переводим частями
    @State private var translatedCount = 0
    /// Новые слова, которых нет в словаре проверки орфографии iOS: диалект, обрывки, редкие имена — без галочки и без автоперевода
    @State private var unknown: Set<String> = []
    /// Перевод под вопросом: несуществующее русское слово, транслит, латиница — без галочки, в разделе «Проверьте перевод»
    @State private var doubtful: Set<String> = []
    /// Сколько новых слов отдано переводчику — для прогресса (сами разделы за время перевода меняются)
    @State private var translationTotal = 0
    /// Как переводить новые слова: "ai", "apple" или "" — спросить при первом словаре
    @AppStorage(BookWordsAI.choiceKey) private var translatorChoice = ""
    @State private var isChoosingTranslator = false
    @State private var hasStarted = false
    /// Ответ ИИ по слову: словарная форма, часть речи, пояснение к значению
    @State private var aiEntries: [String: BookWordsAI.Entry] = [:]
    /// ИИ узнал в «новом» слове слово базы (britches → breeches): у него проверенный перевод и прогресс
    @State private var aiBase: [String: Word] = [:]
    /// Запас ИИ кончился или нет сети — остальное перевёл встроенный переводчик
    @State private var aiProblem: BookWordsAI.Problem?
    /// «Отмечать слова, которые уже учу» — запоминается для следующих сканов
    @AppStorage(Self.selectLearningKey) private var selectLearning = false
    private static let selectLearningKey = "scan_select_learning"

    private enum TranslationState {
        case idle, translating, done, failed
    }

    /// Новых слов нет в базе (A1–B2), поэтому скорее всего они сложнее; уровень можно поправить в правке слова
    private let newWordLevel = CEFRLevel.c1.rawValue

    init(candidates: [ScanCandidate], fileName: String? = nil, note: String? = nil, photo: Data? = nil,
         onSave: @escaping (WordList) -> Void) {
        self.candidates = candidates
        self.fileName = fileName
        self.note = note
        self.photo = photo
        self.onSave = onSave
        if let fileName { _listName = State(initialValue: fileName) }
        // По умолчанию отмечены новые слова и слова из базы, которые ещё не начали учить,
        // а с «Отмечать слова, которые уже учу» — все найденные
        let selectLearning = UserDefaults.standard.bool(forKey: Self.selectLearningKey)
        _selected = State(initialValue: Set(candidates.filter { selectLearning || !Self.isLearning($0) }.map(\.id)))
    }

    /// Слово из базы, которое уже начали учить (хотя бы раз оценили в карточках)
    private static func isLearning(_ candidate: ScanCandidate) -> Bool {
        candidate.existing.map { $0.state != .new } ?? false
    }

    /// Слово базы: найденное сразу или узнанное ИИ
    private func base(_ candidate: ScanCandidate) -> Word? {
        candidate.existing ?? aiBase[candidate.id]
    }

    private var newWords: [ScanCandidate] {
        candidates.filter { base($0) == nil && !unknown.contains($0.id) && !doubtful.contains($0.id) }
    }

    private var doubtfulWords: [ScanCandidate] {
        candidates.filter { base($0) == nil && doubtful.contains($0.id) }
    }

    private var unknownWords: [ScanCandidate] {
        candidates.filter { base($0) == nil && unknown.contains($0.id) }
    }

    /// Слова, которых нет в словаре iOS ни в американском, ни в британском написании
    private static func notInDictionary(_ candidates: [ScanCandidate]) -> Set<String> {
        let checker = UITextChecker()
        let languages = ["en_US", "en_GB"].filter(UITextChecker.availableLanguages.contains)
        guard !languages.isEmpty else { return [] }
        return Set(candidates.filter { candidate in
            let word = candidate.extracted.lemma
            let range = NSRange(location: 0, length: (word as NSString).length)
            return languages.allSatisfy { language in
                checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language).location != NSNotFound
            }
        }.map(\.id))
    }

    /// Фразовые глаголы и выражения из базы, найденные в тексте целиком
    private var phrases: [ScanCandidate] {
        candidates.filter { base($0) != nil && $0.extracted.isPhrase }
    }

    /// Сложные слова сверху; из файла — самые частые
    private var knownWords: [ScanCandidate] {
        let known = candidates.filter { base($0) != nil && !$0.extracted.isPhrase }
        return fileName == nil ? known.sorted { levelRank($0) > levelRank($1) } : known
    }

    private var missingTranslations: Int {
        candidates.filter { base($0) == nil && selected.contains($0.id) && translation(for: $0).isEmpty }.count
    }

    /// Из файла слов тысячи — без перевода они просто не сохраняются, а не держат кнопку
    private var canSave: Bool {
        !selected.isEmpty && (missingTranslations == 0 || fileName != nil) && translationState != .translating
            && !listName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        List {
            Group {
                Section {
                    TextField("Название", text: $listName)
                } header: {
                    Text("Новый словарь")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let existing = existingList {
                            Text("Словарь «\(existing.name)» уже есть — слова добавятся в него (\(existing.words.count) сейчас).")
                        }
                        if fileName != nil {
                            Text("Слова отсортированы по частоте в файле. Новые слова этого словаря пойдут на изучение первыми — от самых частых.")
                        }
                        if let note { Text(note) }
                        if photo != nil {
                            Text("Фото сохранится в словаре — его видно над словами.")
                        }
                    }
                }
                // Перевод тысяч слов из книги — до минуты; видно сразу, а не в подписи под всем списком
                if translationState == .translating {
                    Section {
                        translationProgress
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
                if !phrases.isEmpty {
                    Section {
                        ForEach(phrases) { knownWordRow($0, showsExample: true) }
                    } header: {
                        sectionHeader("Выражения", items: phrases)
                    } footer: {
                        Text("Фразовые глаголы и устойчивые выражения из базы, найденные в тексте целиком. Проверьте по примеру, что значение то же: в «look up at the sky» не «искать в словаре».")
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
                if !doubtfulWords.isEmpty {
                    Section {
                        ForEach(doubtfulWords) { newWordRow($0) }
                    } header: {
                        sectionHeader("Проверьте перевод", items: doubtfulWords)
                    } footer: {
                        Text("Переводчик выдал несуществующее слово, транслит, латиницу или грубость (её не показываем) — галочки сняты. Исправьте перевод, и слово отметится.")
                    }
                }
                if !unknownWords.isEmpty {
                    Section {
                        ForEach(unknownWords) { newWordRow($0) }
                    } header: {
                        sectionHeader("Не найдены в словаре", items: unknownWords)
                    } footer: {
                        Text(aiEntries.isEmpty
                             ? "Диалект, обрывки слов, редкие имена и опечатки — переводчик их не знает, поэтому они не отмечены. Нужное слово отметьте и впишите перевод сами."
                             : "Имена, обрывки слов и служебные слова — учить их отдельно незачем, поэтому они не отмечены.")
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
            // Строки — тёплого цвета карточек, а не системного серого
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Найдено слов: \(candidates.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if translationState == .translating {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Перевожу…")
                            .foregroundColor(.gray)
                    }
                } else {
                    Button("Сохранить (\(selected.count))", action: save)
                        .bold()
                        .disabled(!canSave)
                }
            }
        }
        .translationTask(translationConfig) { session in
            await translate(with: session)
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            unknown = Self.notInDictionary(candidates.filter { $0.existing == nil })
            selected.subtract(unknown)
            guard candidates.contains(where: { $0.existing == nil }) else { return }
            switch translatorChoice {
            case "ai": Task { await translateWithAI() }
            case "apple": startAppleTranslation()
            default: isChoosingTranslator = true
            }
        }
        .confirmationDialog("Как перевести новые слова?", isPresented: $isChoosingTranslator, titleVisibility: .visible) {
            Button("ИИ — точнее, по предложению") {
                translatorChoice = "ai"
                Task { await translateWithAI() }
            }
            Button("Встроенный переводчик iOS") {
                translatorChoice = "apple"
                startAppleTranslation()
            }
            Button("Не сейчас", role: .cancel) { startAppleTranslation() }
        } message: {
            Text("ИИ переводит слово в значении из предложения и понимает диалект: на проверке 97% верно, у встроенного — 69%. Нужен интернет: слово и предложение уйдут на сервер WordLearner, без имени и почты. Выбор запомнится, поменять можно в Настройках.")
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

    private var translationProgress: some View {
        let total = translationTotal
        return VStack(alignment: .leading, spacing: 8) {
            Text(total > Self.translationChunk
                 ? "Перевожу новые слова: \(translatedCount.formatted()) из \(total.formatted())"
                 : "Перевожу новые слова…")
                .scaledFont(size: 15, weight: .semibold)
                .foregroundColor(.brandDark)
            if total > Self.translationChunk {
                ProgressView(value: Double(translatedCount), total: Double(total))
                    .tint(.teal)
            } else {
                ProgressView()
            }
            Text("Сохранить можно будет, когда закончу.")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }

    private var newWordsFooter: String {
        switch translationState {
        case .translating:
            let total = translationTotal
            return total > Self.translationChunk ? "Перевожу… \(translatedCount) из \(total)" : "Перевожу…"
        case .failed:
            return fileName == nil
                ? "Переводчик недоступен — введите перевод вручную или снимите галочку."
                : "Переводчик недоступен — введите перевод вручную. Слова без перевода не сохранятся."
        case .idle, .done:
            if missingTranslations > 0 {
                return fileName == nil
                    ? "Введите перевод для отмеченных слов или снимите галочку."
                    : "Без перевода: \(missingTranslations) — такие слова не сохранятся, впишите перевод, если нужны."
            }
            switch aiProblem {
            case .limit:
                return "Дневной запас ИИ-перевода закончился — остальные слова перевёл встроенный переводчик, проверьте их. Пример взят из вашего текста."
            case .failed:
                return "ИИ был недоступен — часть слов перевёл встроенный переводчик, проверьте их. Пример взят из вашего текста."
            case nil:
                return aiEntries.isEmpty
                    ? "Перевод автоматический, без учёта контекста — проверьте его. Пример взят из вашего текста."
                    : "Перевод ИИ — в значении из предложения (✦). Пример взят из вашего текста."
            }
        }
    }

    private func newWordRow(_ candidate: ScanCandidate) -> some View {
        let word = candidate.extracted
        let entry = aiEntries[candidate.id]
        return HStack(alignment: .top, spacing: 12) {
            checkbox(for: candidate)
            VStack(alignment: .leading, spacing: 4) {
                titleLine(english: entry?.lemma ?? word.lemma, partOfSpeech: entry?.pos ?? word.partOfSpeech, count: word.count)
                TextField(translationState == .translating ? "переводится…" : "перевод", text: translationBinding(for: candidate))
                    .foregroundStyle(.secondary)
                if let entry {
                    aiCaption(entry, surface: word.surface)
                }
                Text(Word.attributedExample(word.example))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    /// ✦ — перевёл ИИ; «в тексте: britches», если словарная форма другая; пояснение к значению
    private func aiCaption(_ entry: BookWordsAI.Entry, surface: String) -> some View {
        var parts: [String] = []
        if entry.lemma.caseInsensitiveCompare(surface) != .orderedSame { parts.append("в тексте: \(surface)") }
        if !entry.note.isEmpty { parts.append(entry.note) }
        return Text("✦ " + (parts.isEmpty ? "ИИ" : parts.joined(separator: " · ")))
            .font(.caption)
            .foregroundStyle(.indigo)
    }

    /// showsExample — пример из текста: у выражений по нему видно, в том ли значении оно стоит
    private func knownWordRow(_ candidate: ScanCandidate, showsExample: Bool = false) -> some View {
        let word = base(candidate)!
        return HStack(alignment: .top, spacing: 12) {
            checkbox(for: candidate)
            VStack(alignment: .leading, spacing: 4) {
                titleLine(english: word.english, partOfSpeech: word.partOfSpeech, count: candidate.extracted.count)
                Text(word.russian)
                    .foregroundStyle(.secondary)
                if aiBase[candidate.id] != nil {
                    Text("✦ в тексте: \(candidate.extracted.surface) — ИИ узнал слово базы")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
                if showsExample {
                    Text(Word.attributedExample(candidate.extracted.example))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
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
        Binding(get: { translations[candidate.id] ?? "" }, set: {
            translations[candidate.id] = $0
            // Исправили сомнительный перевод — слово нужно
            if doubtful.contains(candidate.id) { selected.insert(candidate.id) }
        })
    }

    /// Новые слова — ИИ по предложению из текста; что ИИ не перевёл (сеть, запас) — встроенным переводчиком
    private func translateWithAI() async {
        translationState = .translating
        let targets = candidates.filter { $0.existing == nil }
        translationTotal = targets.count
        translatedCount = 0
        let items = targets.map { candidate in
            let word = candidate.extracted
            return (id: candidate.id, item: BookWordsAI.Item(word: word.lemma, pos: word.partOfSpeech, sentence: word.example))
        }
        let result = await BookWordsAI.translate(items) { translatedCount = $0 }
        aiProblem = result.problem
        let byEnglish = Dictionary(grouping: modelContext.fetchAllWords()) { $0.english.lowercased() }
        for candidate in targets {
            guard let entry = result.entries[candidate.id] else { continue }
            aiEntries[candidate.id] = entry
            let ru = WordTranslator.cleaned(entry.ru)
            guard entry.isStudyWord else {
                // Имя, обрывок, служебное слово — без галочки
                translations[candidate.id] = WordTranslator.shown(ru)
                unknown.insert(candidate.id)
                selected.remove(candidate.id)
                continue
            }
            let lemma = entry.lemma.lowercased()
            if lemma != candidate.extracted.lemma.lowercased(), let matches = byEnglish[lemma] {
                // britches → breeches: слово базы — с проверенным переводом и своим прогрессом
                let word = matches.first { $0.partOfSpeech == entry.pos } ?? matches[0]
                aiBase[candidate.id] = word
                unknown.remove(candidate.id)
                if selectLearning || word.state == .new { selected.insert(candidate.id) } else { selected.remove(candidate.id) }
                continue
            }
            // Слово не из словаря проверки орфографии, но ИИ его знает — значит, нужное
            if unknown.remove(candidate.id) != nil { selected.insert(candidate.id) }
            if WordTranslator.isRude(ru) {
                markDoubtful(candidate.id, translation: ru)
            } else {
                translations[candidate.id] = ru
            }
        }
        if newWords.contains(where: { translation(for: $0).isEmpty }) {
            startAppleTranslation()
        } else {
            translationState = .done
        }
    }

    private func startAppleTranslation() {
        guard newWords.contains(where: { translation(for: $0).isEmpty }) else {
            translationState = .done
            return
        }
        if translationConfig == nil {
            translationConfig = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                                 target: Locale.Language(identifier: "ru"))
        } else {
            translationConfig?.invalidate()
        }
    }

    private func translate(with session: TranslationSession) async {
        translationState = .translating
        // Только то, что ещё без перевода: остальное уже перевёл ИИ
        let sources = newWords.filter { translation(for: $0).isEmpty }.map { candidate in
            let word = candidate.extracted
            return (id: candidate.id, text: WordTranslator.source(for: word.lemma, partOfSpeech: word.partOfSpeech))
        }
        translationTotal = sources.count
        translatedCount = 0
        do {
            // Частями: тысячи слов из файла — с прогрессом, и экран не ждёт всё разом
            for start in stride(from: 0, to: sources.count, by: Self.translationChunk) {
                let chunk = Array(sources[start..<min(start + Self.translationChunk, sources.count)])
                let responses = try await session.translations(from: Self.translationRequests(chunk))
                var retry: [(id: String, text: String)] = []
                var firstTry: [String: String] = [:]
                for response in responses {
                    guard let id = response.clientIdentifier, (translations[id] ?? "").isEmpty else { continue }
                    let translated = WordTranslator.cleaned(response.targetText)
                    if WordTranslator.isUsable(translated, source: response.sourceText) {
                        translations[id] = translated
                    } else if let second = WordTranslator.retrySource(for: response.sourceText) {
                        // «to mighty» → «к могуществу», «to fetch» → «зарать»: глагол переводим ещё раз, без «to»
                        firstTry[id] = translated
                        retry.append((id: id, text: second))
                    } else {
                        markDoubtful(id, translation: translated)
                    }
                }
                if !retry.isEmpty {
                    for response in try await session.translations(from: Self.translationRequests(retry)) {
                        guard let id = response.clientIdentifier else { continue }
                        let translated = WordTranslator.cleaned(response.targetText)
                        if WordTranslator.isUsable(translated, source: response.sourceText) {
                            translations[id] = translated
                        } else {
                            // Оба перевода плохие — показываем тот, где хотя бы слова настоящие
                            let first = firstTry[id] ?? ""
                            let broken = WordTranslator.looksBroken(translated) && !WordTranslator.looksBroken(first)
                            markDoubtful(id, translation: broken ? first : translated)
                        }
                    }
                }
                translatedCount = start + chunk.count
            }
            translationState = .done
        } catch {
            translationState = .failed
        }
    }

    private static let translationChunk = 200

    /// Грубый перевод не показываем: поле пустое, перевод впишут сами
    private func markDoubtful(_ id: String, translation: String) {
        translations[id] = WordTranslator.shown(translation)
        doubtful.insert(id)
        selected.remove(id)
    }

    /// Запросы собираем вне главного потока: так Swift 6 разрешает передать их в переводчик
    nonisolated private static func translationRequests(_ sources: [(id: String, text: String)]) -> [TranslationSession.Request] {
        sources.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id) }
    }

    // MARK: - Сохранение

    private func levelRank(_ candidate: ScanCandidate) -> Int {
        CEFRLevel.allCases.firstIndex { $0.rawValue == base(candidate)?.cefrLevel } ?? 0
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
        if let photo { list.addPhoto(photo) }
        /// Новые слова этого сохранения: ИИ мог свести две формы к одной словарной (fagged, fag) — второй раз не создаём
        var savedNew = Set<String>()
        for candidate in candidates where selected.contains(candidate.id) {
            let baseWord = base(candidate)
            let entry = aiEntries[candidate.id]
            let aiLemma = entry?.lemma.trimmingCharacters(in: .whitespaces) ?? ""
            let english = aiLemma.isEmpty ? candidate.extracted.lemma : aiLemma
            // Из файла — запоминаем частоту: новые слова словаря учатся первыми, от частых
            if fileName != nil {
                let key = baseWord.map(WordList.frequencyKey) ?? english.lowercased()
                if baseWord != nil || !translation(for: candidate).isEmpty {
                    list.frequencies[key] = max(list.frequencies[key] ?? 0, candidate.extracted.count)
                }
            }
            if let word = baseWord {
                // Слово уже в этом словаре — второй раз не добавляем
                if !word.lists.contains(where: { $0.id == list.id }) {
                    word.lists.append(list)
                }
            } else {
                // Из файла слово без перевода не сохраняем — пустую карточку не выучить
                guard !translation(for: candidate).isEmpty, savedNew.insert(english.lowercased()).inserted else { continue }
                let item = candidate.extracted
                let word = Word(
                    english: english,
                    russian: translation(for: candidate),
                    example: item.example,
                    cefrLevel: newWordLevel,
                    partOfSpeech: entry?.pos ?? item.partOfSpeech,
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
