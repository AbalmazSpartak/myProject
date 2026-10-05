import SwiftUI
import SwiftData

/// Тренировка «Слово в контексте»: пример с пропуском вместо изучаемого слова
struct ClozeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.modelContext) private var modelContext
    @State private var allWords: [Word] = []
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

    @FocusState private var isInputFocused: Bool

    /// Слова из выбранных словарей, у которых в примере отмечено целевое слово
    private var clozeWords: [Word] {
        allWords.filter { studyScope.includes($0) && $0.clozeParts != nil }
    }

    private var currentWord: Word? {
        currentIndex < sessionWords.count ? sessionWords[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer()

            if isApproachFinished {
                ApproachDoneCard(
                    summary: "Верно \(approachCorrect) из \(approachAnswered)",
                    tint: .pink,
                    onContinue: { withAnimation { startSession() } },
                    onExit: { dismiss() }
                )
            } else if let word = currentWord, let parts = word.clozeParts {
                card(for: word, parts: parts)
            } else {
                emptyState
            }

            Spacer()
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            allWords = modelContext.fetchAllWords()
            startSession()
        }
    }

    // MARK: - Части экрана

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .scaledFont(size: 16, weight: .semibold)
                    Text("Обзор")
                        .scaledFont(size: 17, weight: .semibold, design: .rounded)
                }
                .foregroundColor(.pink)
            }

            Spacer()

            HelpButton(topic: .cloze)
                .padding(.trailing, 8)

            Text("Верно: \(correctCount)/\(totalAnswered)")
                .scaledFont(size: 13, weight: .bold, design: .rounded)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Нет слов с примерами в выбранных словарях.")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    private func card(for word: Word, parts: (before: String, answer: String, after: String)) -> some View {
        VStack(spacing: 20) {
            ClozeSentence(parts: parts, revealed: result != nil, showHint: showHint)
                .padding(.top, 28)
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                Text(word.russian)
                    .scaledFont(size: 18, weight: .semibold, design: .rounded)
                    .foregroundColor(.brandDark)
                if !word.partOfSpeech.isEmpty {
                    Text(word.partOfSpeech)
                        .scaledFont(size: 13, weight: .medium, design: .rounded)
                        .italic()
                        .foregroundColor(.gray)
                }
            }

            Divider().padding(.horizontal, 10)

            answerField(answer: parts.answer, word: word)

            if let result {
                ClozeResultBanner(result: result, answer: parts.answer)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            actionButton(answer: parts.answer, word: word)
        }
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(28)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 20)
    }

    private func answerField(answer: String, word: Word) -> some View {
        HStack(spacing: 10) {
            TextField("Впишите слово...", text: $userInput)
                .scaledFont(size: 18, weight: .semibold, design: .rounded)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.brandFill)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor, lineWidth: 2)
                )
                .focused($isInputFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(result != nil)
                .onSubmit { result == nil ? check(answer: answer, word: word) : next() }

            if result == nil {
                Button(action: { withAnimation { showHint = true } }) {
                    Image(systemName: "lightbulb.fill")
                        .scaledFont(size: 20)
                        .foregroundColor(showHint ? .gray.opacity(0.4) : .orange)
                }
                .disabled(showHint)
                .accessibilityLabel("Подсказка: первая буква")
            }
        }
        .padding(.horizontal, 16)
    }

    private func actionButton(answer: String, word: Word) -> some View {
        let isEmpty = userInput.trimmingCharacters(in: .whitespaces).isEmpty
        return Button(action: { result == nil ? check(answer: answer, word: word) : next() }) {
            Text(result == nil ? "Проверить" : "Дальше")
                .scaledFont(size: 16, weight: .bold, design: .rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(result == nil && isEmpty ? Color.pink.opacity(0.4) : Color.pink)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
        .disabled(result == nil && isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private var borderColor: Color {
        switch result {
        case nil: return isInputFocused ? .pink : Color.brandDark.opacity(0.15)
        case .wrong: return .red
        default: return .green
        }
    }

    // MARK: - Логика

    private func startSession() {
        sessionWords = SessionLength.limited(clozeWords.shuffled(), to: sessionLength)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
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
            .scaledFont(size: 22, weight: .regular, design: .serif)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var middle: Text {
        if revealed {
            return Text(parts.answer).bold().foregroundColor(.pink)
        }
        // Длина пропуска подсказывает длину слова; с подсказкой видна первая буква
        let blankLength = max(5, parts.answer.count)
        let blank = showHint
            ? String(parts.answer.prefix(1)) + String(repeating: "_", count: blankLength - 1)
            : String(repeating: "_", count: blankLength)
        return Text(blank).bold().foregroundColor(.pink)
    }
}

// MARK: - Результат

private struct ClozeResultBanner: View {
    let result: ClozeResult
    let answer: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: result == .wrong ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .scaledFont(size: 22)
                Text(title)
                    .scaledFont(size: 18, weight: .bold, design: .rounded)
            }
            .foregroundColor(result == .wrong ? .red : .green)

            if result != .exact {
                Text(result == .wrong ? "Правильно: \(answer)" : "В этом предложении нужна форма: \(answer)")
                    .scaledFont(size: 14, weight: .medium, design: .rounded)
                    .foregroundColor(.gray)
            }
        }
    }

    private var title: String {
        switch result {
        case .exact: return "Правильно!"
        case .baseForm: return "Почти!"
        case .wrong: return "Неверно"
        }
    }
}
