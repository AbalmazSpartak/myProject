import SwiftUI
import SwiftData
import AVFoundation

struct QuizView: View {
    @Query private var words: [Word]
    @Binding var currentScreen: String
    
    @State private var isAlreadySpoken = false
    @State private var currentWord: Word?
    @State private var options: [String] = []
    @State private var selectedAnswer: String?
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        VStack(spacing: 25) {
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
            
            Text("Викторина")
                .font(.largeTitle)
                .bold()
            
            Spacer()
            
            if words.count < 3 {
                Text("Для генерации теста нужно минимум 3 слова в вашем словаре.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
            } else if let word = currentWord {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        Text(word.english)
                            .font(.system(size: 40, weight: .bold))
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.bottom, 10)
                    
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(20)
                .padding(.horizontal)
                
                if selectedAnswer != nil {
                    Button("Продолжить") {
                        generateQuestion()
                    }
                    .font(.headline)
                    .foregroundColor(.purple)
                    .padding(.top)
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            if !isAlreadySpoken {
                generateQuestion()
                isAlreadySpoken = true
            }
        }
    }
    
    func generateQuestion() {
        guard words.count >= 3 else { return }
        selectedAnswer = nil
        isAlreadySpoken = false // Сбрасываем для нового вопроса

        let shuffled = words.shuffled()
        currentWord = shuffled.first

        var answers = [currentWord!.russian]
        let wrongs = shuffled.dropFirst().map { $0.russian }.prefix(2)
        answers.append(contentsOf: wrongs)

        options = answers.shuffled()
        speakWord()
    }

    
    func speakWord() {
        guard let word = currentWord else { return }
        let utterance = AVSpeechUtterance(string: word.english)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        synthesizer.speak(utterance)
    }
    
    func checkAnswer(_ option: String) {
        selectedAnswer = option
        totalAnswered += 1
        if option == currentWord?.russian {
            correctCount += 1
        }
    }
    
    func buttonColor(for option: String) -> Color {
        guard let selected = selectedAnswer else { return .purple }
        if option == currentWord?.russian { return .green }
        if option == selected { return .red }
        return .purple.opacity(0.4)
    }
}
