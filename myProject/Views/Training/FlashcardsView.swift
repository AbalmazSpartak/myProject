import SwiftUI
import SwiftData

enum FlashcardsFilter: Equatable {
    case due           // Только слова, готовые к повторению по FSRS
    case all           // Все слова подряд
    case category(Category)
    case mistakes      // Ошибки
    case level(CEFRLevel)   // новая строка
}

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
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: FlashcardsFilter = .due
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    
    @State private var reviewedCount = 0
    @State private var showHelp = false
    private let fsrs = FSRSCalculator()
    
    private func countWords(for category: Category) -> Int {
        let catID = category.id
        return studyWords.filter { $0.category?.id == catID }.count
    }
    
    private var mistakeWordsCount: Int {
        studyWords.filter { $0.isMistake }.count
    }
    
    private var dueWordsCount: Int {
        let now = Date()
        return studyWords.filter { $0.state == .new || $0.dueDate <= now }.count
    }
    
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
    
    private var filterTitle: String {
        switch currentFilter {
        case .due: return "⏰ На повторение (\(dueWordsCount))"
        case .all: return "Все слова"
        case .category(let cat): return cat.name
        case .mistakes: return "⚠️ Ошибки (\(mistakeWordsCount))"
        case .level(let level): return "Уровень \(level.rawValue)"
        
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                }
                
                Spacer()

                Button(action: { showHelp = true }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 8)

                Menu {
                    Button("⏰ На повторение (FSRS)") { changeFilter(to: .due) }
                    
                    Button("Все слова") { changeFilter(to: .all) }
                    
                    Button("⚠️ Работа над ошибками (\(mistakeWordsCount))") {
                        changeFilter(to: .mistakes)
                    }
                    .disabled(mistakeWordsCount == 0)
                    
                    Divider()
                    
                    ForEach(categories) { category in
                        Button("\(category.name) (\(countWords(for: category)))") { changeFilter(to: .category(category)) }
                    }
                    // ↓ новый блок
                    Divider()
                    
                    ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                        Button("Уровень \(level.rawValue) (\(countWords(level: level)))") {
                            changeFilter(to: .level(level))
                        }
                        .disabled(countWords(level: level) == 0)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: currentFilter == .mistakes ? "exclamationmark.triangle.fill" : "clock.badge.checkmark.fill")
                        Text(filterTitle)
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(currentFilter == .mistakes ? .orange : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((currentFilter == .mistakes ? Color.orange : Color.blue).opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            HStack {
                Spacer()
                Text("Повторено: \(reviewedCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            Spacer()
            
            if sessionWords.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text(currentFilter == .due ? "Отлично! Все запланированные слова повторены!" : "В выбранном разделе нет слов.")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else if let word = currentWord {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Text(currentQuestion)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
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
                                .font(.system(size: 16, weight: .medium, design: .rounded))
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
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 8) {
                                Text("Как сложно было вспомнить?")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
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
                                .font(.system(size: 16, weight: .bold, design: .rounded))
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
        .onAppear {
            loadWords()
            generateSession()
        }
        // Картинка грузится заранее, пока пользователь вспоминает перевод
        .task(id: currentWord?.persistentModelID) {
            guard showWordImages, let word = currentWord else { return }
            await WordImageLoader.loadIfNeeded(word)
        }
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                FlashcardsHelpView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Готово") { showHelp = false }
                                .fontWeight(.bold)
                        }
                    }
            }
        }
    }
    
    private func countWords(level: CEFRLevel) -> Int {
        studyWords.filter { $0.cefrLevel == level.rawValue }.count
    }
    
    private func changeFilter(to filter: FlashcardsFilter) {
        currentFilter = filter
        isAnswerRevealed = false
        generateSession()
    }
    
    private func loadWords() {
        allWords = modelContext.fetchAllWords()
        studyWords = allWords.filter { studyScope.includes($0) }
    }

    private func generateSession() {
        let now = Date()
        switch currentFilter {
        case .due:
            sessionWords = studyWords.filter { $0.state == .new || $0.dueDate <= now }
                .sorted { $0.dueDate < $1.dueDate }
        case .all:
            sessionWords = studyWords.shuffled()
        case .category(let cat):
            let catID = cat.id
            sessionWords = studyWords.filter { $0.category?.id == catID }.shuffled()
        case .mistakes:
            sessionWords = studyWords.filter { $0.isMistake }.shuffled()
        case .level(let level):
            sessionWords = studyWords.filter { $0.cefrLevel == level.rawValue }.shuffled()
        }
        currentIndex = 0
    }
    
    private func processRating(_ rating: FSRSRating) {
        guard let word = currentWord else { return }
        
        fsrs.calculateNextReview(word: word, rating: rating)
        
        if rating == .again {
            word.isMistake = true
        } else if rating == .good || rating == .easy {
            word.isMistake = false
        }
        
        reviewedCount += 1
        if let userProfile = profiles.first {
            if translationMode == "en_ru" {
                userProfile.flashcardsEnRuTotal += 1
                if rating != .again { userProfile.flashcardsEnRuCorrect += 1 }
            } else {
                userProfile.flashcardsRuEnTotal += 1
                if rating != .again { userProfile.flashcardsRuEnCorrect += 1 }
            }
        }
        
        isAnswerRevealed = false
        if currentIndex + 1 >= sessionWords.count {
            generateSession()
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
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(12)
        }
    }
}
