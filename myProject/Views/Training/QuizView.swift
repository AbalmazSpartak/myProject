import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    /// Неправильные варианты ответа — из нескольких сотен случайных слов, а не из всей базы
    @State private var distractors: [Word] = []
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    /// Счётчики для меню фильтров — пересчитываются после загрузки и ответа
    @State private var counts = WordCounts()
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: TrainingFilter = .all
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var options: [String] = []
    /// Другие значения того же написания — для «to» у глагола и чтобы не попасть в обманки
    @State private var homographs: [Word] = []
    
    @State private var selectedOption: String? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    /// Подход окончен — показываем итог вместо следующего слова
    @State private var isApproachFinished = false
    @State private var approachAnswered = 0
    @State private var approachCorrect = 0
    /// Слова с ошибками в этом подходе — в итоге «Вернутся позже»
    @State private var missed: [Word] = []
    
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
            TrainingTopBar(current: currentFilter, counts: counts, categories: categories, helpTopic: .quiz,
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
                TrainingEmpty(systemImage: currentFilter == .mistakes ? "checkmark.circle" : "doc.text.magnifyingglass",
                              text: currentFilter == .mistakes ? "Неисправленных ошибок нет" : "В выбранном разделе нет слов")
            } else if let word = currentWord {
                TrainingCard(score: totalAnswered == 0 ? "" : "Верно \(correctCount) из \(totalAnswered)", level: word.cefrLevel) {
                    VStack {
                        Spacer(minLength: 0)
                        TrainingQuestion(word: word, text: currentQuestion, isEnglish: translationMode == "en_ru")
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        QuizOptionRow(text: option, state: optionState(option), isLocked: showResult) {
                            selectOption(option)
                        }
                    }
                    if showResult {
                        LXButton(title: "Следующее слово", action: nextWord)
                            .padding(.top, 6)
                            .transition(.opacity)
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

    private func optionState(_ option: String) -> QuizOptionState {
        guard showResult else { return .plain }
        if isOptionCorrect(option) { return .correct }
        return selectedOption == option ? .wrong : .dimmed
    }

    private func changeFilter(to filter: TrainingFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        selectedOption = nil
        showResult = false
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
        distractors = StudyWords.random(#Predicate<Word> { _ in true }, limit: 300, in: modelContext)
    }

    private func generateSession() {
        sessionWords = StudyWords.session(currentFilter, scope: studyScope, length: sessionLength, in: modelContext)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
        missed = []
        setupQuestion()
    }

    /// Слова подхода закончились: с лимитом — итог, без лимита («все») — сразу следующий круг
    private func finishApproach() {
        if sessionLength > 0 {
            withAnimation { isApproachFinished = true }
        } else {
            generateSession()
        }
    }
    
    private func setupQuestion() {
        guard let word = currentWord else { return }
        selectedOption = nil
        showResult = false
        
        let correctAnswer = translationMode == "en_ru" ? word.russian : word.english
        homographs = Homographs.others(of: word, in: modelContext)
        // Перевод другого значения того же слова — тоже верный ответ, обманкой его не даём
        let also = translationMode == "en_ru" ? homographs.map(\.russian) : []
        
        let wrongAnswers = distractors.randomWrongAnswers(3, excluding: correctAnswer, also: also) {
            translationMode == "en_ru" ? $0.russian : $0.english
        }
        options = ([correctAnswer] + wrongAnswers).shuffled()
    }
    
    private func selectOption(_ option: String) {
        guard let word = currentWord else { return }
        selectedOption = option
        
        isCorrect = (option == currentCorrectAnswerString)
        
        if isCorrect {
            correctCount += 1
            word.isMistake = false
        } else {
            word.isMistake = true
        }
        totalAnswered += 1
        approachAnswered += 1
        if isCorrect { approachCorrect += 1 } else { missed.append(word) }
        counts.refreshProgress(scope: studyScope, in: modelContext)
        
        profiles.first?.recordAnswer(.quiz, translationMode: translationMode, isCorrect: isCorrect)
        DailyStudy.record(word, rating: isCorrect ? .good : .again)
        
        // Рус ➔ англ — английское слово звучит после ответа, чтобы не подсказывать
        if translationMode != "en_ru" {
            TextToSpeechManager.shared.speakAutomatically(word.english)
        }
        withAnimation { showResult = true }
    }
    
    private func isOptionCorrect(_ option: String) -> Bool {
        return option == currentCorrectAnswerString
    }
    
    private func nextWord() {
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                finishApproach()
            } else {
                currentIndex += 1
                setupQuestion()
            }
        }
    }
}
