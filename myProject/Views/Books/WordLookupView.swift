import SwiftUI
import SwiftData
@preconcurrency import Translation

/// Карточка слова из книги: словарная форма, перевод (из базы или переводчиком iOS), предложение (перевод — в Google) и «В словарь книги»
struct WordLookupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var lists: [WordList]

    let tapped: TappedWord
    let bookTitle: String
    /// Читать книгу вслух с этого слова
    var onReadFromHere: (() -> Void)?

    @State private var lemma = ""
    @State private var partOfSpeech = ""
    /// Это слово в основной базе — перевод и уровень оттуда
    @State private var baseWord: Word?
    @State private var translation = ""
    @State private var config: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var translationFailed = false
    /// Переводчик выдал несуществующее слово, транслит или грубость — просим проверить
    @State private var translationDoubtful = false
    /// Значение в этом предложении: Apple Intelligence (по-английски от модели, по-русски от переводчика)
    /// или, где его нет, ИИ-подсказка с сервера (сразу оба)
    @State private var contextEnglish: String?
    @State private var contextRussian: String?
    @State private var isFindingContext = false
    @State private var contextFromCloud = false
    /// ИИ-подсказка не пришла: запас на сегодня кончился или нет сети
    @State private var cloudMessage: String?
    @AppStorage(CloudContext.enabledKey) private var aiHints = false
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    /// Разговорная форма старой книги (knowed, a-going, de) — плашка с обычной формой и урок
    @State private var colloquial: ColloquialForm?
    /// То же место в переводе книги; подсветка уточняется, когда известен перевод слова (из базы или переводчика)
    @State private var passage: BookPassage?
    @State private var lesson: CommunityTopic?

    private var bookList: WordList? {
        let name = bookTitle.trimmingCharacters(in: .whitespaces)
        return lists.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
    }

    private var isAdded: Bool {
        bookList?.words.contains { $0.english.caseInsensitiveCompare(lemma) == .orderedSame } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                wordHeader
                if let colloquial {
                    colloquialBanner(colloquial)
                }
                ReadingBreakdownView(word: tapped.word, lemma: lemma, transcription: baseWord?.transcription,
                                     translation: baseWord?.russian ?? translation)
                translationBlock
                if let passage {
                    bookTranslationBlock(passage)
                }
                if isFindingContext || contextEnglish != nil {
                    contextBlock
                } else if aiHints && mode == .learning {
                    // В «Чтении» переключатель ИИ-подсказок спрятан — и кнопки нет
                    cloudButton
                }
                sentenceBlock
                addButton
            }
            .padding(22)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .task { prepare() }
        .translationTask(config) { session in
            await translate(with: session)
        }
        .sheet(item: $lesson) { topic in
            TopicView(topic: topic, backTitle: "Слово")
                .appThemedColorScheme()
        }
    }

    // MARK: - Разговорная форма

    private func colloquialBanner(_ form: ColloquialForm) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .foregroundColor(ColloquialRule.color)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Разговорная форма · \(form.rule.title)")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(.gray)
                    (Text(tapped.word) + Text(" = ") + Text(form.standard).bold() + Text(form.note.map { " (\($0))" } ?? ""))
                        .scaledFont(size: 15)
                        .foregroundColor(.brandDark)
                }
            }
            Button(action: openLesson) {
                Label("Урок: «Разговорный английский в старых книгах»", systemImage: "book.pages")
                    .scaledFont(size: 14, weight: .semibold)
                    .multilineTextAlignment(.leading)
            }
            .tint(.brown)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColloquialRule.color.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColloquialRule.color.opacity(0.3), lineWidth: 1))
        .cornerRadius(12)
    }

    private func openLesson() {
        let id = BuiltInTopics.colloquialID
        var descriptor = FetchDescriptor<CommunityTopic>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        lesson = try? modelContext.fetch(descriptor).first
    }

    /// Форма по слову и знакам вокруг него в предложении: апостроф показывает проглоченный звук (goin’, ’em)
    private static func colloquialForm(_ tapped: TappedWord) -> ColloquialForm? {
        let sentence = tapped.sentence
        let before = tapped.range.lowerBound > sentence.startIndex ? sentence[sentence.index(before: tapped.range.lowerBound)] : nil
        let after = String(sentence[tapped.range.upperBound...].prefix(2))
        return ColloquialForms.form(tapped.word, before: before, after: after, singleQuotes: sentence.contains("‘"))
    }

    // MARK: - Слово

    private var wordHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lemma.isEmpty ? tapped.word : lemma)
                    .scaledFont(size: 32, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                HStack(spacing: 8) {
                    if !lemma.isEmpty, lemma.caseInsensitiveCompare(tapped.word) != .orderedSame {
                        Text("в тексте: \(tapped.word)")
                    }
                    if !partOfSpeech.isEmpty {
                        Text(partOfSpeech).italic()
                    }
                }
                .scaledFont(size: 14)
                .foregroundColor(.gray)
            }
            Spacer()
            Button {
                TextToSpeechManager.shared.speak(lemma.isEmpty ? tapped.word : lemma)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .scaledFont(size: 22)
                    .foregroundColor(.brown)
            }
            .accessibilityLabel("Озвучить")
        }
    }

    @ViewBuilder
    private var translationBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let baseWord {
                HStack(spacing: 8) {
                    Text("Из базы")
                    Text(baseWord.cefrLevel).bold().foregroundColor(.indigo)
                }
                .scaledFont(size: 12, weight: .semibold)
                .foregroundColor(.gray)
                Text(baseWord.russian)
                    .scaledFont(size: 20, design: .serif)
                    .foregroundColor(.brandDark)
            } else {
                Text(isTranslating ? "Перевожу…" : translationFailed ? "Переводчик недоступен — впишите перевод"
                     : translationDoubtful ? "Перевод под вопросом — проверьте" : "Перевод")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(.gray)
                TextField("перевод", text: $translation)
                    .scaledFont(size: 20, design: .serif)
                    .foregroundColor(.brandDark)
                // В переводе книги нашлось это слово — можно взять оттуда
                if let lemma = passage?.lemma, translation.caseInsensitiveCompare(lemma) != .orderedSame {
                    Button { translation = lemma } label: {
                        Label("Из перевода книги: «\(lemma)»", systemImage: "text.quote")
                            .scaledFont(size: 13, weight: .semibold)
                    }
                    .tint(.brown)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    /// «В переводе книги» — то же место у переводчика книги, перевод слова подсвечен
    private func bookTranslationBlock(_ passage: BookPassage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("В переводе книги", systemImage: "text.quote")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundColor(.gray)
            Text(ReaderSelectionPanel.marked(passage))
                .scaledFont(size: 16, design: .serif)
                .foregroundColor(.brandDark)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    /// Словарь приложения слова не знает (Hatter) — ищем в переводе книги его перевод из базы или переводчика (шляпник ≈ шляпочник)
    private func refinePassageHighlights() {
        guard var current = passage, current.highlights.isEmpty else { return }
        let source = baseWord?.russian ?? translation
        let words = source.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
            .split(whereSeparator: { ",;".contains($0) })
            .map { Set($0.split(separator: " ").map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }.filter { $0.count >= 3 }) }
            .filter { !$0.isEmpty }
        let found = ParallelText.highlights(in: current.text, for: words)
        guard !found.ranges.isEmpty else { return }
        current.highlights = found.ranges
        current.lemma = found.lemma
        passage = current
    }

    /// «В этом предложении» — Apple Intelligence (iPhone 15 Pro и новее) или ИИ-подсказка с сервера, если она включена
    private var contextBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("В этом предложении")
                Spacer()
                if contextFromCloud {
                    Label("ИИ-подсказка", systemImage: "sparkles")
                        .labelStyle(.titleAndIcon)
                } else {
                    Label("Apple Intelligence", systemImage: "apple.intelligence")
                        .labelStyle(.titleAndIcon)
                }
            }
            .scaledFont(size: 12, weight: .semibold)
            .foregroundColor(.gray)
            if let contextEnglish {
                if let contextRussian {
                    Text(contextRussian)
                        .scaledFont(size: 18, design: .serif)
                        .foregroundColor(.brandDark)
                }
                Text(contextEnglish)
                    .scaledFont(size: 15, design: .serif)
                    .italic()
                    .foregroundColor(.gray)
                if baseWord == nil, let contextRussian, contextRussian != translation {
                    Button("Взять этот перевод") { translation = contextRussian }
                        .scaledFont(size: 14, weight: .semibold)
                        .tint(.brown)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Смотрю значение…")
                        .scaledFont(size: 15)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    /// ИИ-подсказка с сервера — только по нажатию: каждая тратит дневной запас
    private var cloudButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: askCloud) {
                Label("Значение в этом предложении", systemImage: "sparkles")
                    .scaledFont(size: 15, weight: .semibold)
            }
            .tint(.brown)
            if let cloudMessage {
                Text(cloudMessage)
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
            }
        }
    }

    private var sentenceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Word.attributedExample(exampleWithBold))
                .scaledFont(size: 16, design: .serif)
                .foregroundColor(.brandDark)
            // Предложение — в Google Переводчик: переводчик iOS переводит литературный текст почти дословно
            Button {
                if let url = ReaderSelectionPanel.googleTranslateURL(tapped.sentence) { openURL(url) }
            } label: {
                Label("Перевести предложение в Google", systemImage: "globe")
                    .scaledFont(size: 15, weight: .semibold)
            }
            Button {
                TextToSpeechManager.shared.speak(tapped.sentence)
            } label: {
                Label("Прослушать предложение", systemImage: "play.circle")
                    .scaledFont(size: 15)
            }
            if let onReadFromHere {
                Button(action: onReadFromHere) {
                    Label("Читать вслух с этого слова", systemImage: "play.fill")
                        .scaledFont(size: 15)
                }
            }
        }
        .tint(.brown)
    }

    private var addButton: some View {
        Button(action: add) {
            Label(isAdded ? "В словаре «\(bookTitle)»" : "В словарь «\(bookTitle)»",
                  systemImage: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(isAdded ? Color.white : Color.brandBackground)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(isAdded ? .green : .brandDark)
        .disabled(isAdded || (baseWord == nil && translation.trimmingCharacters(in: .whitespaces).isEmpty))
    }

    /// Предложение с выделенным словом — пример для карточки
    private var exampleWithBold: String {
        String(tapped.sentence[..<tapped.range.lowerBound]) + "<b>" + tapped.word + "</b>"
            + String(tapped.sentence[tapped.range.upperBound...])
    }

    // MARK: - Перевод

    private func prepare() {
        guard lemma.isEmpty else { return }
        passage = tapped.passage
        colloquial = Self.colloquialForm(tapped)
        var found = TextWordExtractor.lemma(of: tapped.word, at: tapped.range, in: tapped.sentence)
        // de → the, goin’ → going → go: перевод — у обычного слова
        if let colloquial, colloquial.lemma == nil, colloquial.rule != .aPrefix,
           colloquial.standard.allSatisfy({ $0.isLetter }) {
            let standard = colloquial.standard
            found = TextWordExtractor.lemma(of: standard, at: standard.startIndex..<standard.endIndex, in: standard)
        }
        lemma = found.lemma
        partOfSpeech = found.partOfSpeech
        let matches = modelContext.fetchAllWords().filter {
            $0.english.caseInsensitiveCompare(found.lemma) == .orderedSame
                || $0.english.caseInsensitiveCompare(tapped.word) == .orderedSame
        }
        baseWord = matches.first { $0.partOfSpeech == found.partOfSpeech } ?? matches.first
        if baseWord == nil { requestTranslation() }
        refinePassageHighlights()
        findContextMeaning()
    }

    /// Apple Intelligence — сразу (бесплатно, без сети); где его нет или он не ответил — кнопка ИИ-подсказки
    private func findContextMeaning() {
        guard ContextMeaning.isAvailable else { return }
        isFindingContext = true
        Task {
            defer { isFindingContext = false }
            guard let meaning = try? await ContextMeaning.meaning(of: tapped.word, in: tapped.sentence) else { return }
            contextEnglish = meaning
            requestTranslation()
        }
    }

    private func askCloud() {
        cloudMessage = nil
        contextFromCloud = true
        isFindingContext = true
        Task {
            defer { isFindingContext = false }
            switch await CloudContext.meaning(of: tapped.word, in: tapped.sentence) {
            case .meaning(let meaning):
                contextRussian = meaning.ru
                contextEnglish = meaning.en
            case .limit:
                cloudMessage = "На сегодня ИИ-подсказки закончились, завтра снова будут. Обычный перевод работает как всегда."
            case .failed:
                cloudMessage = "Не получилось — проверьте интернет и попробуйте ещё раз."
            }
        }
    }

    private func requestTranslation() {
        if config == nil {
            config = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                      target: Locale.Language(identifier: "ru"))
        } else {
            config?.invalidate()
        }
    }

    private func translate(with session: TranslationSession) async {
        isTranslating = true
        defer { isTranslating = false }
        do {
            if baseWord == nil, translation.isEmpty {
                let result = try await WordTranslator.translate(lemma, partOfSpeech: partOfSpeech, session: session)
                translation = result.text
                translationDoubtful = result.doubtful
                refinePassageHighlights()
            }
            if let contextEnglish, contextRussian == nil {
                contextRussian = WordTranslator.cleaned(try await session.translate(contextEnglish).targetText)
            }
        } catch {
            translationFailed = true
        }
    }

    // MARK: - В словарь

    /// Слово из базы — ссылкой со своим прогрессом; новое — своим словом с примером из книги
    private func add() {
        let list = WordList.named(bookTitle, context: modelContext)
        if let baseWord {
            if !baseWord.lists.contains(where: { $0.id == list.id }) { baseWord.lists.append(list) }
        } else {
            let word = Word(english: lemma, russian: translation.trimmingCharacters(in: .whitespaces),
                            example: exampleWithBold, cefrLevel: CEFRLevel.c1.rawValue,
                            partOfSpeech: partOfSpeech, isCustom: true)
            modelContext.insert(word)
            word.lists.append(list)
        }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Сигнал для словаря: в каком значении слово встречается в книгах; или его нет в базе
        if let baseWord {
            DictionarySignals.record(.init(kind: "context", word: baseWord.english, partOfSpeech: baseWord.partOfSpeech,
                                           field: "russian", old: baseWord.russian, sentence: tapped.sentence))
        } else {
            DictionarySignals.record(.init(kind: "missing", word: lemma, partOfSpeech: partOfSpeech,
                                           field: "russian", new: translation, sentence: tapped.sentence))
        }
    }
}
