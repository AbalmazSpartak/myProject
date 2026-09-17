import SwiftUI

struct FlashcardsView: View {
    @State private var currentIndex = 0
    @State private var userAnswer = ""
    @State private var showResult = false
    @State private var isCorrect = false
    
    private let words = sampleWords
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Изучение слов")
                .font(.largeTitle)
                .bold()
                .padding(.top)
            
            Spacer()
            
            // Карточка со словом и полем ввода
            VStack(spacing: 20) {
                Text(words[currentIndex].english)
                    .font(.system(size: 45, weight: .bold))
                    .padding(.bottom, 10)
                
                // Поле ввода перевода
                TextField("Введите перевод на русский", text: $userAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.center)
                    .font(.title3)
                    .padding(.horizontal, 20)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .disabled(showResult) // Блокируем поле после проверки
                
                // Отображение результата проверки
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
            
            Spacer()
            
            // Кнопка действия (Проверить / Следующее)
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
        .padding()
    }
    
    // Проверка ответа пользователя
    func checkAnswer() {
        let cleanUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCorrectAnswer = words[currentIndex].russian.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        isCorrect = (cleanUserAnswer == cleanCorrectAnswer)
        showResult = true
    }
    
    // Переход к следующему слову
    func nextWord() {
        userAnswer = ""
        showResult = false
        currentIndex = (currentIndex + 1) % words.count
    }
}

#Preview {
    FlashcardsView()
}
