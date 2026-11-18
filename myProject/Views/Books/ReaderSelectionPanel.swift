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
    /// У одного слова — «Карточка»: полная карточка слова, как при нажатии
    var onOpenCard: (() -> Void)?
    let onClose: () -> Void

    @AppStorage(ReaderSelectionPanel.systemTranslatorKey) private var usesSystemTranslator = false
    /// Слово из словаря приложения — его перевод показывается сразу
    @State private var baseWord: Word?
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
            HStack(alignment: .top) {
                Text(text)
                    .scaledFont(size: 16, design: .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(4)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(size: 22)
                        .foregroundStyle(Color.brandMuted)
                }
                .accessibilityLabel("Снять выделение")
            }

            if let baseWord {
                Text(baseWord.russian)
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark.opacity(0.75))
                    .lineLimit(6)
                    .textSelection(.enabled)
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

            HStack(spacing: 8) {
                if !isEnglish {
                    // Книга не на английском: перевода на русский нет — толкование из словаря iPhone
                    if isSingleWord {
                        action("Толкование", icon: "character.book.closed") {
                            definedWord = DefinedWord(term: text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))
                        }
                    }
                } else if isSingleWord && !usesSystemTranslator {
                    // Перевод — из словаря приложения; переводчик iOS включается в Настройках
                    action(baseWord == nil ? "Нет в словаре" : "Из словаря", icon: "character.book.closed", disabled: true) {}
                } else if isSingleWord {
                    action(translation == nil ? "Перевести" : "Готово", icon: "character.bubble", disabled: translation != nil || isTranslating) {
                        if config == nil {
                            config = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                                      target: Locale.Language(identifier: "ru"))
                        } else {
                            config?.invalidate()
                        }
                    }
                } else {
                    action("Google", icon: "globe") {
                        if let url = Self.googleTranslateURL(text) { googlePage = GooglePage(url: url) }
                    }
                }
                if isSingleWord, let onOpenCard {
                    action("Карточка", icon: "text.book.closed", action: onOpenCard)
                }
                // ВРЕМЕННО: толкование из словаря iPhone и для английских книг — посмотреть, как работает (в неанглийских оно есть всегда)
                if isEnglish, isSingleWord {
                    action("Толкование", icon: "text.magnifyingglass") {
                        definedWord = DefinedWord(term: text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))
                    }
                }
                action("Озвучить", icon: "speaker.wave.2") {
                    if isEnglish {
                        TextToSpeechManager.shared.speak(text)
                    } else if let voice = SpeechSettings.bestVoice(language: language) {
                        TextToSpeechManager.shared.preview(text, voice: voice)
                    }
                }
                action(copied ? "Скопировано" : "Копировать", icon: "doc.on.doc") {
                    UIPasteboard.general.string = text
                    copied = true
                }
                if isEnglish && fitsDictionary {
                    action(isAdded ? "В словаре" : "В словарь", icon: isAdded ? "checkmark.circle.fill" : "plus.circle",
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
        let found = TextWordExtractor.lemma(of: clean, at: clean.startIndex..<clean.endIndex, in: clean)
        let matches = modelContext.fetchAllWords().filter {
            $0.english.caseInsensitiveCompare(found.lemma) == .orderedSame || $0.english.caseInsensitiveCompare(clean) == .orderedSame
        }
        return matches.first { $0.partOfSpeech == found.partOfSpeech } ?? matches.first
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

    private func action(_ title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .scaledFont(size: 17)
                Text(title)
                    .scaledFont(size: 11, weight: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.brandBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .foregroundColor(.brandDark)
        .disabled(disabled)
        .opacity(disabled && !(title == "В словаре" || title == "Готово" || title == "Из словаря") ? 0.4 : 1)
    }

    /// Фраза — своим словом в словаре книги, с переводом; учится в тренировках, как слова
    private func add() {
        guard let translation = dictionaryTranslation else { return }
        let list = WordList.named(bookTitle, context: modelContext)
        // Слово из словаря приложения — ссылкой со своим прогрессом, а не копией
        if isSingleWord, let baseWord, translation == baseWord.russian {
            if !baseWord.lists.contains(where: { $0.id == list.id }) { baseWord.lists.append(list) }
            try? modelContext.save()
            isAdded = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        let phrase = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let word = Word(english: phrase, russian: translation.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)),
                        example: "<b>\(phrase)</b>", cefrLevel: CEFRLevel.c1.rawValue, partOfSpeech: "phrase", isCustom: true)
        modelContext.insert(word)
        word.lists.append(list)
        try? modelContext.save()
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
