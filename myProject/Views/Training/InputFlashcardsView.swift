import SwiftUI
import SwiftData

struct InputFlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    /// Счётчики для меню фильтров — пересчитываются после загрузки и ответа
    @State private var counts = WordCounts()
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: TrainingFilter = .all
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    
    @State private var userInput = ""
    @State private var showResult = false
    @State private var isCorrect = false
    /// Другие значения того же написания (speed сущ. / гл.)
    @State private var homographs: [Word] = []
    /// Ответ подошёл к другому значению — не ошибка, но поясняем
    @State private var homographNote: String?
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
    
    private var currentWord: Word? {
        guard !sessionWords.isEmpty, currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    private var currentQuestion: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.prompt(ambiguous: !homographs.isEmpty) : word.russian
    }
    
    private var currentCorrectAnswerString: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.russian : word.english
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TrainingTopBar(current: currentFilter, counts: counts, categories: categories, helpTopic: .inputCards,
                           onSelect: changeFilter, onExit: { dismiss() })

            if isApproachFinished {
                TrainingSummary(
                    subtitle: "Верно \(approachCorrect) из \(approachAnswered).",
                    tiles: [
                        .init(symbol: "checkmark.circle", color: .statusKnown, value: approachCorrect, title: "Верно"),
                        .init(symbol: "xmark.circle", color: .statusLearning, value: approachAnswered - approachCorrect, title: "Ошибки")
                    ],
                    laterTitle: "Вернутся позже",
                    later: missed,
                    onContinue: { withAnimation { generateSession() } },
                    onExit: { dismiss() }
                )
                .transition(.opacity)
            } else if sessionWords.isEmpty {
                TrainingEmpty(systemImage: currentFilter == .mistakes ? "checkmark.circle" : "keyboard",
                              text: currentFilter == .mistakes ? "Неисправленных ошибок нет" : "В выбранном разделе нет слов")
            } else if let word = currentWord {
                TrainingCard(score: totalAnswered == 0 ? "" : "Верно \(correctCount) из \(totalAnswered)", level: word.cefrLevel) {
                    ScrollView {
                        VStack(spacing: 16) {
                            TrainingQuestion(word: word, text: currentQuestion, isEnglish: translationMode == "en_ru")
                                .padding(.top, 8)
                            if showResult { resultBlock(word) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    LXField(label: translationMode == "en_ru" ? "Перевод на русский" : "Перевод на английский") {
                        TextField("Ваш перевод", text: $userInput)
                            .scaledFont(size: 18, weight: .medium)
                            .foregroundStyle(Color.brandDark)
                            .focused($isInputFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(showResult ? .next : .done)
                            .onSubmit {
                                if !showResult && !userInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                    checkAnswer()
                                } else if showResult {
                                    nextWord()
                                }
                            }
                            .disabled(showResult)
                    }
                    .overlay {
                        if showResult || isInputFocused {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(inputBorderColor, lineWidth: 1.5)
                        }
                    }

                    if showResult {
                        LXButton(title: "Следующее слово", action: nextWord)
                    } else {
                        LXButton(title: "Проверить",
                                 isEnabled: !userInput.trimmingCharacters(in: .whitespaces).isEmpty,
                                 action: checkAnswer)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        // «Озвучивать слово сразу» (⚙️ → «Озвучка»): англ ➔ рус — как только слово показано
        .onChange(of: currentWord?.persistentModelID, initial: true) {
            guard translationMode == "en_ru", !isApproachFinished, let word = currentWord else { return }
            TextToSpeechManager.shared.speakAutomatically(word.english)
        }
        .onAppear {
            NeuralVoice.shared.warmUp()
            loadWords()
            generateSession()
        }
    }

    /// Итог ответа внутри карточки: верно или нет, правильный ответ, пояснение, пример
    private func resultBlock(_ word: Word) -> some View {
        let isAlmost = homographNote != nil
        return VStack(spacing: 10) {
            Label(isAlmost ? "Почти" : isCorrect ? "Верно" : "Неверно",
                  systemImage: isAlmost ? "checkmark.circle" : isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                .scaledFont(size: 18, weight: .semibold)
                .foregroundStyle(isCorrect ? Color.statusKnown : Color.statusLearning)

            if let homographNote {
                Text(homographNote)
                    .scaledFont(size: 14)
                    .foregroundStyle(Color.brandDark)
                    .multilineTextAlignment(.center)
            }

            if !isCorrect {
                VStack(spacing: 2) {
                    LXSectionLabel(text: "Правильный ответ")
                    Text(currentCorrectAnswerString)
                        .scaledFont(size: 26, weight: .medium, design: .serif)
                        .foregroundStyle(Color.brandDark)
                        .multilineTextAlignment(.center)
                }
            }

            if !word.example.isEmpty {
                FlashcardExample(word: word)
                    .padding(.top, 4)
            }
        }
        .transition(.opacity)
    }

    private var inputBorderColor: Color {
        guard showResult else { return Color.brandTint }
        return isCorrect ? Color.statusKnown : Color.statusLearning
    }
    
    private func changeFilter(to filter: TrainingFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        showResult = false
        userInput = ""
        generateSession()
    }
    
    /// Счётчики для меню — запросами к базе: все слова не читаем (10 000+ — ~2 с на iPhone 12)
    private func loadWords() {
        // «На повторение» — сразу, числа тем — порциями после показа первого слова
        counts.refreshProgress(scope: studyScope, in: modelContext)
        Task {
            await StudyWords.warmCategoryCounts(scope: studyScope, categories: categories, in: modelContext)
            counts = WordCounts(scope: studyScope, categories: categories, in: modelContext)
        }
    }

    private func generateSession() {
        sessionWords = StudyWords.session(currentFilter, scope: studyScope, length: sessionLength, in: modelContext)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
        missed = []
        resetQuestion()
    }

    /// Слова подхода закончились: с лимитом — итог, без лимита («все») — сразу следующий круг
    private func finishApproach() {
        if sessionLength > 0 {
            withAnimation { isApproachFinished = true }
        } else {
            generateSession()
        }
    }
    
    private func resetQuestion() {
        userInput = ""
        showResult = false
        isCorrect = false
        homographNote = nil
        homographs = currentWord.map { Homographs.others(of: $0, in: modelContext) } ?? []
        
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            isInputFocused = true
        }
    }
    
    private func checkAnswer() {
        guard let word = currentWord else { return }
        
        let targetAnswer = currentCorrectAnswerString
        isCorrect = validateInput(userInput, target: targetAnswer)
        // Перевод другого значения того же слова (скорость для глагола speed) — не ошибка
        if !isCorrect, translationMode == "en_ru",
           let other = homographs.first(where: { validateInput(userInput, target: $0.russian) }) {
            isCorrect = true
            homographNote = Homographs.note(answered: other, expected: word)
        }
        
        if isCorrect {
            correctCount += 1
            word.isMistake = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            word.isMistake = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        totalAnswered += 1
        approachAnswered += 1
        if isCorrect { approachCorrect += 1 } else { missed.append(word) }
        counts.refreshProgress(scope: studyScope, in: modelContext)
        
        TextToSpeechManager.shared.speak(word.english)
        
        profiles.first?.recordAnswer(.flashcards, translationMode: translationMode, isCorrect: isCorrect)
        DailyStudy.record(word, rating: isCorrect ? .good : .again)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showResult = true
        }
    }
    
    private func validateInput(_ input: String, target: String) -> Bool {
        let cleanedInput = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
        
        guard !cleanedInput.isEmpty else { return false }
        
        let separators = CharacterSet(charactersIn: ",;/")
        func variants(of text: String) -> [String] {
            text.components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "ё", with: "е") }
                .filter { !$0.isEmpty }
        }
        let rawVariants = variants(of: target)

        // Дополнительно: варианты без текста в скобках (например, "(не переводится)").
        // Скобки убираем до разбиения, иначе "статья (в газете/журнале)" разрежется по "/"
        var withoutParentheses = target
        while let openRange = withoutParentheses.range(of: "("), let closeRange = withoutParentheses.range(of: ")", range: openRange.upperBound..<withoutParentheses.endIndex) {
            withoutParentheses.removeSubrange(openRange.lowerBound...closeRange.lowerBound)
        }
        let variantsWithoutParentheses = variants(of: withoutParentheses)
        
        let targetVariants = Set(rawVariants + variantsWithoutParentheses).filter { !$0.isEmpty }
        
        return targetVariants.contains(cleanedInput)
    }
    
    private func nextWord() {
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                finishApproach()
            } else {
                currentIndex += 1
                resetQuestion()
            }
        }
    }
}
