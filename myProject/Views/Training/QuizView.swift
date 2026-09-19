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
    
    var body: some View {
        VStack(spacing: 25) {
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
            
            // ИСПРАВЛЕНИЕ: Крупный заголовок "Викторина" полностью удален
            
            Spacer()
            
            if !hasMinimumWords {
                Text("Для генерации тестов нужно минимум 3 слова с уникальными переводами в вашем словаре.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding()
            } else if let word = currentWord {
                // ЦЕЛЬНАЯ КАРТОЧКА ВИКТОРИНЫ
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
                    .padding(.top, 10)
                    
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
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
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
            checkDatabaseAndStart()
        }
    }
    
    private func checkDatabaseAndStart() {
        do {
            let descriptor = FetchDescriptor<Word>()
            let allWords = try modelContext.fetch(descriptor)
            
            // Собираем все уникальные русские переводы через Set
            let uniqueTranslations = Set(allWords.map { $0.russian.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            
            // Для викторины нужно минимум 3 разных перевода, иначе кнопки будут дублироваться
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
        selectedAnswer = nil
        
        do {
            let descriptor = FetchDescriptor<Word>()
            let allWords = try modelContext.fetch(descriptor)
            
            guard allWords.count >= 3 else { return }
            
            if let randomMainWord = allWords.randomElement() {
                currentWord = randomMainWord
                
                var answers = [randomMainWord.russian]
                
                // ИСПРАВЛЕНИЕ БАГА: исключаем дубликаты строк через Set
                let alternativeTranslations = Array(Set(allWords
                    .filter { $0.id != randomMainWord.id && $0.russian.lowercased() != randomMainWord.russian.lowercased() }
                    .map { $0.russian }))
                
                let wrongAnswers = alternativeTranslations.shuffled().prefix(2)
                answers.append(contentsOf: wrongAnswers)
                
                // Если вариантов все равно не хватило до 3 (из-за дубликатов в БД), подмешиваем заглушки
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
