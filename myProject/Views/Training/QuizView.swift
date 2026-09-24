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
    
    private let brandDarkColor = Color.brandDark
    private let brandBgColor = Color.brandBackground
    
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
    
    private var currentCorrectAnswer: String {
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
                
                // Выбор категории / Ошибок
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
                    .foregroundColor(currentFilter == .mistakes ? .orange : .purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((currentFilter == .mistakes ? Color.orange : Color.purple).opacity(0.1))
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
                                Text("❌ Неверно (добавлено в ошибки)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(height: 44)
                    .padding(.top, 8)
                    
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
    
    private func changeFilter(to filter: QuizFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        selectedOption = nil
        showResult = false
        generateSession()
    }
    
    private func generateSession() {
        do {
            var descriptor = FetchDescriptor<Word>()
            switch currentFilter {
            case .all:
                break
            case .category(let cat):
                let catID = cat.id
                descriptor.predicate = #Predicate<Word> { $0.category?.id == catID }
            case .mistakes:
                descriptor.predicate = #Predicate<Word> { $0.isMistake == true }
            }
            
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
        
        let otherWords = allWords.filter { $0.id != word.id }
        let wrongCandidates = Array(Set(otherWords.map { translationMode == "en_ru" ? $0.russian : $0.english }))
            .filter { $0 != correct }
            .shuffled()
        
        var choices = Array(wrongCandidates.prefix(3))
        choices.append(correct)
        options = choices.shuffled()
    }
    
    private func selectOption(_ option: String) {
        guard !showResult, let word = currentWord else { return }
        selectedOption = option
        isCorrect = (option == currentCorrectAnswer)
        
        if isCorrect {
            correctCount += 1
            // Если отвечено верно, снимаем флаг ошибки
            word.isMistake = false
        } else {
            // Если ошибка — заносим в слова-ошибки
            word.isMistake = true
        }
        totalAnswered += 1
        
        // Запись в статистику
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
