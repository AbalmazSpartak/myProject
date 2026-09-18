import SwiftUI
import SwiftData
import AVFoundation

struct FlashcardsView: View {
    @Query private var words: [Word]
    @Binding var currentScreen: String

    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { currentScreen = "menu" }) {
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
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if !words[currentIndex].example.isEmpty {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Пример использования:")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .bold()
                            
                            Text(words[currentIndex].example)
                                .font(.subheadline)
                                .italic()
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 15)
                        }
                        .padding(.bottom, 10)
                    }
                    
                    TextField(isTextFieldFocused ? "" : "Введите перевод на русский", text: $userAnswer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(showResult)
                        .focused($isTextFieldFocused)
                    
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
                .padding(.vertical, 30)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(20)
                .padding(.horizontal)
                .onTapGesture { }
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
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                }
        )
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
        isTextFieldFocused = false
        
        let cleanUser = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCorrect = words[currentIndex].russian.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        isCorrect = (cleanUser == cleanCorrect)
        if isCorrect { correctCount += 1 }
        totalAnswered += 1
        withAnimation {
            showResult = true
        }
    }
    
    func nextWord() {
        userAnswer = ""
        showResult = false
        
        if !words.isEmpty {
            currentIndex = (currentIndex + 1) % words.count
        } else {
            currentIndex = 0
        }
    }
}
