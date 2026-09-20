import SwiftUI
import SwiftData

struct MenuItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

// MARK: - ГЛАВНЫЙ НАВИГАЦИОННЫЙ ПЕРЕКЛЮЧАТЕЛЬ
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @State private var currentScreen = "menu" // Хранит ID активного экрана
    
    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
            
            switch currentScreen {
            case "cards":
                FlashcardsView(currentScreen: $currentScreen)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case "quiz":
                QuizView(currentScreen: $currentScreen)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case "dictionary":
                DictionaryView(currentScreen: $currentScreen)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            default:
                TitleScreenView(currentScreen: $currentScreen)
                    .transition(.opacity)
            }
        }
        // Пружинная анимация переключения разделов меню
        .animation(.interpolatingSpring(stiffness: 170, damping: 22), value: currentScreen)
        .preferredColorScheme(.light)
        .onAppear {
            if words.isEmpty {
                for word in sampleWords { modelContext.insert(word) }
            }
        }
    }
}

// MARK: - ИНТЕРФЕЙС ГЛАВНОЙ СТРАНИЦЫ
struct TitleScreenView: View {
    @Binding var currentScreen: String
    @AppStorage("menu_order") private var menuOrderData: String = "cards,quiz,dictionary"
    @State private var menuItems: [MenuItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(minHeight: 20, maxHeight: 60)
            
            // 1. ЛОГОТИП ПРИЛОЖЕНИЯ
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
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
            
            // 2. БЛОК ЗАГОЛОВКОВ ТЕКСТА
            VStack(spacing: 12) {
                Text("WordLearner")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 26/255, green: 37/255, blue: 68/255))
                
                Text("Твой персональный тренажер\nанглийского языка")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
                .frame(minHeight: 20, maxHeight: 50)
            
            // 3. ИНТЕРАКТИВНЫЕ КАРТОЧКИ РАЗДЕЛОВ
            VStack(spacing: 16) {
                ForEach(menuItems) { item in
                    Button(action: { currentScreen = item.id }) {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(item.color)
                                .frame(width: 6)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(item.color.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .foregroundColor(item.color)
                            }
                            .padding(.leading, 16)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                
                                Text(item.subtitle)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 16)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.trailing, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(FlatButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 247/255, green: 249/255, blue: 253/255))
        .onAppear(perform: loadMenuOrder)
    }
    
    private func loadMenuOrder() {
        let allItems = [
            "cards": MenuItem(id: "cards", title: "Карточки с вводом", subtitle: "Учи новые слова", icon: "keyboard.fill", color: Color.blue),
            "quiz": MenuItem(id: "quiz", title: "Викторина", subtitle: "Тесты с вариантами", icon: "checkmark.seal.fill", color: Color.purple),
            "dictionary": MenuItem(id: "dictionary", title: "Словарь", subtitle: "Все изученные слова", icon: "book.fill", color: Color.orange)
        ]
        
        let ids = menuOrderData.components(separatedBy: ",")
        var orderedList: [MenuItem] = []
        for id in ids {
            if let item = allItems[id] { orderedList.append(item) }
        }
        menuItems = orderedList.count == 3 ? orderedList : [allItems["cards"]!, allItems["quiz"]!, allItems["dictionary"]!]
    }
}

// MARK: - ЭФФЕКТ ФИЗИЧЕСКОГО НАЖАТИЯ КНОПОК
struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
