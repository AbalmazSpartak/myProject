import SwiftUI
import SwiftData

/// Карточка слова из словаря (нажатие на строку): перевод, пример, как читать, другие значения того же написания и прогресс
struct WordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let word: Word

    @State private var others: [Word] = []
    @State private var isEditing = false
    @State private var isReporting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    translationCard
                    if !word.example.isEmpty {
                        exampleCard
                    }
                    if !others.isEmpty {
                        othersCard
                    }
                    ReadingBreakdownView(word: word.english, lemma: "", transcription: word.transcription,
                                         translation: word.russian)
                    progressCard
                    actions
                }
                .padding(20)
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onAppear { others = Homographs.others(of: word, in: modelContext) }
        .sheet(isPresented: $isEditing, onDismiss: { try? modelContext.save() }) {
            EditWordView(word: word)
        }
        .sheet(isPresented: $isReporting) {
            ReportWordView(word: word)
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
    }

    // MARK: - Слово

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(word.english)
                    .scaledFont(size: 34, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    TextToSpeechManager.shared.speak(word.english)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .scaledFont(size: 24)
                        .foregroundColor(.orange)
                }
                .accessibilityLabel("Озвучить")
            }
            HStack(spacing: 8) {
                if !word.displayTranscription.isEmpty {
                    Text(word.displayTranscription)
                        .scaledFont(size: 17, design: .serif)
                        .foregroundColor(.gray)
                }
                if !word.partOfSpeech.isEmpty {
                    Text(word.russianPartOfSpeech)
                        .scaledFont(size: 14)
                        .italic()
                        .foregroundColor(.gray)
                }
                badge(word.cefrLevel, color: .indigo)
                if !word.isCustom, !word.tags.isEmpty {
                    let isOxford = word.tags == StudyScope.oxfordTag
                    badge(isOxford ? "Oxford" : "доп.", color: isOxford ? .teal : .gray)
                }
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .scaledFont(size: 12, weight: .bold, design: .rounded)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private var translationCard: some View {
        Text(word.russian)
            .scaledFont(size: 22, weight: .medium, design: .serif)
            .foregroundColor(.brandDark)
            .textSelection(.enabled)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground)
            .cornerRadius(14)
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(word.attributedExample)
                .scaledFont(size: 17, design: .serif)
                .foregroundColor(.brandDark)
            Button {
                TextToSpeechManager.shared.speak(word.plainExample)
            } label: {
                Label("Прослушать пример", systemImage: "play.circle")
                    .scaledFont(size: 15)
            }
            .tint(.brown)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    /// Другие значения того же написания: book — книга и book — бронировать
    private var othersCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Так же пишется")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(.gray)
            ForEach(others) { other in
                (Text(other.russianPartOfSpeech).italic().foregroundColor(.gray) + Text(" — \(other.russian)"))
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    // MARK: - Прогресс

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Изучение")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(.gray)
            if word.reps == 0 {
                Text("Ещё не встречалось в тренировках")
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark)
            } else {
                Text("Повторений: \(word.reps)" + (word.lapses > 0 ? " · забывалось: \(word.lapses)" : ""))
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark)
                Text("Следующее повторение: " + Self.dueText(word.dueDate))
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark)
            }
            if word.isMistake {
                Label("В списке «Слова с ошибками»", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(size: 14)
                    .foregroundColor(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private static func dueText(_ date: Date) -> String {
        if date <= Date() { return "уже пора" }
        if Calendar.current.isDateInTomorrow(date) { return "завтра" }
        return date.formatted(.relative(presentation: .named))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                isEditing = true
            } label: {
                Label("Изменить", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.brown)
            if !word.isCustom {
                Button {
                    isReporting = true
                } label: {
                    Label("Ошибка в слове", systemImage: "exclamationmark.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .scaledFont(size: 15, weight: .semibold)
    }
}
