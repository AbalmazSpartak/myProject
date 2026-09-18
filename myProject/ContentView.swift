import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @State private var currentScreen = "menu"
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case "cards":
                FlashcardsView(currentScreen: $currentScreen)
                    .transition(.opacity)
            case "quiz":
                QuizView(currentScreen: $currentScreen)
                    .transition(.opacity)
            case "dictionary":
                DictionaryView(currentScreen: $currentScreen)
                    .transition(.opacity)
            default:
                TitleScreenView(currentScreen: $currentScreen)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: currentScreen)
        .preferredColorScheme(.dark)
        .onAppear {
            if words.isEmpty {
                for word in sampleWords {
                    modelContext.insert(word)
                }
            }
        }
    }
}

// MARK: - ГЛАВНОЕ МЕНЮ
struct TitleScreenView: View {
    @Binding var currentScreen: String
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 10)
            
            VStack(spacing: 10) {
                Text("WordLearner")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                
                Text("Твой персональный тренажер английского")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            VStack(spacing: 15) {
                Button(action: { currentScreen = "cards" }) {
                    HStack {
                        Text("Карточки с вводом")
                        Image(systemName: "keyboard")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                Button(action: { currentScreen = "quiz" }) {
                    HStack {
                        Text("Викторина (Выбор ответа)")
                        Image(systemName: "checkmark.seal.fill")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                Button(action: { currentScreen = "dictionary" }) {
                    HStack {
                        Text("Открыть словарь")
                        Image(systemName: "book.fill")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)
        }
    }
}
