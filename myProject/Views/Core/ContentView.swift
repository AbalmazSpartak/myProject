import SwiftUI
import SwiftData

// MARK: - ВСПОМОГАТЕЛЬНАЯ МОДЕЛЬ ДЛЯ ЭЛЕМЕНТОВ МЕНЮ
struct MenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @State private var currentScreen = "menu"
    
    var body: some View {
        ZStack {
            Color.black
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
        // Быстрый и плавный пружинный переход для iOS 18
        .animation(.interpolatingSpring(stiffness: 170, damping: 22), value: currentScreen)
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

// MARK: - СТРУКТУРА ГЛАВНОГО МЕНЮ (TitleScreenView)
struct TitleScreenView: View {
    @Binding var currentScreen: String
    
    // ИСПРАВЛЕНИЕ: Используем правильный тип состояния для режима редактирования списка в SwiftUI
    @State private var editMode: EditMode = .inactive
    @AppStorage("menu_order") private var menuOrderData: String = "cards,quiz,dictionary"
    @State private var menuItems: [MenuItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }) {
                    Text(editMode == .active ? "Готово" : "Изменить меню")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 15)
            
            Spacer()
            
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 90))
                .foregroundColor(.blue)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 10)
                .padding(.bottom, 15)
            
            VStack(spacing: 5) {
                Text("WordLearner")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                
                Text("Твой персональный тренажер английского")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            List {
                ForEach(menuItems) { item in
                    Button(action: {
                        if editMode != .active {
                            currentScreen = item.id
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: item.icon)
                                .font(.title2)
                                .frame(width: 30)
                            
                            Text(item.title)
                                .font(.headline)
                            
                            Spacer()
                            
                            if editMode != .active {
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(item.color) // ИСПРАВЛЕНИЕ: Ошибка ShapeStyle полностью ушла
                            .padding(.vertical, 6)
                    )
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveBlock)
            }
            .listStyle(PlainListStyle())
            .environment(\.editMode, $editMode)
            .frame(height: 280)
            .padding(.horizontal, 25)
            
            Spacer()
        }
        .onAppear(perform: loadMenuOrder)
    }
    
    private func moveBlock(from source: IndexSet, to destination: Int) {
        menuItems.move(fromOffsets: source, toOffset: destination)
        let newOrder = menuItems.map { $0.id }.joined(separator: ",")
        menuOrderData = newOrder
    }
    
    private func loadMenuOrder() {
        let allItems = [
            "cards": MenuItem(id: "cards", title: "Карточки с вводом", icon: "keyboard", color: Color.blue),
            "quiz": MenuItem(id: "quiz", title: "Викторина\n(Выбор ответа)", icon: "checkmark.seal.fill", color: Color.purple),
            "dictionary": MenuItem(id: "dictionary", title: "Открыть словарь", icon: "book.fill", color: Color.orange)
        ]
        
        let ids = menuOrderData.components(separatedBy: ",")
        var orderedList: [MenuItem] = []
        
        for id in ids {
            if let item = allItems[id] {
                orderedList.append(item)
            }
        }
        
        if orderedList.count != 3 {
            menuItems = [allItems["cards"]!, allItems["quiz"]!, allItems["dictionary"]!]
        } else {
            menuItems = orderedList
        }
    }
}
