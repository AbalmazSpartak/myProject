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
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель навигации и прогресса
            HStack {
                Button(action: {
                    // Сначала принудительно гасим клавиатуру, затем переключаем экран
                    isTextFieldFocused = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        currentScreen = "menu"
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.headline)
                }
                Spacer()
                Text("Прогресс: \(correctCount)/\(totalAnswered)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .bold()
            }
            .padding(.horizontal)
            
            Spacer()
            
            if sessionWords.isEmpty {
                Text("В словаре нет слов для тренировки.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                // ЕДИНАЯ ЦЕЛЬНАЯ КАРТОЧКА С КОНТЕНТОМ
                VStack(spacing: 0) {
                    // Английское слово и озвучка
                    HStack(spacing: 15) {
                        Text(sessionWords[currentIndex].english)
                            .font(.system(size: 40, weight: .bold))
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 25)
                    
                    // Вывод транскрипции (если заполнена)
                    if !sessionWords[currentIndex].transcription.isEmpty {
                        Text(sessionWords[currentIndex].transcription)
                            .font(.title3)
                            .foregroundColor(.orange)
                            .padding(.top, 5)
                    }
                    
                    // Пример предложения (если заполнен)
                    if !sessionWords[currentIndex].example.isEmpty {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Пример использования:")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .bold()
                            
                            Text(sessionWords[currentIndex].example)
                                .font(.subheadline)
                                .italic()
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 15)
                        }
                        .padding(.top, 15)
                    }
                    
                    // Текстовое поле ввода перевода
                    TextField(isTextFieldFocused ? "" : "Введите перевод на русский", text: $userAnswer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isTextFieldFocused)
                        .submitLabel(showResult ? .next : .done)
                        .onSubmit {
                            if !showResult {
                                if !userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    checkAnswer()
                                }
                            } else {
                                nextWord()
                            }
                        }
                    
                    // Блок результата фиксированной высоты (защита от съезжания интерфейса)
                    ZStack {
                        if showResult {
                            if isCorrect {
                                Text("🎉 Правильно!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            } else {
                                VStack(spacing: 2) {
                                    Text("❌ Ошибка")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("Правильный ответ: \(sessionWords[currentIndex].russian)")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .frame(height: 65)
                    .padding(.top, 10)
                    
                    // Нижняя интерактивная кнопка управления
                    Group {
                        if !showResult {
                            Button(action: checkAnswer) {
                                Text("Проверить")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        } else {
                            Button(action: nextWord) {
                                Text("Следующее слово")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 25)
                }
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(20)
                .padding(.horizontal)
                .onTapGesture { }
            }
            
            Spacer()
        }
        .padding(.vertical)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
        )
        .onAppear {
            generateSession()
            isTextFieldFocused = true
        }
    }
    
    private func generateSession() {
        do {
            let descriptor = FetchDescriptor<Word>()
            let allAvailableWords = try modelContext.fetch(descriptor)
            
            guard !allAvailableWords.isEmpty else {
                sessionWords = []
                return
            }
            
            sessionWords = Array(allAvailableWords.shuffled().prefix(30))
            currentIndex = 0
        } catch {
            print("Ошибка ленивой выборки сессии: \(error.localizedDescription)")
            sessionWords = []
        }
    }
    
    func speakWord() {
        guard !sessionWords.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: sessionWords[currentIndex].english)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }
    
    func checkAnswer() {
        let cleanUser = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let correctVariants = sessionWords[currentIndex].russian
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        isCorrect = correctVariants.contains(cleanUser)
        
        if isCorrect { correctCount += 1 }
        totalAnswered += 1
        withAnimation(.easeInOut(duration: 0.15)) {
            showResult = true
        }
        isTextFieldFocused = true
    }
    
    func nextWord() {
        userAnswer = ""
        showResult = false
        
        if !sessionWords.isEmpty {
            if currentIndex + 1 >= sessionWords.count {
                generateSession()
            } else {
                currentIndex += 1
            }
        } else {
            currentIndex = 0
        }
        
        isTextFieldFocused = true
    }
}
