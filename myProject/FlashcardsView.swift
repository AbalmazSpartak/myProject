import SwiftUI
import SwiftData
import AVFoundation

struct FlashcardsView: View {
    @Query private var words: [Word] // Запрашиваем слова из базы
    @Binding var currentScreen: String
    @State private var isAlreadySpoken = false // Защита от двойного старта

    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    
    // Статистика сессии
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 20) {
            // Панель навигации
            HStack {
                Button(action: { currentScreen = "menu" }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.headline)
                }
                Spacer()
                // Счетчик прогресса сессии
                Text("Прогресс: \(correctCount)/\(totalAnswered)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .bold()
            }
            .padding(.horizontal)
            
            Text("Изучение слов")
                .font(.largeTitle)
                .bold()
            
            Spacer()
            
            if words.isEmpty {
                Text("Добавьте слова в словаре")
                    .foregroundColor(.gray)
            } else {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        Text(words[currentIndex].english)
                            .font(.system(size: 40, weight: .bold))
                        
                        // Кнопка ручной озвучки
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 10)
                    
                    TextField("Введите перевод на русский", text: $userAnswer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(showResult)
                    
                    if showResult {
                        if isCorrect {
                            Text("🎉 Правильно!")
                                .font(.headline)
                                .foregroundColor(.green)
                        } else {
                            VStack(spacing: 5) {
                                Text("❌ Ошибка")
                                  .font(.headline)
                                  .foregroundColor(.red)
                                Text("Правильный ответ: \(words[currentIndex].russian)")
                                  .font(.subheadline)
                                  .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(20)
                .padding(.horizontal)
            }
            
            Spacer()
            
            if !words.isEmpty {
                if !showResult {
                    Button(action: checkAnswer) {
                        Text("Проверить")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 40)
                } else {
                    Button(action: nextWord) {
                        Text("Следующее слово")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
        .padding()
        
        .onAppear {
            if !isAlreadySpoken {
                speakWord()
                isAlreadySpoken = true
            }
        }

    }
    
    func speakWord() {
        guard !words.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: words[currentIndex].english)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }
    
    func checkAnswer() {
        let cleanUser = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCorrect = words[currentIndex].russian.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        isCorrect = (cleanUser == cleanCorrect)
        if isCorrect { correctCount += 1 }
        totalAnswered += 1
        showResult = true
    }
    
    func nextWord() {
        userAnswer = ""
        showResult = false
        isAlreadySpoken = false // 1. Сбрасываем флаг, чтобы новое слово могло озвучиться
        
        // 2. Безопасно переключаем индекс (защита от вылета, если удалили слова в словаре)
        if !words.isEmpty {
            currentIndex = (currentIndex + 1) % words.count
        } else {
            currentIndex = 0
        }
        
        speakWord() // 3. Озвучиваем следующее слово
    }

}
