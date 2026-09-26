import SwiftUI
import SwiftData

struct FlashcardsFSRSView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allWords: [Word]
    
    @State private var dueWords: [Word] = []
    @State private var currentIndex = 0
    @State private var isAnswerRevealed = false
    
    private let fsrs = FSRSCalculator()
    
    var currentWord: Word? {
        guard !dueWords.isEmpty, currentIndex < dueWords.count else { return nil }
        return dueWords[currentIndex]
    }
    
    var body: some View {
        VStack {
            if dueWords.isEmpty {
                Text("На сегодня всё! 🎉")
                    .font(.title)
                    .foregroundColor(.gray)
            } else if let word = currentWord {
                VStack(spacing: 30) {
                    Text("Осталось карточек: \(dueWords.count - currentIndex)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(word.english)
                        .font(.system(size: 42, weight: .bold))
                    
                    if isAnswerRevealed {
                        Text(word.russian)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        // Кнопки оценки FSRS
                        HStack(spacing: 12) {
                            FSRSButton(title: "Снова", color: .red) {
                                rateWord(rating: .again)
                            }
                            FSRSButton(title: "Трудно", color: .orange) {
                                rateWord(rating: .hard)
                            }
                            FSRSButton(title: "Хорошо", color: .green) {
                                rateWord(rating: .good)
                            }
                            FSRSButton(title: "Легко", color: .blue) {
                                rateWord(rating: .easy)
                            }
                        }
                    } else {
                        Button(action: { isAnswerRevealed = true }) {
                            Text("Показать ответ")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear(perform: loadDueWords)
    }
    
    private func loadDueWords() {
        let now = Date()
        // Фильтруем слова: новые или те, у которых наступил срок повторения
        dueWords = allWords.filter { $0.state == .new || $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    private func rateWord(rating: FSRSRating) {
        guard let word = currentWord else { return }
        
        // Рассчитываем и обновляем данные слова с помощью FSRS
        fsrs.calculateNextReview(word: word, rating: rating)
        
        isAnswerRevealed = false
        currentIndex += 1
    }
}

// Вспомогательный компонент для кнопок
struct FSRSButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(12)
        }
    }
}
