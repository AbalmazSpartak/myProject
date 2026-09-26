import SwiftUI
import SwiftData

enum ActiveScreen: Identifiable {
    case profile
    case flashcardsFSRS
    case quiz
    case inputCards
    case dictionary
    case tetris
    
    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?
    @State private var isCardsExpanded: Bool = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Адаптивный фон: Белый в светлой теме, Черный в темной
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // MARK: - Логотип и заголовок приложения
                        VStack(spacing: 24) {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    // Адаптивный цвет фона логотипа
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 90, height: 90)
                                
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 44, weight: .regular))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("WordLearner")
                                .font(.system(size: 34, weight: .heavy, design: .default))
                                // Адаптивный цвет текста (черный днем, белый ночью)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 80)
                        .padding(.bottom, 20)
                        
                        // MARK: - Меню кнопок
                        VStack(spacing: 14) {
                            
                            // 1. Мой профиль (Бирюзовый)
                            MenuCardButton(
                                title: "Мой профиль",
                                icon: "person.fill",
                                themeColor: .teal
                            ) {
                                activeScreen = .profile
                            }
                            
                            // 2. РАЗДЕЛ: КАРТОЧКИ (Выпадающий список)
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
                                            .foregroundColor(.primary) // Адаптивный текст
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
                                        // 2a. Карточки для запоминания (Синий)
                                        MenuCardButton(
                                            title: "Карточки для\nзапоминания",
                                            icon: "brain.head.profile",
                                            themeColor: .blue
                                        ) {
                                            activeScreen = .flashcardsFSRS
                                        }
                                        
                                        // 2b. Викторина (Фиолетовый)
                                        MenuCardButton(
                                            title: "Викторина",
                                            icon: "checkmark.seal.fill",
                                            themeColor: .purple
                                        ) {
                                            activeScreen = .quiz
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(14)
                            // Адаптивный фон для выделения раздела
                            .background(Color(.systemGray6))
                            .cornerRadius(24)
                            
                            // 3. Карточки ввода (На главном уровне)
                            MenuCardButton(
                                title: "Карточки ввода",
                                icon: "keyboard.fill",
                                themeColor: .teal
                            ) {
                                activeScreen = .inputCards
                            }
                            
                            // 4. Словарь (Оранжевый)
                            MenuCardButton(
                                title: "Словарь",
                                icon: "book.fill",
                                themeColor: .orange
                            ) {
                                activeScreen = .dictionary
                            }
                            
                            // 5. Тетрис слов (Индиго)
                            MenuCardButton(
                                title: "Тетрис слов",
                                icon: "gamecontroller.fill",
                                themeColor: .indigo
                            ) {
                                activeScreen = .tetris
                            }
                        }
                        .padding(.horizontal, 20)
                        
                    }
                    .padding(.bottom, 40)
                }
            }
            // Удален модификатор .preferredColorScheme(.dark), теперь тема зависит от устройства
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
                }
            }
        }
    }
}

// MARK: - Вспомогательный компонент для кнопок меню
struct MenuCardButton: View {
    let title: String
    let icon: String
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        // Адаптивный цвет квадрата под иконкой
                        .fill(Color(.systemGray5))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(themeColor)
                }
                
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .default))
                    // Адаптивный цвет текста
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                ZStack(alignment: .leading) {
                    // Адаптивный цвет фона самой кнопки
                    Color(.secondarySystemBackground)
                    themeColor.frame(width: 6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
