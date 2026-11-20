import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    @AppStorage("show_word_images") private var showWordImages: Bool = true

    @Query(sort: \Category.name) private var categories: [Category]
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    /// Счётчики для меню фильтров — пересчитываются после загрузки и ответа
    @State private var counts = WordCounts()
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: TrainingFilter

    /// filter — с чего начать: «На повторение» или, например, слова из книги
    init(filter: TrainingFilter = .due) {
        _currentFilter = State(initialValue: filter)
    }
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    /// Другие значения того же написания — глагол тогда показывается с to
    @State private var homographs: [Word] = []
    
    @State private var reviewedCount = 0
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    /// Подход окончен — показываем итог вместо следующего слова
    @State private var isApproachFinished = false
    @State private var approachAnswered = 0
    @State private var approachCorrect = 0
    /// Сколько ответов каждой оценки в этом подходе и какие слова вернутся позже
    @State private var ratingCounts: [FSRSRating: Int] = [:]
    @State private var returnLater: [Word] = []
    @AppStorage(DailyNewWords.limitKey) private var newWordsPerDay = DailyNewWords.defaultLimit
    private let fsrs = FSRSCalculator()
    
    private var currentWord: Word? {
        guard !sessionWords.isEmpty, currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    private var currentQuestion: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.prompt(ambiguous: !homographs.isEmpty) : word.russian
    }
    
    private var currentAnswer: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.russian : word.english
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TrainingFilterMenu(
                    current: currentFilter,
                    counts: counts,
                    categories: categories,
                    includesDue: true,
                    icon: "clock.badge.checkmark.fill",
                    tint: Color.brandTint,
                    usesChipStyle: true,
                    onSelect: changeFilter
                )

                Spacer()

                HelpButton(topic: .flashcards)

                LXTextButton(title: "Закончить", isMuted: true) { dismiss() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .frame(minHeight: 52)

            if isApproachFinished {
                FlashcardsSummary(
                    counts: ratingCounts,
                    total: approachAnswered,
                    returnLater: returnLater,
                    onContinue: { withAnimation { generateSession() } },
                    onExit: { dismiss() }
                )
                .transition(.opacity)
            } else if sessionWords.isEmpty {
                Spacer()
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle")
                        .scaledFont(size: 56)
                        .foregroundStyle(Color.statusKnown)

                    Text(currentFilter == .due ? "Все запланированные слова повторены" : "В выбранном разделе нет слов")
                        .scaledFont(size: 26, weight: .medium, design: .serif)
                        .foregroundStyle(Color.brandDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                Spacer()
            } else if let word = currentWord {
                card(for: word)
                    .padding(.horizontal, 16)

                bottomControls
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

    // MARK: - Карточка

    private func card(for word: Word) -> some View {
        VStack(spacing: 0) {
            if isAnswerRevealed {
                cardBack(word)
            } else {
                cardFront(word)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        .onChange(of: word.persistentModelID, initial: true) {
            homographs = Homographs.others(of: word, in: modelContext)
        }
    }

    /// Состояние слова слева и уровень справа
    private func cardHeader(_ word: Word) -> some View {
        HStack {
            let status = word.studyStatus
            Label(status.title, systemImage: status.symbol)
                .scaledFont(size: 13, weight: .medium)
                .foregroundStyle(status.color)
            Spacer()
            LevelBadge(level: word.cefrLevel)
        }
    }

    /// Лицо: слово, транскрипция, озвучка, пример
    private func cardFront(_ word: Word) -> some View {
        VStack(spacing: 0) {
            cardHeader(word)

            VStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(currentQuestion)
                    .scaledFont(size: 56, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                // Транскрипция и часть речи — одной строкой; без транскрипции — только часть речи
                HStack(spacing: 8) {
                    if translationMode == "en_ru" && !word.displayTranscription.isEmpty {
                        Text(word.displayTranscription)
                            .scaledFont(size: 17)
                            .foregroundStyle(Color.brandMuted)
                    }
                    PartOfSpeechBadge(word: word)
                }
                if translationMode == "en_ru" {
                    ExampleFormHint(word: word)
                }
                Button { TextToSpeechManager.shared.speak(word.english) } label: {
                    Image(systemName: "speaker.wave.2")
                        .scaledFont(size: 24)
                        .foregroundStyle(Color.brandOnSoft)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.brandAccent))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .accessibilityLabel("Озвучить слово")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            // В режиме «рус → англ» пример на английском выдал бы ответ
            if translationMode == "en_ru", !word.example.isEmpty {
                FlashcardExample(word: word)
            }
        }
    }

    /// Оборот: слово сверху, перевод крупно, картинка, пример
    private func cardBack(_ word: Word) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(word.english)
                    .scaledFont(size: 22, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                    .lineLimit(1)
                Button { TextToSpeechManager.shared.speak(word.english) } label: {
                    Image(systemName: "speaker.wave.2")
                        .scaledFont(size: 17)
                        .foregroundStyle(Color.brandDark)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Озвучить слово")
                Spacer()
                LevelBadge(level: word.cefrLevel)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(currentAnswer)
                        .scaledFont(size: 38, weight: .medium, design: .serif)
                        .foregroundStyle(Color.brandDark)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if showWordImages {
                        WordImageView(word: word)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: .infinity)

            if !word.example.isEmpty {
                FlashcardExample(word: word)
            }
        }
    }

    /// Под карточкой: «Показать перевод» или четыре оценки FSRS
    @ViewBuilder
    private var bottomControls: some View {
        if isAnswerRevealed {
            VStack(spacing: 8) {
                Text("Как сложно было вспомнить?")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(Color.brandMuted)
                HStack(spacing: 8) {
                    FlashcardRatingButton(rating: .again) { processRating(.again) }
                    FlashcardRatingButton(rating: .hard) { processRating(.hard) }
                    FlashcardRatingButton(rating: .good) { processRating(.good) }
                    FlashcardRatingButton(rating: .easy) { processRating(.easy) }
                }
            }
            .transition(.opacity)
        } else {
            LXButton(title: "Показать перевод") {
                withAnimation(.easeOut(duration: 0.2)) { isAnswerRevealed = true }
            }
        }
    }

    private func changeFilter(to filter: TrainingFilter) {
        currentFilter = filter
        isAnswerRevealed = false
        generateSession()
    }
    
    /// Счётчики для меню — запросами к базе: все слова не читаем (10 000+ — ~2 с на iPhone 12).
    /// «На повторение» — сразу, числа тем — порциями после показа первой карточки
    private func loadWords() {
        counts.refreshProgress(scope: studyScope, newWordsAllowance: newWordsAllowance, in: modelContext)
        Task {
            await StudyWords.warmCategoryCounts(scope: studyScope, categories: categories, in: modelContext)
            counts = WordCounts(scope: studyScope, categories: categories, newWordsAllowance: newWordsAllowance, in: modelContext)
        }
    }

    /// Сколько новых слов ещё можно начать сегодня; nil — без лимита
    private var newWordsAllowance: Int? {
        DailyNewWords.allowance(limit: newWordsPerDay)
    }

    private func generateSession() {
        sessionWords = StudyWords.session(currentFilter, scope: studyScope, newWordsAllowance: newWordsAllowance,
                                          length: sessionLength, in: modelContext)
        currentIndex = 0
        isApproachFinished = false
        approachAnswered = 0
        approachCorrect = 0
        ratingCounts = [:]
        returnLater = []
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
        
        let isReview = word.state != .new
        if !isReview { DailyNewWords.recordIntroduced() }
        fsrs.calculateNextReview(word: word, rating: rating)
        if rating == .again { DictionarySignals.recordHardIfNeeded(word) }
        // Повторили последнее слово к повторению — день идёт в серию и без нормы новых слов
        if isReview, StudyWords.count(StudyWords.all(StudyWords.scope(studyScope), StudyWords.isDue(now: Date())), in: modelContext) == 0 {
            DailyStreak.recordReviewsCleared()
        }
        
        if rating == .again {
            word.isMistake = true
        } else if rating == .good || rating == .easy {
            word.isMistake = false
        }
        
        reviewedCount += 1
        approachAnswered += 1
        if rating != .again { approachCorrect += 1 }
        ratingCounts[rating, default: 0] += 1
        if (rating == .again || rating == .hard), !returnLater.contains(where: { $0.persistentModelID == word.persistentModelID }) {
            returnLater.append(word)
        }
        counts.refreshProgress(scope: studyScope, newWordsAllowance: newWordsAllowance, in: modelContext)
        profiles.first?.recordAnswer(.flashcards, translationMode: translationMode, isCorrect: rating != .again)
        DailyStudy.record(word, rating: rating)
        
        isAnswerRevealed = false
        if currentIndex + 1 >= sessionWords.count {
            finishApproach()
        } else {
            currentIndex += 1
        }
    }
}
