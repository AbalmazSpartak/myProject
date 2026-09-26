import SwiftUI
import SwiftData

// Перечисление всех экранов для навигации
enum ActiveScreen: Identifiable {
    case profile           // Мой профиль
    case flashcardsFSRS    // Карточки для запоминания (FSRS)
    case quiz              // Викторина
    case inputCards        // Карточки ввода (написание ответов)
    case tetris            // Тетрис слов
    case dictionary        // Словарь
    
    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // 1. МОЙ ПРОФИЛЬ (Верхний баннер)
                    Button(action: { activeScreen = .profile }) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profiles.first?.name ?? "Мой профиль")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.brandDark)
                                
                                Text("Статистика и достижения")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray.opacity(0.6))
                        }
                        .padding(18)
                        .background(Color.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    }
                    
                    // 2. РАЗДЕЛ: КАРТОЧКИ (Группа из 2-х тренировок)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundColor(.blue)
                            Text("Карточки")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.brandDark)
                        }
                        .padding(.horizontal, 4)
                        
                        VStack(spacing: 10) {
                            // 2a. Карточки для запоминания (FSRS)
                            MenuTileButton(
                                title: "Карточки для запоминания",
                                subtitle: "Интервальные повторения FSRS",
                                icon: "brain.head.profile",
                                color: .indigo
                            ) {
                                activeScreen = .flashcardsFSRS
                            }
                            
                            // 2b. Викторина
                            MenuTileButton(
                                title: "Викторина",
                                subtitle: "Тест с 4 вариантами ответов",
                                icon: "checkmark.seal.fill",
                                color: .orange
                            ) {
                                activeScreen = .quiz
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(22)
                    
                    // 3. КАРТОЧКИ ВВОДА (Практика написания)
                    MenuTileButton(
                        title: "Карточки ввода",
                        subtitle: "Тренировка ручного ввода перевода",
                        icon: "keyboard.fill",
                        color: .teal
                    ) {
                        activeScreen = .inputCards
                    }
                    
                    // 4. ТЕТРИС СЛОВ
                    MenuTileButton(
                        title: "Тетрис слов",
                        subtitle: "Аркадная игра на скорость",
                        icon: "gamecontroller.fill",
                        color: .purple
                    ) {
                        activeScreen = .tetris
                    }
                    
                    // 5. СЛОВАРЬ
                    MenuTileButton(
                        title: "Словарь",
                        subtitle: "Управление словами и категориями",
                        icon: "book.closed.fill",
                        color: .green
                    ) {
                        activeScreen = .dictionary
                    }
                    
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Главное меню")
            .background(Color.brandBackground.ignoresSafeArea())
            // Открытие выбранного экрана на весь экран
            .fullScreenCover(item: $activeScreen) { screen in
                switch screen {
                case .profile:
                    ProfileView() // Ваш экран профиля
                case .flashcardsFSRS:
                    FlashcardsView() // Карточки с алгоритмом FSRS
                case .quiz:
                    QuizView() // Викторина
                case .inputCards:
                    InputFlashcardsView() // Экран ввода ответов (вручную)
                case .tetris:
                    TetrisView() // Тетрис
                case .dictionary:
                    DictionaryView() // Ваш экран словаря
                }
            }
        }
    }
}

// MARK: - Вспомогательный компонент для карточек меню
struct MenuTileButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        }
    }
}
