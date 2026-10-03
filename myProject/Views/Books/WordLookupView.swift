import SwiftUI
import SwiftData
@preconcurrency import Translation

/// Карточка слова из книги: словарная форма, перевод (из базы или переводчиком iOS), предложение и «В словарь книги»
struct WordLookupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [WordList]

    let tapped: TappedWord
    let bookTitle: String

    @State private var lemma = ""
    @State private var partOfSpeech = ""
    /// Это слово в основной базе — перевод и уровень оттуда
    @State private var baseWord: Word?
    @State private var translation = ""
    @State private var sentenceTranslation: String?
    @State private var wantsSentence = false
    @State private var config: TranslationSession.Configuration?
    @State private var isTranslating = false
    @State private var translationFailed = false

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
                translationBlock
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
                Text(isTranslating ? "Перевожу…" : (translationFailed ? "Переводчик недоступен — впишите перевод" : "Перевод"))
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(.gray)
                TextField("перевод", text: $translation)
                    .scaledFont(size: 20, design: .serif)
                    .foregroundColor(.brandDark)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private var sentenceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Word.attributedExample(exampleWithBold))
                .scaledFont(size: 16, design: .serif)
                .foregroundColor(.brandDark)
            if let sentenceTranslation {
                Text(sentenceTranslation)
                    .scaledFont(size: 15)
                    .foregroundColor(.gray)
            } else {
                Button {
                    wantsSentence = true
                    requestTranslation()
                } label: {
                    Label("Перевести предложение", systemImage: "character.bubble")
                        .scaledFont(size: 15, weight: .semibold)
                }
                .disabled(wantsSentence && isTranslating)
            }
            Button {
                TextToSpeechManager.shared.speak(tapped.sentence)
            } label: {
                Label("Прослушать предложение", systemImage: "play.circle")
                    .scaledFont(size: 15)
            }
        }
        .tint(.brown)
    }

    private var addButton: some View {
        Button(action: add) {
            Label(isAdded ? "В словаре «\(bookTitle)»" : "В словарь «\(bookTitle)»",
                  systemImage: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                .scaledFont(size: 16, weight: .semibold)
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
        let found = TextWordExtractor.lemma(of: tapped.word, at: tapped.range, in: tapped.sentence)
        lemma = found.lemma
        partOfSpeech = found.partOfSpeech
        let matches = modelContext.fetchAllWords().filter {
            $0.english.caseInsensitiveCompare(found.lemma) == .orderedSame
                || $0.english.caseInsensitiveCompare(tapped.word) == .orderedSame
        }
        baseWord = matches.first { $0.partOfSpeech == found.partOfSpeech } ?? matches.first
        if baseWord == nil { requestTranslation() }
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
                // Глагол — с «to», иначе переводчик часто выдаёт существительное
                let source = partOfSpeech == "v." ? "to \(lemma)" : lemma
                translation = Self.cleaned(try await session.translate(source).targetText)
            }
            if wantsSentence, sentenceTranslation == nil {
                sentenceTranslation = try await session.translate(tapped.sentence).targetText
            }
        } catch {
            translationFailed = true
        }
    }

    /// «Маяк.» → «маяк», «чтобы бежать» → «бежать»
    private static func cleaned(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if text.lowercased().hasPrefix("чтобы ") { text = String(text.dropFirst("чтобы ".count)) }
        guard let first = text.first, text.dropFirst().contains(where: \.isLowercase) || text.count == 1 else { return text }
        return first.lowercased() + text.dropFirst()
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
    }
}
