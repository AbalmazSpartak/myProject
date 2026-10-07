import SwiftUI
import SwiftData

struct InputFlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var allWords: [Word] = []
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []
    /// Счётчики для меню фильтров — пересчитываются после загрузки и ответа
    @State private var counts = WordCounts()
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: TrainingFilter = .all
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    
    @State private var userInput = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    /// Подход окончен — показываем итог вместо следующего слова
    @State private var isApproachFinished = false
    @State private var approachAnswered = 0
    @State private var approachCorrect = 0
    
    @FocusState private var isInputFocused: Bool
    
    private var currentWord: Word? {
        guard !sessionWords.isEmpty, currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    private var currentQuestion: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.english : word.russian
    }
    
    private var currentCorrectAnswerString: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.russian : word.english
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .scaledFont(size: 16, weight: .semibold)
                        Text("Обзор")
                            .scaledFont(size: 17, weight: .semibold, design: .rounded)
                    }
                    .foregroundColor(.teal)
                }
                
                Spacer()

                HelpButton(topic: .inputCards)
                    .padding(.trailing, 8)
                
                VStack(alignment: .trailing, spacing: 6) {
                    TrainingFilterMenu(
                        current: currentFilter,
                        counts: counts,
                        categories: categories,
                        icon: "folder.fill",
                        tint: .teal,
                        onSelect: changeFilter
                    )
                    
                    Text("Ввод: \(correctCount)/\(totalAnswered)")
                        .scaledFont(size: 13, weight: .bold, design: .rounded)
                        .foregroundColor(.gray)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
            
            if isApproachFinished {
                ApproachDoneCard(
                    summary: "Верно \(approachCorrect) из \(approachAnswered)",
                    tint: .teal,
                    onContinue: { withAnimation { generateSession() } },
                    onExit: { dismiss() }
                )
            } else if sessionWords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: currentFilter == .mistakes ? "checkmark.circle.fill" : "keyboard")
                        .font(.system(size: 48))
                        .foregroundColor(currentFilter == .mistakes ? .green : .gray)
                    
                    Text(currentFilter == .mistakes ? "Отлично! У вас нет неисправленных ошибок." : "В выбранном разделе нет слов.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else if let word = currentWord {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Text(currentQuestion)
                                .scaledFont(size: 34, weight: .semibold, design: .serif)
                                .foregroundColor(.brandDark)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { TextToSpeechManager.shared.speak(word.english) }) {
                                Image(systemName: "speaker.wave.2.bubble.fill")
                                    .scaledFont(size: 22)
                                    .foregroundColor(.teal)
                            }
                        }
                        
                        // Транскрипция и часть речи — одной строкой; без транскрипции — только часть речи
                        HStack(spacing: 8) {
                            if translationMode == "en_ru" && !word.displayTranscription.isEmpty {
                                Text(word.displayTranscription)
                                    .scaledFont(size: 16, weight: .semibold, design: .rounded)
                                    .foregroundColor(.orange)
                            }
                            PartOfSpeechBadge(word: word)
                        }
                    }
                    .padding(.top, 24)
                    
                    Divider()
                        .padding(.horizontal, 10)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(translationMode == "en_ru" ? "Введите перевод на русский:" : "Введите перевод на английский:")
                            .scaledFont(size: 13, weight: .medium, design: .rounded)
                            .foregroundColor(.gray)
                        
                        TextField("Ваш перевод...", text: $userInput)
                            .scaledFont(size: 18, weight: .semibold, design: .rounded)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.brandFill)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(inputBorderColor, lineWidth: 2)
                            )
                            .focused($isInputFocused)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onSubmit {
                                if !showResult && !userInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                    checkAnswer()
                                } else if showResult {
                                    nextWord()
                                }
                            }
                            .disabled(showResult)
                    }
                    .padding(.horizontal, 16)
                    
                    if showResult {
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .scaledFont(size: 22)
                                
                                Text(isCorrect ? "Правильно!" : "Неверно")
                                    .scaledFont(size: 18, weight: .bold, design: .rounded)
                            }
                            .foregroundColor(isCorrect ? .green : .red)
                            
                            if !isCorrect {
                                VStack(spacing: 4) {
                                    Text("Правильный ответ:")
                                        .scaledFont(size: 12, weight: .medium, design: .rounded)
                                        .foregroundColor(.gray)
                                    
                                    Text(currentCorrectAnswerString)
                                        .scaledFont(size: 20, weight: .bold, design: .rounded)
                                        .foregroundColor(.brandDark)
                                }
                            }
                            
                            if !word.example.isEmpty {
                                (Text("Пример: ") + Text(word.attributedExample))
                                    .scaledFont(size: 13, weight: .regular, design: .rounded)
                                    .italic()
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.vertical, 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    VStack {
                        if !showResult {
                            Button(action: checkAnswer) {
                                Text("Проверить")
                                    .scaledFont(size: 16, weight: .bold, design: .rounded)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(userInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.teal.opacity(0.4) : Color.teal)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            }
                            .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        } else {
                            Button(action: nextWord) {
                                Text("Следующее слово")
                                    .scaledFont(size: 16, weight: .bold, design: .rounded)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.teal)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground)
                .cornerRadius(28)
                .shadow(color: colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .background(Color.brandBackground.ignoresSafeArea())
        // «Озвучивать слово сразу» (⚙️ → «Озвучка»): англ ➔ рус — как только слово показано
        .onChange(of: currentWord?.persistentModelID, initial: true) {
            guard translationMode == "en_ru", !isApproachFinished, let word = currentWord else { return }
            TextToSpeechManager.shared.speakAutomatically(word.english)
        }
        .onAppear {
            loadWords()
            generateSession()
        }
    }
    
    private var inputBorderColor: Color {
        guard showResult else {
            return isInputFocused ? Color.teal : Color.brandDark.opacity(0.15)
        }
        return isCorrect ? Color.green : Color.red
    }
    
    private func changeFilter(to filter: TrainingFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        showResult = false
        userInput = ""
        generateSession()
    }
    
    private func loadWords() {
        allWords = modelContext.fetchAllWords()
        studyWords = allWords.filter { studyScope.includes($0) }
        counts = WordCounts(studyWords)
    }

    private func generateSession() {
        sessionWords = SessionLength.limited(currentFilter.sessionWords(from: studyWords), to: sessionLength)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
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
        
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            isInputFocused = true
        }
    }
    
    private func checkAnswer() {
        guard let word = currentWord else { return }
        
        let targetAnswer = currentCorrectAnswerString
        isCorrect = validateInput(userInput, target: targetAnswer)
        
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
        if isCorrect { approachCorrect += 1 }
        counts = WordCounts(studyWords)
        
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
