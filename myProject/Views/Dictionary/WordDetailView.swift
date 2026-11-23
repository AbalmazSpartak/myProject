import SwiftUI
import SwiftData
import UIKit

/// Карточка слова из словаря (нажатие на строку) по дизайну LexiStream: картинка, перевод, пример, толкование,
/// как читать, состояние слова, правка и «Ошибка в слове»
struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("show_word_images") private var showWordImages = true

    let word: Word

    @State private var others: [Word] = []
    @State private var isEditing = false
    @State private var isReporting = false
    @State private var definedWord: DefinedWord?
    @State private var isConfirmingReset = false
    private let fsrs = FSRSCalculator()

    /// Толкование — в словаре iPhone, он есть не для каждого слова
    private var hasDefinition: Bool {
        UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word.english)
    }

    var body: some View {
        VStack(spacing: 0) {
            LXNavBar {
                LXBackButton { dismiss() }
            } trailing: {
                HStack(spacing: 0) {
                    Button { isEditing = true } label: { LXIconLabel(systemImage: "pencil", label: "Изменить слово") }
                        .buttonStyle(.plain)
                    LXMenu { moreMenu } label: { LXIconLabel(systemImage: "ellipsis", label: "Ещё") }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Пустое место под ещё не загрузившуюся картинку не держим: она появится сама
                    if showWordImages, word.imageData != nil || word.isImageHidden {
                        WordImageView(word: word)
                            .padding(.bottom, 4)
                    }
                    header
                    translation
                    if !word.example.isEmpty { exampleCard }
                    if !others.isEmpty { othersCard }
                    if hasDefinition { definitionRow }
                    ReadingBreakdownView(word: word.english, lemma: "", transcription: word.transcription,
                                         translation: word.russian)
                        .padding(.top, 14)
                    statusSection
                    actions
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear { others = Homographs.others(of: word, in: modelContext) }
        .task(id: word.persistentModelID) {
            guard showWordImages else { return }
            await WordImageLoader.loadIfNeeded(word)
        }
        .sheet(isPresented: $isEditing, onDismiss: { modelContext.saveReporting() }) {
            EditWordView(word: word)
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isReporting) {
            ReportWordView(word: word)
                .presentationDetents([.large])
                .appThemedColorScheme()
        }
        .sheet(item: $definedWord) { item in
            SystemDefinitionView(term: item.term)
        }
        .lxDialog("Сбросить прогресс слова?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
            Button("Сбросить", role: .destructive, action: resetProgress)
        } message: {
            Text("Слово снова станет новым: повторения и «забыто раз» обнулятся.")
        }
    }

    @ViewBuilder
    private var moreMenu: some View {
        Button { TextToSpeechManager.shared.speak(word.english) } label: { Label("Озвучить", systemImage: "speaker.wave.2") }
        if hasDefinition {
            Button { definedWord = DefinedWord(term: word.english) } label: { Label("Толкование", systemImage: "text.book.closed") }
        }
        if !word.isCustom {
            Button { isReporting = true } label: { Label("Ошибка в слове", systemImage: "flag") }
        }
    }

    // MARK: - Слово и перевод

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if !word.partOfSpeech.isEmpty { tag(Self.fullPartOfSpeech(word)) }
                LevelBadge(level: word.cefrLevel)
                if !word.isCustom, !word.tags.isEmpty {
                    tag(word.tags == StudyScope.oxfordTag ? "Oxford" : "доп.")
                }
            }
            .padding(.top, 14)

            Text(word.english)
                .tracking(-0.4)
                .scaledFont(size: 46, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
                .textSelection(.enabled)
                .padding(.top, 6)

            HStack(spacing: 10) {
                if !word.displayTranscription.isEmpty {
                    Text(word.displayTranscription)
                        .scaledFont(size: 16)
                        .foregroundStyle(Color.brandMuted)
                }
                Button { TextToSpeechManager.shared.speak(word.english) } label: {
                    LXIconLabel(systemImage: "speaker.wave.2", label: "Озвучить слово", isSoft: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
    }

    private var translation: some View {
        Text(word.russian)
            .scaledFont(size: 24, weight: .regular, design: .serif)
            .foregroundStyle(Color.brandDark)
            .textSelection(.enabled)
            .padding(.top, 2)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 12, weight: .semibold)
            .foregroundStyle(Color.brandMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    /// «n.» → «существительное»; незнакомое — как в базе
    private static func fullPartOfSpeech(_ word: Word) -> String {
        let names = ["n.": "существительное", "v.": "глагол", "adj.": "прилагательное", "adv.": "наречие", "prep.": "предлог",
                     "pron.": "местоимение", "num.": "числительное", "det.": "определитель", "conj.": "союз",
                     "excl.": "междометие", "exclam.": "междометие", "modal v.": "модальный глагол",
                     "phr. v.": "фразовый глагол", "phr.": "выражение", "art.": "артикль", "part.": "частица"]
        let tag = word.partOfSpeech.trimmingCharacters(in: .whitespaces).lowercased()
        return names[tag] ?? word.russianPartOfSpeech
    }

    // MARK: - Пример, значения, толкование

    private var exampleCard: some View {
        LXCard {
            VStack(alignment: .leading, spacing: 8) {
                LXSectionLabel(text: word.lists.isEmpty ? "Пример" : "Из книги")
                Text(Self.highlighted(word.example))
                    .scaledFont(size: 19, design: .serif)
                    .italic()
                    .foregroundStyle(Color.brandDark)
                    .lineSpacing(3)
                if let source = word.lists.first {
                    Label(DictionaryView.shortName(source.name, limit: 40), systemImage: "book.closed")
                        .scaledFont(size: 13)
                        .foregroundStyle(Color.brandMuted)
                }
                Button { TextToSpeechManager.shared.speak(word.plainExample) } label: {
                    Label("Прослушать пример", systemImage: "play.circle")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(Color.brandTint)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 14)
    }

    /// Пример с целевым словом на мягкой подложке (в базе — <b>слово</b>)
    static func highlighted(_ example: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(example)
        while let open = rest.range(of: "<b>"),
              let close = rest.range(of: "</b>", range: open.upperBound..<rest.endIndex) {
            result += AttributedString(String(rest[..<open.lowerBound]))
            var mark = AttributedString(String(rest[open.upperBound..<close.lowerBound]))
            mark.inlinePresentationIntent = .stronglyEmphasized
            mark.foregroundColor = .brandOnSoft
            mark.backgroundColor = .brandAccent
            result += mark
            rest = rest[close.upperBound...]
        }
        result += AttributedString(String(rest))
        return result
    }

    /// Другие значения того же написания: book — книга и book — бронировать
    private var othersCard: some View {
        LXCard {
            VStack(alignment: .leading, spacing: 6) {
                LXSectionLabel(text: "Так же пишется")
                ForEach(others) { other in
                    (Text(other.russianPartOfSpeech).italic().foregroundColor(Color.brandMuted) + Text(" — \(other.russian)"))
                        .scaledFont(size: 15)
                        .foregroundStyle(Color.brandDark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 12)
    }

    private var definitionRow: some View {
        Button { definedWord = DefinedWord(term: word.english) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    LXSectionLabel(text: "Толкование")
                    Text("Словарь iPhone")
                        .scaledFont(size: 15)
                        .foregroundStyle(Color.brandDark)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(Color.brandMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    // MARK: - Состояние

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            LXSectionLabel(text: "Статус")
                .padding(.top, 14)
            HStack(spacing: 6) {
                ForEach(WordStatus.allCases) { status in
                    let isOn = word.studyStatus == status
                    Button { setStatus(status) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: status.symbol).scaledFont(size: 16).foregroundStyle(status.color)
                            Text(status.title)
                        }
                        .scaledFont(size: 14, weight: isOn ? .semibold : .medium)
                        .foregroundStyle(isOn ? Color.brandOnSoft : Color.brandDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .lxSelectable(isOn: isOn)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            progressText
        }
    }

    @ViewBuilder
    private var progressText: some View {
        VStack(alignment: .leading, spacing: 2) {
            if word.reps == 0 {
                Text("Ещё не встречалось в тренировках")
            } else {
                Text("Повторений: \(word.reps)" + (word.lapses > 0 ? " · забывалось: \(word.lapses)" : ""))
                Text("Следующее повторение: " + Self.dueText(word.dueDate))
            }
            if word.isMistake {
                Label("В списке «Слова с ошибками»", systemImage: "flag")
            }
        }
        .scaledFont(size: 13)
        .foregroundStyle(Color.brandMuted)
        .padding(.top, 4)
    }

    private static func dueText(_ date: Date) -> String {
        if date <= Date() { return "уже пора" }
        if Calendar.current.isDateInTomorrow(date) { return "завтра" }
        return date.formatted(.relative(presentation: .named))
    }

    /// «Знаю» — как ответ «Легко» (слово уходит в обычные повторения с длинным интервалом);
    /// «Учу» — на заучивание (новое — как ответ «Снова», знакомое — как забытое); «Новое» — сброс прогресса с вопросом
    private func setStatus(_ status: WordStatus) {
        guard word.studyStatus != status else { return }
        Haptics.tap()
        switch status {
        case .known:
            fsrs.calculateNextReview(word: word, rating: .easy)
            word.isMistake = false
        case .learning:
            fsrs.calculateNextReview(word: word, rating: .again)
        case .new:
            isConfirmingReset = true
            return
        }
        modelContext.saveReporting()
    }

    private func resetProgress() {
        word.state = .new
        word.reps = 0
        word.lapses = 0
        word.stability = 0
        word.difficulty = 0
        word.dueDate = Date()
        word.lastReview = nil
        word.isMistake = false
        modelContext.saveReporting()
    }

    // MARK: - Действия

    private var actions: some View {
        HStack {
            Button { isEditing = true } label: {
                Label("Изменить", systemImage: "pencil")
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(Color.brandTint)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            if !word.isCustom {
                Button { isReporting = true } label: {
                    Label("Сообщить об ошибке", systemImage: "flag")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundStyle(Color.brandMuted)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }
}
