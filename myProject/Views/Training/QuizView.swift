import SwiftUI
import SwiftData

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Считываем направление перевода из настроек
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allWords: [Word]
    @Query private var profiles: [UserProfile]
    
    @State private var selectedCategory: Category?
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var options: [String] = []
    @State private var selectedOption: String? = nil
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    
    private let brandDarkColor = Color.brandDark
    private let brandBgColor = Color.brandBackground
    
    // Текущее слово сессии
    private var currentWord: Word? {
        guard !sessionWords.isEmpty, currentIndex < sessionWords.count else { return nil }
        return sessionWords[currentIndex]
    }
    
    // Вопрос в зависимости от режима перевода
    private var currentQuestion: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.english : word.russian
    }
    
    // Правильный ответ в зависимости от режима перевода
    private var currentCorrectAnswer: String {
        guard let word = currentWord else { return "" }
        return translationMode == "en_ru" ? word.russian : word.english
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.purple)
                }
                
                Spacer()
                
                // Выбор категории
                Menu {
                    Button("Все слова") { changeCategory(to: nil) }
                    Divider()
                    ForEach(categories) { category in
                        Button(category.name) { changeCategory(to: category) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                        Text(selectedCategory?.name ?? "Все слова")
                            .lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            // Прогресс текущей сессии
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
                Text(selectedCategory == nil ? "В словаре нет слов для викторины." : "В этой категории нет слов.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
            } else if let _ = currentWord {
                // Карточка викторины
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text(currentQuestion)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(brandDarkColor)
                            .multilineTextAlignment(.center)
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.top, 28)
                    .padding(.horizontal, 16)
                    
                    // Варианты ответов
                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            Button(action: { selectOption(option) }) {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(optionTextColor(for: option))
                                    Spacer()
                                    if showResult {
                                        if option == currentCorrectAnswer {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        } else if option == selectedOption {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                                .background(optionBackgroundColor(for: option))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(optionBorderColor(for: option), lineWidth: 1.5)
                                )
                            }
                            .disabled(showResult)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Сообщение о результате
                    ZStack {
                        if showResult {
                            if isCorrect {
                                Text("🎉 Отлично!")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            } else {
                                Text("❌ Неверно")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(height: 44)
                    .padding(.top, 8)
                    
                    // Кнопка перехода к следующему вопросу
                    if showResult {
                        Button(action: nextWord) {
                            Text("Следующий вопрос")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    } else {
                        Spacer().frame(height: 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .background(brandBgColor.ignoresSafeArea())
        .onAppear {
            generateSession()
        }
    }
    
    // --- Цвета вариантов ответов при проверке ---
    
    private func optionTextColor(for option: String) -> Color {
        if !showResult { return .brandDark }
        if option == currentCorrectAnswer { return .green }
        if option == selectedOption { return .red }
        return .gray
    }
    
    private func optionBackgroundColor(for option: String) -> Color {
        if !showResult { return Color.brandBackground.opacity(0.5) }
        if option == currentCorrectAnswer { return Color.green.opacity(0.12) }
        if option == selectedOption { return Color.red.opacity(0.12) }
        return Color.brandBackground.opacity(0.3)
    }
    
    private func optionBorderColor(for option: String) -> Color {
        if !showResult { return Color.black.opacity(0.06) }
        if option == currentCorrectAnswer { return Color.green }
        if option == selectedOption { return Color.red }
        return Color.clear
    }
    
    // --- Вспомогательная логика ---
    
    private func changeCategory(to category: Category?) {
        selectedCategory = category
        correctCount = 0
        totalAnswered = 0
        selectedOption = nil
        showResult = false
        generateSession()
    }
    
    private func generateSession() {
        do {
            var descriptor = FetchDescriptor<Word>()
            if let catID = selectedCategory?.id {
                descriptor.predicate = #Predicate<Word> { $0.category?.id == catID }
            }
            let totalCount = (try? modelContext.fetchCount(descriptor)) ?? 0
            guard totalCount > 0 else { sessionWords = []; return }
            
            sessionWords = (try modelContext.fetch(descriptor)).shuffled()
            currentIndex = 0
            prepareOptions()
        } catch {
            sessionWords = []
        }
    }
    
    private func prepareOptions() {
        guard let word = currentWord else { return }
        let correct = currentCorrectAnswer
        
        // Берем случайные варианты из общей базы слов на целевом языке
        let otherWords = allWords.filter { $0.id != word.id }
        let wrongCandidates = Array(Set(otherWords.map { translationMode == "en_ru" ? $0.russian : $0.english }))
            .filter { $0 != correct }
            .shuffled()
        
        var choices = Array(wrongCandidates.prefix(3))
        choices.append(correct)
        options = choices.shuffled()
    }
    
    private func selectOption(_ option: String) {
        guard !showResult else { return }
        selectedOption = option
        isCorrect = (option == currentCorrectAnswer)
        
        if isCorrect { correctCount += 1 }
        totalAnswered += 1
        
        // Детализированная запись в профиль
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
    
    private func nextWord() {
        selectedOption = nil
        showResult = false
        
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                generateSession()
            } else {
                currentIndex += 1
                prepareOptions()
            }
        }
    }
    
    private func speakWord() {
        guard let word = currentWord else { return }
        TextToSpeechManager.shared.speak(word.english)
    }
}
