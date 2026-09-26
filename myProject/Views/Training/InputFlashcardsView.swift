import SwiftUI
import SwiftData

enum InputFlashcardsFilter: Equatable {
    case all
    case category(Category)
    case mistakes
}

struct InputFlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query private var allWords: [Word]
    @Query private var profiles: [UserProfile]
    
    @State private var currentFilter: InputFlashcardsFilter = .all
    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    
    @State private var userInput = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    
    @FocusState private var isInputFocused: Bool
    
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
            // MARK: - Шапка управления
            HStack(alignment: .top) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("В меню")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.teal)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Выпадающее меню выбора категории
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
                        .foregroundColor(currentFilter == .mistakes ? .orange : .teal)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            (currentFilter == .mistakes ? Color.orange : Color.teal).opacity(0.12)
                        )
                        .cornerRadius(10)
                    }
                    
                    // Статистика сессии
                    Text("Ввод: \(correctCount)/\(totalAnswered)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Spacer()
            
            // MARK: - Контент карточки
            if sessionWords.isEmpty {
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
                    // Вопрос и озвучка
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Text(currentQuestion)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.brandDark)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { TextToSpeechManager.shared.speak(word.english) }) {
                                Image(systemName: "speaker.wave.2.bubble.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.teal)
                            }
                        }
                        
                        if translationMode == "en_ru" && !word.transcription.isEmpty {
                            Text(word.transcription)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 24)
                    
                    Divider()
                        .padding(.horizontal, 10)
                    
                    // Текстовое поле ввода
                    VStack(alignment: .leading, spacing: 8) {
                        Text(translationMode == "en_ru" ? "Введите перевод на русский:" : "Введите перевод на английский:")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                        
                        TextField("Ваш перевод...", text: $userInput)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
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
                    
                    // Результат ответа
                    if showResult {
                        VStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 22))
                                
                                Text(isCorrect ? "Правильно!" : "Неверно")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(isCorrect ? .green : .red)
                            
                            if !isCorrect {
                                VStack(spacing: 4) {
                                    Text("Правильный ответ:")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.gray)
                                    
                                    Text(currentCorrectAnswerString)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.brandDark)
                                }
                            }
                            
                            if !word.example.isEmpty {
                                Text("Пример: \(word.example)")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .italic()
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.vertical, 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Кнопки действия (Проверить / Далее)
                    VStack {
                        if !showResult {
                            Button(action: checkAnswer) {
                                Text("Проверить")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
        .onAppear {
            generateSession()
        }
    }
    
    // MARK: - Вычисление цвета границы поля ввода
    private var inputBorderColor: Color {
        guard showResult else {
            return isInputFocused ? Color.teal : Color.brandDark.opacity(0.15)
        }
        return isCorrect ? Color.green : Color.red
    }
    
    // MARK: - Переключение фильтров
    private func changeFilter(to filter: InputFlashcardsFilter) {
        currentFilter = filter
        correctCount = 0
        totalAnswered = 0
        showResult = false
        userInput = ""
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
        resetQuestion()
    }
    
    private func resetQuestion() {
        userInput = ""
        showResult = false
        isCorrect = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }
    
    // MARK: - Проверка ответа
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
        
        // Озвучиваем слово при завершении ответа
        TextToSpeechManager.shared.speak(word.english)
        
        // Обновляем статистику пользователя
        if let userProfile = profiles.first {
            if translationMode == "en_ru" {
                userProfile.flashcardsEnRuTotal += 1
                if isCorrect { userProfile.flashcardsEnRuCorrect += 1 }
            } else {
                userProfile.flashcardsRuEnTotal += 1
                if isCorrect { userProfile.flashcardsRuEnCorrect += 1 }
            }
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showResult = true
        }
    }
    
    // Сравнение текста (с поддержкой синонимов через запятую/слэш и замену 'ё' -> 'е')
    private func validateInput(_ input: String, target: String) -> Bool {
        let cleanedInput = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
        
        guard !cleanedInput.isEmpty else { return false }
        
        let separators = CharacterSet(charactersIn: ",;/")
        let targetVariants = target
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "ё", with: "е") }
            .filter { !$0.isEmpty }
        
        return targetVariants.contains(cleanedInput)
    }
    
    private func nextWord() {
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                generateSession()
            } else {
                currentIndex += 1
                resetQuestion()
            }
        }
    }
}
