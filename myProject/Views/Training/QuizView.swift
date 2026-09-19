import SwiftUI
import SwiftData
import AVFoundation

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var currentScreen: String
    
    @State private var currentWord: Word?
    @State private var options: [String] = []
    @State private var selectedAnswer: String?
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @State private var hasMinimumWords = false
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // НАСТРОЙКА ЦВЕТА: Задаем базовый цвет для кнопок викторины
    private let baseButtonColor = Color.indigo
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель навигации и счета
            HStack {
                Button(action: { currentScreen = "menu" }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.headline)
                }
                Spacer()
                Text("Тест: \(correctCount)/\(totalAnswered)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .bold()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
            
            if !hasMinimumWords {
                Text("Для генерации тестов нужно минимум 3 слова с уникальными переводами в вашем словаре.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
            } else if let word = currentWord {
                // СТАБИЛЬНАЯ ЦЕЛЬНАЯ КАРТОЧКА ВИКТОРИНЫ
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        Text(word.english)
                            .font(.system(size: 40, weight: .bold))
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.blue) // Синий динамик для гармонии с индиго
                        }
                    }
                    .padding(.top, 25)
                    
                    if !word.transcription.isEmpty {
                        Text(word.transcription)
                            .font(.title3)
                            .foregroundColor(.orange)
                            .padding(.top, -10)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            Button(action: { checkAnswer(option) }) {
                                Text(option)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(buttonColor(for: option))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(selectedAnswer != nil)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 25)
                }
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(20)
                .padding(.horizontal)
                
                // КНОПКА ПРОДОЛЖИТЬ (За пределами серой карточки)
                VStack {
                    if selectedAnswer != nil {
                        Button(action: {
                            generateQuestion()
                        }) {
                            Text("Продолжить")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(baseButtonColor) // Использует базовый цвет
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .frame(height: 55)
                .padding(.top, 25)
            }
            
            Spacer()
        }
        .padding(.vertical)
        .onAppear {
            checkDatabaseAndStart()
        }
    }
    
    private func checkDatabaseAndStart() {
        do {
            let descriptor = FetchDescriptor<Word>()
            let allWords = try modelContext.fetch(descriptor)
            let uniqueTranslations = Set(allWords.map { $0.russian.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            
            if allWords.count >= 3 && uniqueTranslations.count >= 3 {
                hasMinimumWords = true
                generateQuestion()
            } else {
                hasMinimumWords = false
            }
        } catch {
            hasMinimumWords = false
        }
    }
    
    func generateQuestion() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedAnswer = nil
        }
        
        do {
            let descriptor = FetchDescriptor<Word>()
            let allWords = try modelContext.fetch(descriptor)
            
            guard allWords.count >= 3 else { return }
            
            if let randomMainWord = allWords.randomElement() {
                currentWord = randomMainWord
                
                var answers = [randomMainWord.russian]
                
                let alternativeTranslations = Array(Set(allWords
                    .filter { $0.id != randomMainWord.id && $0.russian.lowercased() != randomMainWord.russian.lowercased() }
                    .map { $0.russian }))
                
                let wrongAnswers = alternativeTranslations.shuffled().prefix(2)
                answers.append(contentsOf: wrongAnswers)
                
                while answers.count < 3 {
                    answers.append("—")
                }
                
                options = answers.shuffled()
            }
        } catch {
            print("Ошибка генерации викторины: \(error.localizedDescription)")
        }
    }
    
    func speakWord() {
        guard let word = currentWord else { return }
        let utterance = AVSpeechUtterance(string: word.english)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(utterance)
    }
    
    func checkAnswer(_ option: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedAnswer = option
        }
        totalAnswered += 1
        if option == currentWord?.russian {
            correctCount += 1
        }
    }
    
    func buttonColor(for option: String) -> Color {
        guard let selected = selectedAnswer else { return baseButtonColor }
        if option == currentWord?.russian { return .green }
        if option == selected { return .red }
        return baseButtonColor.opacity(0.4)
    }
}
