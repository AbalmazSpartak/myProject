import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var selectedCategory: Category?

    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let brandDarkColor = Color.brandDark
    private let brandBgColor = Color.brandBackground
    
    private var isAnswerEmpty: Bool {
        userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isTextFieldFocused = false
                        DispatchQueue.main.async { dismiss() } // Изменено
                    }) {
                        HStack(spacing: 5) { Image(systemName: "chevron.left"); Text("В меню") }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
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
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 24).padding(.top, 10)
            
            HStack {
                Spacer()
                Text("Прогресс: \(correctCount)/\(totalAnswered)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24).padding(.top, 12)
            
            Spacer()
            
            if sessionWords.isEmpty {
                Text(selectedCategory == nil ? "В словаре нет слов для тренировки." : "В этой категории нет слов.")
                    .font(.system(.body, design: .rounded)).foregroundColor(.gray).padding(.horizontal, 40)
            } else {
                // Карточка со словом
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        Text(sessionWords[currentIndex].english).font(.system(size: 38, weight: .bold, design: .rounded)).foregroundColor(brandDarkColor)
                        Button(action: speakWord) { Image(systemName: "speaker.wave.2.bubble.fill").font(.title2).foregroundColor(.blue) }
                    }
                    .padding(.top, 30)
                    
                    if !sessionWords[currentIndex].transcription.isEmpty {
                        Text(sessionWords[currentIndex].transcription).font(.system(size: 18, weight: .medium, design: .rounded)).foregroundColor(.orange).padding(.top, 6)
                    }
                    
                    if !sessionWords[currentIndex].example.isEmpty {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Пример использования:").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.blue)
                            Text(sessionWords[currentIndex].example).font(.system(size: 15, weight: .medium, design: .rounded)).italic().foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                    }
                    
                    TextField(isTextFieldFocused ? "" : "Введите перевод на русский", text: $userAnswer)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(brandDarkColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, 24).padding(.top, 25)
                        .autocapitalization(.none).disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                        .submitLabel(showResult ? .next : .done)
                        .onSubmit {
                            if !showResult { if !isAnswerEmpty { checkAnswer() } } else { nextWord() }
                        }
                    
                    ZStack {
                        if showResult {
                            if isCorrect {
                                Text("🎉 Правильно!").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.green)
                            } else {
                                VStack(spacing: 2) {
                                    Text("❌ Ошибка").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.red)
                                    Text("Правильный ответ: \(sessionWords[currentIndex].russian)").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .frame(height: 65).padding(.top, 10)
                    
                    Group {
                        if !showResult {
                            Button(action: checkAnswer) {
                                Text("Проверить")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(isAnswerEmpty ? Color.black.opacity(0.06) : Color.blue)
                                    .foregroundColor(isAnswerEmpty ? .gray : .white)
                                    .cornerRadius(16)
                            }
                            .disabled(isAnswerEmpty)
                        } else {
                            Button(action: nextWord) {
                                Text("Следующее слово")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.green).foregroundColor(.white).cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity).background(Color.cardBackground).cornerRadius(24).shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8).padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.vertical).background(brandBgColor.ignoresSafeArea())
        .onAppear { generateSession(); isTextFieldFocused = true }
    }
    
    private func changeCategory(to category: Category?) {
        selectedCategory = category
        correctCount = 0
        totalAnswered = 0
        userAnswer = ""
        showResult = false
        generateSession()
        isTextFieldFocused = true
    }
    
    private func generateSession() {
        do {
            var descriptor = FetchDescriptor<Word>()
            
            // Фильтрация по категории, если она выбрана
            if let catID = selectedCategory?.id {
                descriptor.predicate = #Predicate<Word> { $0.category?.id == catID }
            }
            
            let totalCount = (try? modelContext.fetchCount(descriptor)) ?? 0
            guard totalCount > 0 else { sessionWords = []; return }
            
            let limit = 30
            if totalCount <= limit {
                sessionWords = (try modelContext.fetch(descriptor)).shuffled()
            } else {
                let maxOffset = totalCount - limit
                descriptor.fetchOffset = Int.random(in: 0...maxOffset)
                descriptor.fetchLimit = limit
                sessionWords = (try modelContext.fetch(descriptor)).shuffled()
            }
            currentIndex = 0
        } catch { sessionWords = [] }
    }
    
    func speakWord() {
        guard !sessionWords.isEmpty else { return }
        TextToSpeechManager.shared.speak(sessionWords[currentIndex].english)
    }
    
    func checkAnswer() {
        let cleanUser = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let correctVariants = sessionWords[currentIndex].russian
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        isCorrect = correctVariants.contains(cleanUser)
        if isCorrect { correctCount += 1 }
        totalAnswered += 1
        withAnimation { showResult = true }
        isTextFieldFocused = true
    }
    
    func nextWord() {
        userAnswer = ""; showResult = false
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count { generateSession() } else { currentIndex += 1 }
        }
        isTextFieldFocused = true
    }
}
