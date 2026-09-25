import SwiftUI
import SwiftData

enum QuizFilter: Equatable {
    case all
    case category(Category)
    case mistakes
}

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allWords: [Word]
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: QuizFilter = .all
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var options: [String] = []
    
    @State private var selectedOption: String? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    
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
            // Верхняя панель управления
            HStack(alignment: .top) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("В меню")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.purple)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Выпадающее меню категорий
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
                        HStack(spacing: 6) {
                            Image(systemName: currentFilter == .mistakes ? "exclamationmark.triangle.fill" : "folder.fill")
                            Text(filterTitle)
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(currentFilter == .mistakes ? .orange : .purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            (currentFilter == .mistakes ? Color.orange : Color.indigo).opacity(0.12)
                        )
                        .cornerRadius(10)
                    }
                    
                    // Надпись "Тест: X/Y"
                    Text("Тест: \(correctCount)/\(totalAnswered)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
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
                // Карточка вопроса
                VStack(spacing: 16) {
                    // Слово + озвучка
                    HStack(spacing: 10) {
                        Text(currentQuestion)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Button(action: { TextToSpeechManager.shared.speak(word.english) }) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.top, 28)
                    
                    // Транскрипция
                    if translationMode == "en_ru" && !word.transcription.isEmpty {
                        Text(word.transcription)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    
                    // Варианты ответов (плашки)
                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            Button(action: { selectOption(option) }) {
                                Text(option)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 12)
                                    .background(optionBackgroundColor(option))
                                    .foregroundColor(optionForegroundColor(option))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(optionBorderColor(option), lineWidth: 1.5)
                                    )
                            }
                            .disabled(showResult)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    if showResult {
                        Button(action: nextWord) {
                            Text("Следующее слово")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
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
        .onAppear {
            generateSession()
        }
    }
    
    private func changeFilter(to filter: QuizFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        selectedOption = nil
        showResult = false
        generateSession()
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
        setupQuestion()
    }
    
    private func setupQuestion() {
        guard let word = currentWord else { return }
        selectedOption = nil
        showResult = false
        
        let correctAnswer = translationMode == "en_ru" ? word.russian : word.english
        
        var otherAnswers = allWords
            .map { translationMode == "en_ru" ? $0.russian : $0.english }
            .filter { $0.lowercased() != correctAnswer.lowercased() }
            .shuffled()
        
        var generatedOptions = [correctAnswer]
        while generatedOptions.count < 4 && !otherAnswers.isEmpty {
            let nextOption = otherAnswers.removeFirst()
            if !generatedOptions.contains(nextOption) {
                generatedOptions.append(nextOption)
            }
        }
        
        options = generatedOptions.shuffled()
    }
    
    private func selectOption(_ option: String) {
        guard let word = currentWord else { return }
        selectedOption = option
        
        // Точная проверка совпадения ответа без разбиения строки
        isCorrect = (option == currentCorrectAnswerString)
        
        if isCorrect {
            correctCount += 1
            word.isMistake = false
        } else {
            word.isMistake = true
        }
        totalAnswered += 1
        
        if let userProfile = profiles.first {
            if translationMode == "en_ru" {
                userProfile.quizEnRuTotal += 1
                if isCorrect { userProfile.quizEnRuCorrect += 1 }
            } else {
                userProfile.quizRuEnTotal += 1
                if isCorrect { userProfile.quizRuEnCorrect += 1 }
            }
        }
        
        withAnimation { showResult = true }
    }
    
    private func isOptionCorrect(_ option: String) -> Bool {
        return option == currentCorrectAnswerString
    }
    
    // Цвет фона плашек
    private func optionBackgroundColor(_ option: String) -> Color {
        guard showResult else {
            return colorScheme == .dark
                ? Color(white: 0.16)
                : Color(red: 0.94, green: 0.95, blue: 0.98)
        }
        if isOptionCorrect(option) {
            return Color.green.opacity(colorScheme == .dark ? 0.25 : 0.18)
        }
        if selectedOption == option {
            return Color.red.opacity(colorScheme == .dark ? 0.25 : 0.18)
        }
        return colorScheme == .dark ? Color(white: 0.12) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
    
    // Цвет текста плашек
    private func optionForegroundColor(_ option: String) -> Color {
        guard showResult else {
            return colorScheme == .dark
                ? .white
                : Color(red: 0.2, green: 0.25, blue: 0.45)
        }
        if isOptionCorrect(option) {
            return colorScheme == .dark ? Color(red: 0.4, green: 0.9, blue: 0.5) : .green
        }
        if selectedOption == option {
            return colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : .red
        }
        return .gray.opacity(0.6)
    }
    
    // Тонкая обводка плашек для объема
    private func optionBorderColor(_ option: String) -> Color {
        guard showResult else {
            return colorScheme == .dark
                ? Color.white.opacity(0.12)
                : Color.black.opacity(0.03)
        }
        if isOptionCorrect(option) {
            return .green.opacity(0.6)
        }
        if selectedOption == option {
            return .red.opacity(0.6)
        }
        return Color.clear
    }
    
    private func nextWord() {
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                generateSession()
            } else {
                currentIndex += 1
                setupQuestion()
            }
        }
    }
}
