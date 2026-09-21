import SwiftUI
import SwiftData
import AVFoundation

struct FlashcardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var currentScreen: String

    @State private var sessionWords: [Word] = []
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @FocusState private var isTextFieldFocused: Bool
    
    
    // Брендовые цвета нового светлого дизайна
    private let brandDarkColor = Color(red: 26/255, green: 37/255, blue: 68/255)
    private let brandBgColor = Color(red: 247/255, green: 249/255, blue: 253/255)
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель навигации
            HStack {
                Button(action: {
                    isTextFieldFocused = false
                    DispatchQueue.main.async { currentScreen = "menu" }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                }
                Spacer()
                Text("Прогресс: \(correctCount)/\(totalAnswered)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            Spacer()
            
            if sessionWords.isEmpty {
                Text("В словаре нет слов для тренировки.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
            } else {
                // ПРЕМИАЛЬНАЯ ЦЕЛЬНАЯ БЕЛАЯ КАРТОЧКА
                VStack(spacing: 0) {
                    HStack(spacing: 15) {
                        Text(sessionWords[currentIndex].english)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(brandDarkColor)
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 30)
                    
                    if !sessionWords[currentIndex].transcription.isEmpty {
                        Text(sessionWords[currentIndex].transcription)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.top, 6)
                    }
                    
                    if !sessionWords[currentIndex].example.isEmpty {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Пример использования:")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                            Text(sessionWords[currentIndex].example)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .italic()
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                    }
                    
                    // Исправленное текстовое поле ввода перевода без системных рамок
                    TextField(isTextFieldFocused ? "" : "Введите перевод на русский", text: $userAnswer)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(brandDarkColor) // Темно-синий текст
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.white) // Всегда белый фон внутри инпута
                        .cornerRadius(12)
                        // Тонкая серая рамка-граница вокруг белого поля
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 25)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                        .submitLabel(showResult ? .next : .done)
                        .onSubmit {
                            if !showResult {
                                if !userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { checkAnswer() }
                            } else { nextWord() }
                        }
                    
                    // Блок результата фиксированной высоты
                    ZStack {
                        if showResult {
                            if isCorrect {
                                Text("🎉 Правильно!")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            } else {
                                VStack(spacing: 2) {
                                    Text("❌ Ошибка")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.red)
                                    Text("Правильный ответ: \(sessionWords[currentIndex].russian)")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .frame(height: 65)
                    .padding(.top, 10)
                    
                    // Контрастные кнопки управления под светлую тему
                    Group {
                        if !showResult {
                            Button(action: checkAnswer) {
                                Text("Проверить")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    // Кнопка стала контрастной (синей на белом фоне)
                                    .background(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.06) : Color.blue)
                                    .foregroundColor(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .white)
                                    .cornerRadius(16)
                            }
                            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        } else {
                            Button(action: nextWord) {
                                Text("Следующее слово")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
                .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.vertical)
        .background(brandBgColor.ignoresSafeArea())
        .onAppear {
            generateSession()
            isTextFieldFocused = true
        }
    }
    
    private func generateSession() {
        do {
            var descriptor = FetchDescriptor<Word>()
            let totalCount = (try? modelContext.fetchCount(descriptor)) ?? 0
            guard totalCount > 0 else {
                sessionWords = []
                return
            }
            
            let limit = 30
            if totalCount <= limit {
                sessionWords = (try modelContext.fetch(descriptor)).shuffled()
            } else {
                // Случайное смещение, чтобы брать разные 30 слов при каждом запуске
                let maxOffset = totalCount - limit
                descriptor.fetchOffset = Int.random(in: 0...maxOffset)
                descriptor.fetchLimit = limit
                sessionWords = (try modelContext.fetch(descriptor)).shuffled()
            }
            currentIndex = 0
        } catch {
            sessionWords = []
        }
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
        userAnswer = ""
        showResult = false
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count { generateSession() } else { currentIndex += 1 }
        }
        isTextFieldFocused = true
    }
}
