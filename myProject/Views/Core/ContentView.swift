import SwiftUI
import SwiftData

enum AppScreen: String, Hashable {
    case profile, cards, quiz, dictionary, tetris
}

struct MenuItem: Identifiable {
    let id: AppScreen
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navigationPath: [AppScreen] = []
    
    // Переключатель темы оформления
    @AppStorage("app_theme") private var selectedTheme: String = "system"

    
    private var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            TitleScreenView(navigationPath: $navigationPath)
                .navigationDestination(for: AppScreen.self) { screen in
                    Group {
                        switch screen {
                        case .profile:
                            ProfileView()
                        case .cards:
                            FlashcardsView()
                        case .quiz:
                            QuizView()
                        case .dictionary:
                            DictionaryView()
                        case .tetris: // 👈 Переход на новый экран
                            TetrisView()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            DataPreloader.preloadSampleWords(context: modelContext)
        }
    }
}

struct TitleScreenView: View {
    @Binding var navigationPath: [AppScreen]
    
    @AppStorage("menu_order_v3") private var menuOrderData: String = "profile,cards,quiz,dictionary,tetris"
    @State private var menuItems: [MenuItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(minHeight: 20, maxHeight: 60)
            
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.cardBackground)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 10)
                
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .padding(.bottom, 25)
            
            VStack(spacing: 12) {
                Text("WordLearner")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.brandDark)
                
                /*Text("Твой персональный тренажер\nанглийского языка")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)*/
            }
            
            Spacer().frame(minHeight: 20, maxHeight: 50)
            
            VStack(spacing: 16) {
                ForEach(menuItems) { item in
                    Button(action: {
                        // 👇 ДОБАВЛЯЕМ ВИБРАЦИЮ ЗДЕСЬ
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        navigationPath.append(item.id) }) {
                        HStack(spacing: 0) {
                            Rectangle().fill(item.color).frame(width: 6)
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(item.color.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .foregroundColor(item.color)
                            }
                            .padding(.leading, 16)
                            
                            Text(item.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .padding(.leading, 16)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.cardBackground)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(FlatButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            Spacer().frame(height: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
        .onAppear(perform: loadMenuOrder)
    }
    
    private func loadMenuOrder() {
        let allItems: [String: MenuItem] = [
            "profile": MenuItem(id: .profile, title: "Мой профиль", subtitle: "Статистика и успехи", icon: "person.fill", color: .teal),
            "cards": MenuItem(id: .cards, title: "Карточки для запоминания", subtitle: "Учи новые слова", icon: "keyboard.fill", color: .blue),
            "quiz": MenuItem(id: .quiz, title: "Викторина", subtitle: "Тесты с вариантами", icon: "checkmark.seal.fill", color: .purple),
            "dictionary": MenuItem(id: .dictionary, title: "Словарь", subtitle: "Все изученные слова", icon: "book.fill", color: .orange),
            "tetris": MenuItem(id: .tetris, title: "Тетрис слов", subtitle: "Игровое повторение", icon: "gamecontroller.fill", color: .indigo) // 👈 Добавлен пункт
        ]
        
        let ids = menuOrderData.components(separatedBy: ",")
        var orderedList: [MenuItem] = []
        
        for id in ids {
            if let item = allItems[id] {
                orderedList.append(item)
            }
        }
        
        let defaultOrder: [MenuItem] = [
            allItems["profile"]!,
            allItems["cards"]!,
            allItems["quiz"]!,
            allItems["dictionary"]!,
            allItems["tetris"]!
        ]
        
        menuItems = orderedList.count >= 5 ? orderedList : defaultOrder
    }
}
