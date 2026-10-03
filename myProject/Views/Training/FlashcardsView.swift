import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    @AppStorage("show_word_images") private var showWordImages: Bool = true

    @Query(sort: \Category.name) private var categories: [Category]
    @State private var allWords: [Word] = []
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []
    /// Счётчики для меню фильтров — пересчитываются после загрузки и ответа
    @State private var counts = WordCounts()
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: TrainingFilter = .due
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    
    @State private var reviewedCount = 0
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    /// Подход окончен — показываем итог вместо следующего слова
    @State private var isApproachFinished = false
    @State private var approachAnswered = 0
    @State private var approachCorrect = 0
    @AppStorage(DailyNewWords.limitKey) private var newWordsPerDay = DailyNewWords.defaultLimit
    private let fsrs = FSRSCalculator()
    
    private var currentWord: Word? {
        guard !sessionWords.isEmpty, currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    private var currentQuestion: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.english : word.russian
    }
    
    private var currentAnswer: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.russian : word.english
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Обзор")
                    }
                    .scaledFont(size: 16, weight: .semibold, design: .rounded)
                    .foregroundColor(.blue)
                }
                
                Spacer()

                HelpButton(topic: .flashcards)
                    .padding(.trailing, 8)

                TrainingFilterMenu(
                    current: currentFilter,
                    counts: counts,
                    categories: categories,
                    includesDue: true,
                    icon: "clock.badge.checkmark.fill",
                    tint: .blue,
                    backgroundOpacity: 0.1,
                    onSelect: changeFilter
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            HStack {
                Spacer()
                Text("Повторено: \(reviewedCount)")
                    .scaledFont(size: 13, weight: .bold, design: .rounded)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            Spacer()
            
            if isApproachFinished {
                ApproachDoneCard(
                    summary: "Вспомнили \(approachCorrect) из \(approachAnswered)",
                    tint: .blue,
                    onContinue: { withAnimation { generateSession() } },
                    onExit: { dismiss() }
                )
            } else if sessionWords.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text(currentFilter == .due ? "Отлично! Все запланированные слова повторены!" : "В выбранном разделе нет слов.")
                        .scaledFont(size: 18, weight: .bold, design: .rounded)
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else if let word = currentWord {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Text(currentQuestion)
                                .scaledFont(size: 34, weight: .semibold, design: .serif)
                                .foregroundColor(.brandDark)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { TextToSpeechManager.shared.speak(word.english) }) {
                                Image(systemName: "speaker.wave.2.bubble.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if translationMode == "en_ru" && !word.displayTranscription.isEmpty {
                            Text(word.displayTranscription)
                                .scaledFont(size: 16, weight: .medium, design: .rounded)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 28)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    if isAnswerRevealed {
                        VStack(spacing: 20) {
                            if showWordImages {
                                WordImageView(word: word)
                            }

                            Text(currentAnswer)
                                .scaledFont(size: 28, weight: .regular, design: .serif)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 8) {
                                Text("Как сложно было вспомнить?")
                                    .scaledFont(size: 12, weight: .medium, design: .rounded)
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 8) {
                                    FSRSActionButton(title: "Снова", color: .red) {
                                        processRating(.again)
                                    }
                                    FSRSActionButton(title: "Трудно", color: .orange) {
                                        processRating(.hard)
                                    }
                                    FSRSActionButton(title: "Хорошо", color: .green) {
                                        processRating(.good)
                                    }
                                    FSRSActionButton(title: "Легко", color: .blue) {
                                        processRating(.easy)
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isAnswerRevealed = true
                            }
                        }) {
                            Text("Показать ответ")
                                .scaledFont(size: 16, weight: .bold, design: .rounded)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
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
        // Картинка грузится заранее, пока пользователь вспоминает перевод
        // Рус ➔ англ — английское слово звучит вместе с ответом, чтобы не подсказывать
        .onChange(of: isAnswerRevealed) { _, isRevealed in
            guard isRevealed, translationMode != "en_ru", let word = currentWord else { return }
            TextToSpeechManager.shared.speakAutomatically(word.english)
        }
        .task(id: currentWord?.persistentModelID) {
            guard showWordImages, let word = currentWord else { return }
            await WordImageLoader.loadIfNeeded(word)
        }
    }
    
    private func changeFilter(to filter: TrainingFilter) {
        currentFilter = filter
        isAnswerRevealed = false
        generateSession()
    }
    
    private func loadWords() {
        allWords = modelContext.fetchAllWords()
        studyWords = allWords.filter { studyScope.includes($0) }
        counts = WordCounts(studyWords, newWordsAllowance: newWordsAllowance)
    }

    /// Сколько новых слов ещё можно начать сегодня; nil — без лимита
    private var newWordsAllowance: Int? {
        DailyNewWords.allowance(limit: newWordsPerDay)
    }

    private func generateSession() {
        let words = currentFilter.sessionWords(from: studyWords, newWordsAllowance: newWordsAllowance)
        sessionWords = SessionLength.limited(words, to: sessionLength)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
    }
    
    /// Слова подхода закончились: с лимитом — итог, без лимита («все») — сразу следующий круг
    private func finishApproach() {
        if sessionLength > 0 {
            withAnimation { isApproachFinished = true }
        } else {
            generateSession()
        }
    }

    private func processRating(_ rating: FSRSRating) {
        guard let word = currentWord else { return }
        
        if word.state == .new { DailyNewWords.recordIntroduced() }
        fsrs.calculateNextReview(word: word, rating: rating)
        
        if rating == .again {
            word.isMistake = true
        } else if rating == .good || rating == .easy {
            word.isMistake = false
        }
        
        reviewedCount += 1
        approachAnswered += 1
        if rating != .again { approachCorrect += 1 }
        counts = WordCounts(studyWords, newWordsAllowance: newWordsAllowance)
        profiles.first?.recordAnswer(.flashcards, translationMode: translationMode, isCorrect: rating != .again)
        if rating != .again { DailyStudy.recordCorrect(word) }
        
        isAnswerRevealed = false
        if currentIndex + 1 >= sessionWords.count {
            finishApproach()
        } else {
            currentIndex += 1
        }
    }
}

// MARK: - Компонент кнопок FSRS
struct FSRSActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 13, weight: .bold, design: .rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(12)
        }
    }
}
