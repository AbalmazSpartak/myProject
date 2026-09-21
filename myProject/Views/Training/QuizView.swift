import SwiftUI
import SwiftData
import AVFoundation
 
struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var currentScreen: String
    
    @State private var currentWord: Word?
    @State private var cachedWords: [Word] = []
    @State private var options: [String] = []
    @State private var selectedAnswer: String?
    @State private var correctCount = 0
    @State private var totalAnswered = 0
    @State private var hasMinimumWords = false
    

    
    // Брендовые цвета светлой темы викторины
    private let brandDarkColor = Color.brandDark
    private let brandBgColor = Color.brandBackground
    private let baseButtonColor = Color.indigo
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя навигационная панель
            HStack {
                Button(action: { currentScreen = "menu" }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("В меню")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.purple)
                }
                Spacer()
                Text("Тест: \(correctCount)/\(totalAnswered)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            
            Spacer()
            
            if !hasMinimumWords {
                Text("Для генерации тестов нужно минимум 3 слова с уникальными переводами.")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if let word = currentWord {
                // БЕЛАЯ НЕОМОРФНАЯ КАРТОЧКА ВИКТОРИНЫ
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        Text(word.english)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(brandDarkColor)
                        
                        Button(action: speakWord) {
                            Image(systemName: "speaker.wave.2.bubble.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.top, 30)
                    
                    if !word.transcription.isEmpty {
                        Text(word.transcription)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.top, -10)
                    }
                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            Button(action: { checkAnswer(option) }) {
                                Text(option)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(buttonColor(for: option))
                                    .foregroundColor(buttonTextColor(for: option))
                                    .cornerRadius(16)
                            }
                            .disabled(selectedAnswer != nil)
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
                
                // Кнопка продолжить (За пределами карточки)
                VStack {
                    if selectedAnswer != nil {
                        Button(action: { generateQuestion() }) {
                            Text("Продолжить")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .frame(height: 55)
                .padding(.top, 25)
            }
            Spacer()
        }
        .padding(.vertical)
        .background(brandBgColor.ignoresSafeArea())
        .onAppear { checkDatabaseAndStart() }
    }
    
    private func checkDatabaseAndStart() {
        do {
            let descriptor = FetchDescriptor<Word>()
            cachedWords = try modelContext.fetch(descriptor)
            
            let uniqueTranslations = Set(cachedWords.map {
                $0.russian.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            })
            
            if cachedWords.count >= 3 && uniqueTranslations.count >= 3 {
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
        selectedAnswer = nil
        guard cachedWords.count >= 3, let randomMainWord = cachedWords.randomElement() else { return }
        
        currentWord = randomMainWord
        var answers = [randomMainWord.russian]
        
        let alternativeTranslations = Array(Set(cachedWords
            .filter { $0.id != randomMainWord.id && $0.russian.lowercased() != randomMainWord.russian.lowercased() }
            .map { $0.russian }))
        
        let wrongAnswers = alternativeTranslations.shuffled().prefix(2)
        answers.append(contentsOf: wrongAnswers)
        
        while answers.count < 3 { answers.append("—") }
        options = answers.shuffled()
    }
    
    func speakWord() {
        guard let word = currentWord else { return }
        TextToSpeechManager.shared.speak(word.english)
    }
    
    func checkAnswer(_ option: String) {
        selectedAnswer = option
        totalAnswered += 1
        if option == currentWord?.russian { correctCount += 1 }
    }
    
    func buttonColor(for option: String) -> Color {
        guard let selected = selectedAnswer else { return baseButtonColor.opacity(0.08) }
        if option == currentWord?.russian { return .green }
        if option == selected { return .red }
        return baseButtonColor.opacity(0.03)
    }
    
    func buttonTextColor(for option: String) -> Color {
        guard selectedAnswer != nil else { return baseButtonColor }
        if option == currentWord?.russian || option == selectedAnswer { return .white }
        return baseButtonColor.opacity(0.4)
    }
}
