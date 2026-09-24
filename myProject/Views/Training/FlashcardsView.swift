import SwiftUI
import SwiftData

enum FlashcardsFilter: Equatable {
    case all
    case category(Category)
    case mistakes
}

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allWords: [Word]
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: FlashcardsFilter = .all
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private var mistakeWordsCount: Int {
        allWords.filter { $0.isMistake }.count
    }
    
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
    
    private var filterTitle: String {
        switch currentFilter {
        case .all: return "Все слова"
        case .category(let cat): return cat.name
        case .mistakes: return "⚠️ Ошибки (\(mistakeWordsCount))"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Шапка
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
                
                // Меню выбора фильтра
                Menu {
                    Button("Все слова") { changeFilter(to: .all) }
                    
                    Button("⚠️ Работа над ошибками (\(mistakeWordsCount))") {
                        changeFilter(to: .mistakes)
                    }
                    .disabled(mistakeWordsCount == 0)
                    
                    Divider()
                    
                    ForEach(categories) { category in
                        Button(category.name) { changeFilter(to: .category(category)) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: currentFilter == .mistakes ? "exclamationmark.triangle.fill" : "folder.fill")
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
            
            // Прогресс
            HStack {
                Spacer()
                Text("Прогресс: \(correctCount)/\(totalAnswered)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            Spacer()
            
            if sessionWords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: currentFilter == .mistakes ? "checkmark.circle.fill" : "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(currentFilter == .mistakes ? .green : .gray)
                    
                    Text(currentFilter == .mistakes ? "Отлично! У вас нет неисправленных ошибок." : "В выбранном разделе нет слов.")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            } else if let word = currentWord {
                // Карточка
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Text(currentQuestion)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.brandDark)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { TextToSpeechManager.shared.speak(word.english) }) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 24)
                    
                    if translationMode == "en_ru" && !word.transcription.isEmpty {
                        Text(word.transcription)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    // Ввод ответа
                    TextField("Введите перевод...", text: $userAnswer)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .padding()
                        .background(Color.brandInputBg)
                        .cornerRadius(12)
                        .focused($isTextFieldFocused)
                        .disabled(showResult)
                        .onSubmit {
                            if showResult {
                                nextWord()
                            } else {
                                checkAnswer()
                            }
                        }
                        .padding(.horizontal, 16)
                    
                    // Результат
                    if showResult {
                        VStack(spacing: 6) {
                            Text(isCorrect ? "🎉 Правильно!" : "❌ Неверно (добавлено в ошибки)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(isCorrect ? .green : .red)
                            
                            if !isCorrect {
                                Text("Правильно: \(currentCorrectAnswerString)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.brandDark)
                            }
                        }
                    }
                    
                    // Кнопка
                    Button(action: {
                        if showResult {
                            nextWord()
                        } else {
                            checkAnswer()
                        }
                    }) {
                        Text(showResult ? "Следующее слово" : "Проверить")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(showResult ? Color.blue : Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            generateSession()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isTextFieldFocused = true
            }
        }
        .onChange(of: showResult) { oldValue, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private func changeFilter(to filter: FlashcardsFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        userAnswer = ""
        showResult = false
        generateSession()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
    
    private func generateSession() {
        switch currentFilter {
        case .all:
            sessionWords = allWords.shuffled()
        case .category(let cat):
            let catID = cat.id
            sessionWords = allWords.filter { $0.category?.id == catID }.shuffled()
        case .mistakes:
            sessionWords = allWords.filter { $0.isMistake }.shuffled()
        }
        currentIndex = 0
    }
    
    func checkAnswer() {
        guard let word = currentWord else { return }
        let cleanUser = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let correctVariants = currentCorrectAnswerString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        isCorrect = correctVariants.contains(cleanUser)
        
        if isCorrect {
            correctCount += 1
            word.isMistake = false
        } else {
            word.isMistake = true
        }
        totalAnswered += 1
        
        if let userProfile = profiles.first {
            if translationMode == "en_ru" {
                userProfile.flashcardsEnRuTotal += 1
                if isCorrect { userProfile.flashcardsEnRuCorrect += 1 }
            } else {
                userProfile.flashcardsRuEnTotal += 1
                if isCorrect { userProfile.flashcardsRuEnCorrect += 1 }
            }
        }
        
        withAnimation { showResult = true }
        isTextFieldFocused = true
    }
    
    private func nextWord() {
        userAnswer = ""
        showResult = false
        
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                generateSession()
            } else {
                currentIndex += 1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTextFieldFocused = true
        }
    }
}
