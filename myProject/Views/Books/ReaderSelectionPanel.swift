import SwiftUI
import SwiftData
@preconcurrency import Translation

/// Панель под выделенным текстом: слово — перевод встроенным переводчиком iOS; фраза — в Google Переводчик
/// (переводчик iOS переводит литературные фразы почти дословно); озвучка, копирование, «В словарь» книги
struct ReaderSelectionPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    let text: String
    let bookTitle: String
    let onClose: () -> Void

    @State private var translation: String?
    @State private var config: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var failed = false
    @State private var isAdded = false
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
        let typed = manualTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? nil : typed
    }

    /// Фразу — в словарь; целый абзац там ни к чему
    private var fitsDictionary: Bool { text.split(separator: " ").count <= 12 }

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
                        .foregroundStyle(.gray)
                }
                .accessibilityLabel("Снять выделение")
            }

            if let translation {
                Text(translation)
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark.opacity(0.75))
                    .lineLimit(6)
                    .textSelection(.enabled)
            } else if isTranslating {
                ProgressView()
            } else if failed {
                Text("Не удалось перевести — проверьте, скачан ли русский язык в настройках iPhone «Перевод».")
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
            }

            if isEnteringTranslation {
                HStack(spacing: 8) {
                    TextField("Перевод фразы", text: $manualTranslation)
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
                        .tint(.brown)
                        .disabled(dictionaryTranslation == nil)
                }
            }

            HStack(spacing: 8) {
                if isSingleWord {
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
                        if let url = Self.googleTranslateURL(text) { openURL(url) }
                    }
                }
                action("Озвучить", icon: "speaker.wave.2") {
                    TextToSpeechManager.shared.speak(text)
                }
                action(copied ? "Скопировано" : "Копировать", icon: "doc.on.doc") {
                    UIPasteboard.general.string = text
                    copied = true
                }
                if fitsDictionary {
                    action(isAdded ? "В словаре" : "В словарь", icon: isAdded ? "checkmark.circle.fill" : "plus.circle",
                           disabled: isAdded || (isSingleWord && translation == nil)) {
                        if dictionaryTranslation != nil {
                            add()
                        } else {
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
        .translationTask(config) { session in
            isTranslating = true
            defer { isTranslating = false }
            do {
                translation = try await session.translate(text).targetText
            } catch {
                failed = true
            }
        }
        .onChange(of: text) { _, _ in
            translation = nil
            failed = false
            isAdded = false
            copied = false
            isEnteringTranslation = false
            manualTranslation = ""
        }
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
        .opacity(disabled && !(title == "В словаре" || title == "Готово") ? 0.4 : 1)
    }

    /// Фраза — своим словом в словаре книги, с переводом; учится в тренировках, как слова
    private func add() {
        guard let translation = dictionaryTranslation else { return }
        let list = WordList.named(bookTitle, context: modelContext)
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
