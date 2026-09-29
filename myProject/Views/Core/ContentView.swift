import SwiftUI
import SwiftData

enum ActiveScreen: Identifiable {
    case profile
    case flashcardsFSRS
    case quiz
    case inputCards
    case dictionary
    case tetris
    case race
    
    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?
    @State private var isCardsExpanded: Bool = false
    @State private var isMiniGamesExpanded: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        VStack(spacing: 24) {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 90, height: 90)
                                
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 44, weight: .regular))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("WordLearner")
                                .font(.system(size: 34, weight: .heavy, design: .default))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 80)
                        .padding(.bottom, 20)
                        
                        VStack(spacing: 14) {
                            
                            MenuCardButton(
                                title: "Мой профиль",
                                icon: "person.fill",
                                themeColor: .teal
                            ) {
                                activeScreen = .profile
                            }
                            
                            VStack(alignment: .leading, spacing: 14) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isCardsExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "square.stack.3d.up.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 18))
                                        Text("Карточки")
                                            .font(.system(size: 20, weight: .bold, design: .default))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: isCardsExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.top, 4)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                
                                if isCardsExpanded {
                                    VStack(spacing: 14) {
                                        MenuCardButton(
                                            title: "Карточки для\nзапоминания",
                                            icon: "brain.head.profile",
                                            themeColor: .blue
                                        ) {
                                            activeScreen = .flashcardsFSRS
                                        }
                                        
                                        MenuCardButton(
                                            title: "Викторина",
                                            icon: "checkmark.seal.fill",
                                            themeColor: .purple
                                        ) {
                                            activeScreen = .quiz
                                        }
                                    }
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                                        removal: .opacity
                                    ))
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        isMiniGamesExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gamecontroller.fill")
                                            .foregroundColor(.indigo)
                                            .font(.system(size: 18))
                                        Text("Мини-игры")
                                            .font(.system(size: 20, weight: .bold, design: .default))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: isMiniGamesExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.top, 4)
                                    .contentShape(Rectangle())
                                }
                                
                                .buttonStyle(.plain)
                                
                                if isMiniGamesExpanded {
                                    VStack(spacing: 14) {
                                        MenuCardButton(
                                            title: "Тетрис слов",
                                            icon: "gamecontroller.fill",
                                            themeColor: .indigo
                                        ) {
                                            activeScreen = .tetris
                                        }
                                        
                                        MenuCardButton(
                                            title: "Гонка слов",
                                            icon: "car.fill",
                                            themeColor: .green
                                        ) {
                                            activeScreen = .race
                                        }
                                        
                                        // Следующую мини-игру добавлять сюда же, новым MenuCardButton
                                    }
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                                        removal: .opacity
                                    ))
                                }
                            }
                            .padding(14)
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                            
                            MenuCardButton(
                                title: "Карточки ввода",
                                icon: "keyboard.fill",
                                themeColor: .teal
                            ) {
                                activeScreen = .inputCards
                            }
                            
                            MenuCardButton(
                                title: "Словарь",
                                icon: "book.fill",
                                themeColor: .orange
                            ) {
                                activeScreen = .dictionary
                            }

                        }
                        .padding(.horizontal, 20)
                        
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $activeScreen) { screen in
                switch screen {
                case .profile:
                    ProfileView()
                case .flashcardsFSRS:
                    FlashcardsView()
                case .quiz:
                    QuizView()
                case .inputCards:
                    InputFlashcardsView()
                case .dictionary:
                    DictionaryView()
                case .tetris:
                    TetrisView()
                case .race:
                    RaceLobbyView()
                }
            }
        }
    }
}
