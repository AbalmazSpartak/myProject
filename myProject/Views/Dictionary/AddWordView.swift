import SwiftUI
import SwiftData
@preconcurrency import Translation

/// «Новое слово» (кнопка «+» в Словаре): слово, перевод, пример и уровень.
/// Такое же слово уже есть в базе — предлагаем взять его, а не делать дубль
struct AddWordView: View {
    let category: Category?
    let list: WordList?
    /// Куда попадёт слово: открытая папка, словарь или «Общий»
    let targetName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var english = ""
    @State private var transcription = ""
    /// Подставлено из словаря: пока поле не правили руками, при смене слова оно обновляется
    @State private var autoTranscription: String?
    @State private var russian = ""
    @State private var example = ""
    @State private var level = "A1"
    @State private var partOfSpeech = ""
    /// Такое же слово уже есть (в базе или среди своих) — при добавлении берём его, а не делаем дубль
    @State private var existingMatches: [Word] = []
    /// Кнопка «Перевести» — тот же переводчик и те же проверки, что у слов из книг
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var translationNote: String?
    /// Последнее добавленное слово — подтверждение, пока вписывают следующее
    @State private var lastAdded: String?
    @State private var wordToOpen: Word?

    private var canAdd: Bool {
        !english.trimmingCharacters(in: .whitespaces).isEmpty
            && !russian.trimmingCharacters(in: .whitespaces).isEmpty
            && existingMatches.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            LXNavBar(title: "Новое слово") {
                LXTextButton(title: "Закрыть", isMuted: true) { dismiss() }
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        LXField(label: "Слово") {
                            TextField("по-английски", text: $english)
                                .scaledFont(size: 20, design: .serif)
                                .foregroundStyle(Color.brandDark)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        LXField(label: "Транскрипция") {
                            TextField("необязательно", text: $transcription)
                                .scaledFont(size: 16)
                                .foregroundStyle(Color.brandDark)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    if !existingMatches.isEmpty { existingMatchesCard }
                    PartOfSpeechChips(code: $partOfSpeech)
                        .padding(.top, 4)
                    HStack(spacing: 10) {
                        LXField(label: "Перевод", hint: "Варианты через запятую") {
                            TextField("Перевод на русский", text: $russian)
                                .scaledFont(size: 17)
                                .foregroundStyle(Color.brandDark)
                                .autocorrectionDisabled()
                        }
                        translateButton
                    }
                    if let translationNote {
                        Text(translationNote)
                            .scaledFont(size: 13)
                            .foregroundStyle(Color.brandTint)
                    }
                    LXField(label: "Пример", hint: "Слово в примере выделится само") {
                        TextField("Предложение со словом", text: $example, axis: .vertical)
                            .scaledFont(size: 16, design: .serif)
                            .foregroundStyle(Color.brandDark)
                            .lineLimit(1...4)
                    }
                    levelPicker
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            VStack(spacing: 8) {
                if let lastAdded {
                    Label("Добавлено: \(lastAdded)", systemImage: "checkmark.circle")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(Color.statusKnown)
                }
                LXButton(title: "Добавить в «\(DictionaryView.shortName(targetName))»", isEnabled: canAdd, action: addWord)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.brandBackground)
            .overlay(alignment: .top) { LXDivider() }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onChange(of: english) { _, _ in
            refreshExistingMatches()
            translationNote = nil
        }
        // Транскрипция сама: через полсекунды после остановки набора; вписанное руками не трогаем
        .task(id: english.trimmingCharacters(in: .whitespaces)) {
            await fillTranscription()
        }
        .translationTask(translationConfig) { session in
            await translate(with: session)
        }
        .sheet(item: $wordToOpen, onDismiss: { modelContext.saveReporting() }) { word in
            EditWordView(word: word)
                .appThemedColorScheme()
        }
    }

    // MARK: - Части формы

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            LXSectionLabel(text: "Уровень")
            HStack(spacing: 8) {
                ForEach(CEFRLevel.allCases, id: \.rawValue) { item in
                    LXChip(title: item.rawValue, isOn: level == item.rawValue) { level = item.rawValue }
                }
            }
        }
    }

    private var translateButton: some View {
        Button {
            translationNote = nil
            if translationConfig == nil {
                translationConfig = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                                     target: Locale.Language(identifier: "ru"))
            } else {
                translationConfig?.invalidate()
            }
        } label: {
            Group {
                if isTranslating {
                    ProgressView()
                } else {
                    Image(systemName: "character.bubble").scaledFont(size: 20, weight: .semibold)
                }
            }
            .foregroundStyle(Color.brandOnSoft)
            .frame(width: 56, height: 56)
            .background(AppDesign.isSketch ? NewStyle.pastels[1] : Color.brandAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .sketchFrame(AppDesign.isSketch, radius: 14, shadow: NewStyle.blue, offset: 3)
        }
        .buttonStyle(.plain)
        .disabled(english.trimmingCharacters(in: .whitespaces).isEmpty || isTranslating)
        .accessibilityLabel("Перевести")
    }

    /// Вместо дубля — взять слово из базы: в свой словарь добавить ссылку, в темах — открыть правку
    private var existingMatchesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            LXSectionLabel(text: "Уже есть")
            ForEach(existingMatches.prefix(3)) { word in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(word.english)\(word.partOfSpeech.isEmpty ? "" : " (\(word.partOfSpeech))") — \(word.russian)")
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(Color.brandDark)
                        Text(matchDetails(word))
                            .scaledFont(size: 12)
                            .foregroundStyle(Color.brandMuted)
                    }
                    Spacer()
                    matchAction(for: word)
                }
            }
            // Нужного значения нет (bank — «берег», а в базе только «банк») — своё слово, но только явно
            Button("Другое значение — добавить своё", action: addWord)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(Color.brandMuted)
                .disabled(russian.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppDesign.isSketch ? NewStyle.pastels[0] : Color.brandAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sketchFrame(AppDesign.isSketch, radius: 14, shadow: NewStyle.yellowShadow.opacity(0.7), offset: 3)
    }

    private func matchDetails(_ word: Word) -> String {
        let place = word.category.map { "тема «\($0.name)»" } ?? (word.isCustom ? "ваше слово" : "Общий")
        return "\(word.cefrLevel) · \(place)"
    }

    @ViewBuilder
    private func matchAction(for word: Word) -> some View {
        if let list {
            if word.lists.contains(where: { $0.id == list.id }) {
                Text("уже в словаре")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(Color.brandMuted)
            } else {
                Button("Добавить") { add(word, to: list) }
                    .scaledFont(size: 14, weight: .bold)
                    .foregroundStyle(Color.brandTint)
            }
        } else {
            Button("Открыть") { wordToOpen = word }
                .scaledFont(size: 14, weight: .bold)
                .foregroundStyle(Color.brandTint)
        }
    }

    // MARK: - Действия

    /// Подставляет транскрипцию из словаря, если поле пустое или в нём прежняя подстановка
    private func fillTranscription() async {
        let typed = english.trimmingCharacters(in: .whitespaces)
        let canReplace = transcription.isEmpty || transcription == autoTranscription
        guard canReplace else { return }
        guard TranscriptionLookup.isLookupable(typed.lowercased()) else {
            if transcription == autoTranscription { transcription = "" }
            autoTranscription = nil
            return
        }
        do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
        let found = await TranscriptionLookup.lookup(typed)
        guard !Task.isCancelled, transcription.isEmpty || transcription == autoTranscription else { return }
        transcription = found ?? ""
        autoTranscription = found
    }

    /// Слово с тем же написанием: как введено, строчными и с заглавной (April, I)
    private func refreshExistingMatches() {
        let typed = english.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else {
            existingMatches = []
            return
        }
        let lower = typed.lowercased()
        let capitalized = lower.prefix(1).uppercased() + lower.dropFirst()
        let descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.english == typed || $0.english == lower || $0.english == capitalized })
        existingMatches = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Ссылка на существующее слово в своём словаре — без копии
    private func add(_ word: Word, to list: WordList) {
        word.lists.append(list)
        modelContext.saveReporting()
        finishAdding(word.english)
    }

    private func addWord() {
        let trimmedEnglish = english.trimmingCharacters(in: .whitespaces)
        let trimmedRussian = russian.trimmingCharacters(in: .whitespaces)
        guard !trimmedEnglish.isEmpty, !trimmedRussian.isEmpty else { return }

        let word = Word(
            english: trimmedEnglish,
            russian: trimmedRussian,
            transcription: Word.bareTranscription(transcription),
            example: example.trimmingCharacters(in: .whitespaces),
            category: category,
            cefrLevel: level,
            partOfSpeech: partOfSpeech.trimmingCharacters(in: .whitespaces),
            isCustom: true
        )
        modelContext.insert(word)
        if let list { word.lists.append(list) }
        modelContext.saveReporting()
        finishAdding(trimmedEnglish)
    }

    /// Форма очищается — можно вписать следующее слово; закрыть окно — «Закрыть»
    private func finishAdding(_ added: String) {
        english = ""
        transcription = ""
        autoTranscription = nil
        russian = ""
        example = ""
        partOfSpeech = ""
        translationNote = nil
        existingMatches = []
        lastAdded = added
        Haptics.tap()
    }

    private func translate(with session: TranslationSession) async {
        let text = english.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isTranslating = true
        defer { isTranslating = false }
        do {
            let result = try await WordTranslator.translate(text, session: session)
            russian = result.text
            if result.doubtful {
                translationNote = result.text.isEmpty
                    ? "Подходящего перевода нет — впишите свой."
                    : "Перевод под вопросом — проверьте."
            }
        } catch {
            translationNote = "Переводчик недоступен — проверьте, скачан ли русский язык в настройках iPhone «Перевод»."
        }
    }
}
