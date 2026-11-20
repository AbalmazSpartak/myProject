import SwiftUI
import SwiftData

/// Тренировка «Слово в контексте»: пример с пропуском вместо изучаемого слова
struct ClozeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var userInput = ""
    @State private var result: ClozeResult?
    @State private var showHint = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    /// Подход окончен — показываем итог вместо следующего слова
    @State private var isApproachFinished = false
    @State private var approachAnswered = 0
    @State private var approachCorrect = 0
    /// Слова с ошибками в этом подходе — в итоге «Вернутся позже»
    @State private var missed: [Word] = []

    @FocusState private var isInputFocused: Bool

    /// Слова из выбранных словарей, у которых в примере отмечено целевое слово.
    /// Запросом к базе — все слова не читаем (10 000+ — ~2 с на iPhone 12)
    private func clozeWords(limit: Int?) -> [Word] {
        let marked = #Predicate<Word> { $0.example.contains("<b>") }
        return StudyWords.random(StudyWords.all(StudyWords.scope(studyScope), marked), limit: limit, in: modelContext)
            .filter { $0.clozeParts != nil }
    }

    private var currentWord: Word? {
        currentIndex < sessionWords.count ? sessionWords[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isApproachFinished {
                TrainingSummary(
                    subtitle: "Верно \(approachCorrect) из \(approachAnswered).",
                    tiles: [
                        .init(symbol: "checkmark.circle", color: .statusKnown, value: approachCorrect, title: "Верно"),
                        .init(symbol: "xmark.circle", color: .statusLearning, value: approachAnswered - approachCorrect, title: "Ошибки")
                    ],
                    laterTitle: "Вернутся позже",
                    later: missed,
                    onContinue: { withAnimation { startSession() } },
                    onExit: { dismiss() }
                )
                .transition(.opacity)
            } else if let word = currentWord, let parts = word.clozeParts {
                card(for: word, parts: parts)
            } else {
                TrainingEmpty(systemImage: "text.badge.xmark", text: "Нет слов с примерами в выбранных словарях")
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            NeuralVoice.shared.warmUp()
            startSession()
        }
    }

    // MARK: - Части экрана

    private var header: some View {
        HStack {
            Spacer()
            HelpButton(topic: .cloze)
            LXTextButton(title: "Закончить", isMuted: true) { dismiss() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(minHeight: 52)
    }

    private func card(for word: Word, parts: (before: String, answer: String, after: String)) -> some View {
        VStack(spacing: 0) {
            TrainingCard(score: totalAnswered == 0 ? "" : "Верно \(correctCount) из \(totalAnswered)", level: word.cefrLevel) {
                ScrollView {
                    VStack(spacing: 14) {
                        ClozeSentence(parts: parts, revealed: result != nil, showHint: showHint)
                            .padding(.top, 20)
                        VStack(spacing: 4) {
                            Text(word.russian)
                                .scaledFont(size: 18, weight: .semibold)
                                .foregroundStyle(Color.brandDark)
                            PartOfSpeechBadge(word: word)
                            // Само слово не подсказываем — только что в пропуске оно в изменённой форме
                            if result == nil, word.exampleForm != nil {
                                Text("В пропуске — изменённая форма слова (-s, -ed, -ing…). Словарная форма тоже засчитается.")
                                    .scaledFont(size: 13)
                                    .foregroundStyle(Color.brandMuted)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                            }
                        }
                        if let result {
                            ClozeResultBanner(result: result, answer: parts.answer)
                                .transition(.opacity)
                                .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 10) {
                answerField(answer: parts.answer, word: word)
                actionButton(answer: parts.answer, word: word)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
    }

    private func answerField(answer: String, word: Word) -> some View {
        HStack(spacing: 10) {
            LXField(label: "Пропущенное слово") {
                TextField("Впишите слово", text: $userInput)
                    .scaledFont(size: 18, weight: .medium)
                    .foregroundStyle(Color.brandDark)
                    .focused($isInputFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(result == nil ? .done : .next)
                    .disabled(result != nil)
                    .onSubmit { result == nil ? check(answer: answer, word: word) : next() }
            }
            .overlay {
                if result != nil || isInputFocused {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(borderColor, lineWidth: 1.5)
                }
            }

            if result == nil {
                Button { withAnimation { showHint = true } } label: {
                    LXIconLabel(systemImage: "lightbulb", label: "Подсказка: первая буква", isSoft: !showHint)
                        .opacity(showHint ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(showHint)
            }
        }
    }

    private func actionButton(answer: String, word: Word) -> some View {
        let isEmpty = userInput.trimmingCharacters(in: .whitespaces).isEmpty
        return LXButton(title: result == nil ? "Проверить" : "Дальше", isEnabled: !(result == nil && isEmpty)) {
            result == nil ? check(answer: answer, word: word) : next()
        }
    }

    private var borderColor: Color {
        switch result {
        case nil: return Color.brandTint
        case .wrong: return Color.statusLearning
        default: return Color.statusKnown
        }
    }

    // MARK: - Логика

    private func startSession() {
        sessionWords = clozeWords(limit: sessionLength > 0 ? sessionLength : nil)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
        missed = []
        resetQuestion()
    }

    private func resetQuestion() {
        userInput = ""
        result = nil
        showHint = false
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            isInputFocused = true
        }
    }

    private func check(answer: String, word: Word) {
        guard !userInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let outcome = ClozeResult.evaluate(input: userInput, answer: answer, baseWord: word.english)

        word.isMistake = outcome == .wrong
        totalAnswered += 1
        approachAnswered += 1
        if outcome != .wrong {
            correctCount += 1
            approachCorrect += 1
        } else {
            missed.append(word)
        }
        DailyStudy.record(word, rating: outcome == .wrong ? .again : .good)
        UINotificationFeedbackGenerator().notificationOccurred(outcome == .wrong ? .error : .success)
        TextToSpeechManager.shared.speak(word.plainExample)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { result = outcome }
    }

    private func next() {
        if currentIndex + 1 >= sessionWords.count {
            // С лимитом подхода — итог, без лимита («все») — сразу следующий круг
            if sessionLength > 0 {
                withAnimation { isApproachFinished = true }
            } else {
                startSession()
            }
        } else {
            currentIndex += 1
            resetQuestion()
        }
    }
}

// MARK: - Проверка ответа

enum ClozeResult: Equatable {
    case exact      // вписана та же форма, что в предложении
    case baseForm   // вписана словарная форма, а в предложении другая (captured / capture)
    case wrong

    static func evaluate(input: String, answer: String, baseWord: String) -> ClozeResult {
        let normalize = { (s: String) in
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "’", with: "'")
        }
        let typed = normalize(input)
        if typed == normalize(answer) { return .exact }
        if typed == normalize(baseWord) { return .baseForm }
        return .wrong
    }
}

// MARK: - Предложение с пропуском

private struct ClozeSentence: View {
    let parts: (before: String, answer: String, after: String)
    let revealed: Bool
    let showHint: Bool

    var body: some View {
        (Text(parts.before) + middle + Text(parts.after))
            .scaledFont(size: 26, weight: .regular, design: .serif)
            .foregroundColor(.brandDark)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var middle: Text {
        if revealed {
            return Text(parts.answer).bold().foregroundColor(.brandTint)
        }
        // Длина пропуска подсказывает длину слова; с подсказкой видна первая буква
        let blankLength = max(5, parts.answer.count)
        let blank = showHint
            ? String(parts.answer.prefix(1)) + String(repeating: "_", count: blankLength - 1)
            : String(repeating: "_", count: blankLength)
        return Text(blank).bold().foregroundColor(.brandTint)
    }
}

// MARK: - Результат

private struct ClozeResultBanner: View {
    let result: ClozeResult
    let answer: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: result == .wrong ? "xmark.circle" : "checkmark.circle.fill")
                    .scaledFont(size: 22)
                Text(title)
                    .scaledFont(size: 18, weight: .semibold)
            }
            .foregroundStyle(result == .wrong ? Color.statusLearning : Color.statusKnown)

            if result != .exact {
                Text(result == .wrong ? "Правильно: \(answer)" : "В этом предложении нужна форма: \(answer)")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundColor(Color.brandMuted)
            }
        }
    }

    private var title: String {
        switch result {
        case .exact: return "Верно"
        case .baseForm: return "Почти"
        case .wrong: return "Неверно"
        }
    }
}
