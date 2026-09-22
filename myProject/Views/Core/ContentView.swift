import SwiftUI
import SwiftData

enum AppScreen: String, Hashable {
    case cards, quiz, dictionary
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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            TitleScreenView(navigationPath: $navigationPath)
                .navigationDestination(for: AppScreen.self) { screen in
                    Group {
                        switch screen {
                        case .cards:
                            FlashcardsView()
                        case .quiz:
                            QuizView()
                        case .dictionary:
                            DictionaryView()
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
        }
        .preferredColorScheme(.light)
        .onAppear {
            DataPreloader.preloadSampleWords(context: modelContext)
        }
    }
}

struct TitleScreenView: View {
    @Binding var navigationPath: [AppScreen]
    @AppStorage("menu_order") private var menuOrderData: String = "cards,quiz,dictionary"
    @State private var menuItems: [MenuItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(minHeight: 20, maxHeight: 60)
            
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
            
            VStack(spacing: 12) {
                Text("WordLearner")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.brandDark)
                
                Text("Твой персональный тренажер\nанглийского языка")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer().frame(minHeight: 20, maxHeight: 50)
            
            VStack(spacing: 16) {
                ForEach(menuItems) { item in
                    Button(action: { navigationPath.append(item.id) }) {
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
            Spacer().frame(height: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground)
        .onAppear(perform: loadMenuOrder)
    }
    
    private func loadMenuOrder() {
        let allItems: [String: MenuItem] = [
            "cards": MenuItem(id: .cards, title: "Карточки с вводом", subtitle: "Учи новые слова", icon: "keyboard.fill", color: .blue),
            "quiz": MenuItem(id: .quiz, title: "Викторина", subtitle: "Тесты с вариантами", icon: "checkmark.seal.fill", color: .purple),
            "dictionary": MenuItem(id: .dictionary, title: "Словарь", subtitle: "Все изученные слова", icon: "book.fill", color: .orange)
        ]
        let ids = menuOrderData.components(separatedBy: ",")
        var orderedList: [MenuItem] = []
        for id in ids {
            if let item = allItems[id] { orderedList.append(item) }
        }
        menuItems = orderedList.count == 3 ? orderedList : [allItems["cards"]!, allItems["quiz"]!, allItems["dictionary"]!]
    }
}
