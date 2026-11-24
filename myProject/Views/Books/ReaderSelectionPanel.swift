import SwiftUI
import SafariServices
import SwiftData
@preconcurrency import Translation

/// Панель под выделенным текстом: слово — перевод из словаря приложения (переводчик iOS — по желанию, в Настройках); фраза — в Google Переводчик
/// (переводчик iOS переводит литературные фразы почти дословно); озвучка, копирование, «В словарь» книги.
/// У книги с добавленным переводом — ещё «В переводе книги»: то же место у переводчика, слово подсвечено
struct ReaderSelectionPanel: View {
    /// Настройка: кнопка «Перевести» встроенным переводчиком iOS; по умолчанию выключена — перевод берётся из словаря
    static let systemTranslatorKey = "selection_system_translator"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let text: String
    let bookTitle: String
    var language = BookLanguage.english
    /// Место в переводе книги — ищется, когда панель открылась
    let passageLookup: () -> BookPassage?
    /// Предложение со словом и место слова в нём: по предложению выбирается значение слова
    var sentenceLookup: () -> (sentence: String, range: Range<String.Index>)? = { nil }
    /// У одного слова — «Карточка»: полная карточка слова, как при нажатии
    var onOpenCard: (() -> Void)?
    /// «Заметка» к выделенному месту: читалка спрашивает описание и сохраняет
    var onNote: (() -> Void)?
    let onClose: () -> Void

    @AppStorage(ReaderSelectionPanel.systemTranslatorKey) private var usesSystemTranslator = false
    /// Слово из словаря приложения — его перевод показывается сразу
    @State private var baseWord: Word?
    /// Все значения слова из словаря, подходящее по предложению — первым
    @State private var baseMeanings: [Word] = []
    @State private var translation: String?
    @State private var config: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var failed = false
    @State private var rudeHidden = false
    @State private var isAdded = false
    @State private var definedWord: DefinedWord?
    /// Google Переводчик в окне поверх читалки, без выхода в браузер
    @State private var googlePage: GooglePage?
    @State private var passage: BookPassage?
    @State private var copied = false
    /// Фраза в словарь: перевод вписывает сам читатель (например, из Google Переводчика)
    @State private var isEnteringTranslation = false
    @State private var manualTranslation = ""
    @FocusState private var isTranslationFocused: Bool

    private var isSingleWord: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace).count == 1
    }

    /// Перевод для словаря: у слова — от переводчика iOS, у фразы — вписанный
    private var dictionaryTranslation: String? {
        if let translation { return translation }
        if let baseWord { return baseWord.russian }
        let typed = manualTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? nil : typed
    }

    /// Перевод из книги для словаря: у слова — найденное в переводе слово, у целых предложений — их перевод
    private var bookSuggestion: String? {
        guard let passage else { return nil }
        return isSingleWord ? passage.lemma : (passage.coversSentences ? passage.text : nil)
    }

    /// Фразу — в словарь; целый абзац там ни к чему
    private var fitsDictionary: Bool { text.split(separator: " ").count <= 12 }
    private var isEnglish: Bool { language == BookLanguage.english }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(text)
                    .scaledFont(size: sketch ? 24 : 16, weight: sketch ? .bold : .regular, design: sketch ? .rounded : .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(4)
                Button {
                    Haptics.tap()
                    speak()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .scaledFont(size: 15)
                        .foregroundColor(.brandDark)
                        .frame(width: 34, height: 34)
                        .background(sketch ? NewStyle.yellow : Color.brandBackground, in: Circle())
                        .sketchFrame(sketch, radius: 17, shadow: NewStyle.blue, offset: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Озвучить")
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(size: 22)
                        .foregroundStyle(Color.brandMuted)
                }
                .accessibilityLabel("Снять выделение")
            }

            if let baseWord {
                Text(meaningsText(for: baseWord))
                    .scaledFont(size: 18)
                    .foregroundColor(.brandDark)
                    .lineLimit(6)
                    .textSelection(.enabled)
            }
            if isEnglish, isSingleWord, !usesSystemTranslator {
                Label(baseWord == nil ? "Нет в словаре" : "Из словаря", systemImage: "character.book.closed")
                    .scaledFont(size: 12)
                    .foregroundColor(Color.brandMuted)
            }
            if let translation {
                Text(baseWord == nil ? translation : "Переводчик iOS: \(translation)")
                    .scaledFont(size: baseWord == nil ? 15 : 13)
                    .foregroundColor(.brandDark.opacity(baseWord == nil ? 0.75 : 0.55))
                    .lineLimit(6)
                    .textSelection(.enabled)
            } else if isTranslating {
                ProgressView()
            } else if rudeHidden {
                Text("Переводчик iOS дал грубый перевод, он скрыт. Свой перевод можно ввести через «В словарь».")
                    .scaledFont(size: 13)
                    .foregroundColor(Color.brandMuted)
            } else if failed {
                Text("Не удалось перевести — проверьте, скачан ли русский язык в настройках iPhone «Перевод».")
                    .scaledFont(size: 13)
                    .foregroundColor(Color.brandMuted)
            }

            if let passage {
                VStack(alignment: .leading, spacing: 3) {
                    Text("В переводе книги")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(Color.brandMuted)
                    Text(Self.marked(passage))
                        .scaledFont(size: 15, design: .serif)
                        .foregroundColor(.brandDark.opacity(0.85))
                        .lineLimit(5)
                }
            }

            if isEnteringTranslation {
                if let bookSuggestion, manualTranslation != bookSuggestion {
                    Button { manualTranslation = bookSuggestion } label: {
                        Label("Из перевода книги: «\(bookSuggestion)»", systemImage: "text.quote")
                            .scaledFont(size: 13, weight: .semibold)
                            .lineLimit(1)
                    }
                    .tint(Color.brandTint)
                }
                HStack(spacing: 8) {
                    TextField(isSingleWord ? "Перевод" : "Перевод фразы", text: $manualTranslation)
                        .scaledFont(size: 15)
                        .focused($isTranslationFocused)
                        .submitLabel(.done)
                        .onSubmit(add)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.brandBackground)
                        .cornerRadius(10)
                    Button("Добавить", action: add)
                        .scaledFont(size: 15, weight: .semibold)
                        .tint(Color.brandTint)
                        .disabled(dictionaryTranslation == nil)
                }
            }

            actionsView
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .sheet(item: $googlePage) { page in
            SafariSheet(url: page.url)
                .ignoresSafeArea()
        }
        .sheet(item: $definedWord) { defined in
            SystemDefinitionView(term: defined.term)
                .ignoresSafeArea()
        }
        .translationTask(config) { session in
            isTranslating = true
            defer { isTranslating = false }
            do {
                let result = try await session.translate(text).targetText
                if WordTranslator.isRude(result) {
                    rudeHidden = true
                } else {
                    translation = result
                }
            } catch {
                failed = true
            }
        }
        .task(id: text) {
            passage = passageLookup()
            baseWord = findBaseWord()
        }
        .onChange(of: text) { _, _ in
            translation = nil
            baseWord = nil
            baseMeanings = []
            failed = false
            rudeHidden = false
            isAdded = false
            copied = false
            isEnteringTranslation = false
            manualTranslation = ""
        }
    }

    /// Выделенное слово — в словаре приложения (по словарной форме: ran → run); у нескольких значений — первое
    private func findBaseWord() -> Word? {
        guard isEnglish, isSingleWord else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !clean.isEmpty else { return nil }
        // Часть речи — по предложению из книги, а не по слову отдельно: «Well,» в начале фразы — «ну», а не «здоровый»
        let found: (lemma: String, partOfSpeech: String)
        if let context = sentenceLookup(), context.sentence.localizedCaseInsensitiveContains(clean) {
            found = TextWordExtractor.lemma(of: clean, at: context.range, in: context.sentence)
        } else {
            found = TextWordExtractor.lemma(of: clean, at: clean.startIndex..<clean.endIndex, in: clean)
        }
        let matches = modelContext.words(spelled: [found.lemma, clean])
        // Подходящее по предложению значение — первым, остальные — следом
        let fitting = matches.filter { $0.partOfSpeech == found.partOfSpeech }
        baseMeanings = fitting + matches.filter { $0.partOfSpeech != found.partOfSpeech }
        return fitting.first ?? matches.first
    }

    /// До трёх значений слова через точку с запятой, без повторов; первым — подходящее по предложению
    private func meaningsText(for word: Word) -> String {
        var seen = Set<String>()
        let all = ([word] + baseMeanings).map(\.russian).filter { seen.insert($0.lowercased()).inserted }
        return all.prefix(3).joined(separator: "; ")
    }

    /// Перевод книги с подсвеченными переводами выделенного слова
    static func marked(_ passage: BookPassage) -> AttributedString {
        var result = AttributedString(passage.text)
        for highlight in passage.highlights {
            guard let range = Range(highlight, in: result) else { continue }
            result[range].backgroundColor = Color.brandTint.opacity(0.25)
            result[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }

    /// Google Переводчик с уже вставленным текстом: приложение, если стоит, иначе сайт
    static func googleTranslateURL(_ text: String) -> URL? {
        var components = URLComponents(string: "https://translate.google.com/")
        components?.queryItems = [
            URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: "ru"),
            URLQueryItem(name: "text", value: text.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "op", value: "translate"),
        ]
        return components?.url
    }

    private var sketch: Bool { AppDesign.isSketch }

    private func speak() {
        if isEnglish {
            TextToSpeechManager.shared.speak(text)
        } else if let voice = SpeechSettings.bestVoice(language: language) {
            TextToSpeechManager.shared.preview(text, voice: voice)
        }
    }

    private func openDefinition() {
        definedWord = DefinedWord(term: text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))
    }

    /// Главное действие — большая кнопка («Карточка» у слова, «Google» у фразы), остальные — ряд кнопок поменьше
    private var actionsView: some View {
        VStack(spacing: 10) {
            if isSingleWord, let onOpenCard {
                primaryButton("Карточка", icon: "text.book.closed", action: onOpenCard)
            } else if isEnglish, !isSingleWord {
                primaryButton("Google", icon: "globe") {
                    if let url = Self.googleTranslateURL(text) { googlePage = GooglePage(url: url) }
                }
            }
            HStack(spacing: 6) {
                if isSingleWord, isEnglish, usesSystemTranslator {
                    miniButton(translation == nil ? "Перевести" : "Готово", icon: "character.bubble", disabled: translation != nil || isTranslating) {
                        if config == nil {
                            config = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                                      target: Locale.Language(identifier: "ru"))
                        } else {
                            config?.invalidate()
                        }
                    }
                }
                // Толкование из словаря iPhone (в неанглийских книгах перевода на русский нет — оно главное)
                if isSingleWord {
                    miniButton("Толкование", icon: "text.magnifyingglass", action: openDefinition)
                }
                miniButton(copied ? "Скопировано" : "Копировать", icon: "doc.on.doc") {
                    UIPasteboard.general.string = text
                    copied = true
                }
                if let onNote {
                    miniButton("Заметка", icon: "note.text.badge.plus", action: onNote)
                }
                if isEnglish && fitsDictionary {
                    miniButton(isAdded ? "В словаре" : "В словарь", icon: isAdded ? "checkmark.circle.fill" : "plus.circle",
                               disabled: isAdded || (isSingleWord && usesSystemTranslator && translation == nil && !rudeHidden && baseWord == nil && bookSuggestion == nil)) {
                        if dictionaryTranslation != nil {
                            add()
                        } else {
                            // Подсказка из перевода книги — сразу в поле, поправить можно
                            manualTranslation = bookSuggestion ?? ""
                            isEnteringTranslation = true
                            isTranslationFocused = true
                        }
                    }
                }
            }
        }
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .scaledFont(size: 18, weight: .bold, design: sketch ? .rounded : .default)
                .foregroundColor(sketch ? NewStyle.onYellow : .white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(sketch ? NewStyle.yellow : Color.brandTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .sketchFrame(sketch, radius: 16, shadow: NewStyle.blue, offset: 3)
        }
        .buttonStyle(.plain)
    }

    private func miniButton(_ title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .scaledFont(size: 18)
                Text(title)
                    .scaledFont(size: 12, weight: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 2)
            .background(sketch ? Color.cardBackground : Color.brandBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .sketchFrame(sketch, radius: 12, shadow: NewStyle.blue, offset: 2)
        }
        .buttonStyle(.plain)
        .foregroundColor(.brandDark)
        .disabled(disabled)
        .opacity(disabled && !(title == "В словаре" || title == "Готово") ? 0.4 : 1)
    }

    /// Фраза — своим словом в словаре книги, с переводом; учится в тренировках, как слова
    private func add() {
        guard let translation = dictionaryTranslation else { return }
        let list = WordList.named(bookTitle, context: modelContext)
        // Слово из словаря приложения — ссылкой со своим прогрессом, а не копией
        if isSingleWord, let baseWord, translation == baseWord.russian {
            if !baseWord.lists.contains(where: { $0.id == list.id }) { baseWord.lists.append(list) }
            modelContext.saveReporting()
            isAdded = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let word = Word(english: phrase, russian: translation.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)),
                        example: "<b>\(phrase)</b>", cefrLevel: CEFRLevel.c1.rawValue, partOfSpeech: "phrase", isCustom: true)
        modelContext.insert(word)
        word.lists.append(list)
        modelContext.saveReporting()
        isAdded = true
        isEnteringTranslation = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}


private struct GooglePage: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Системное окно Safari поверх приложения: страница открывается внутри читалки, «Готово» возвращает к книге
private struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
