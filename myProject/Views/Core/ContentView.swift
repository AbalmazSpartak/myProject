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

// Структура для идентификации блоков меню
struct MenuItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
}

// MARK: - ОБНОВЛЕННЫЙ ТИТУЛЬНЫЙ ЭКРАН С ПЕРЕТАСКИВАНИЕМ БЛОКОВ
struct TitleScreenView: View {
    @Binding var currentScreen: String
    
    // Системное состояние режима редактирования списка
    @State private var editMode: EditMode = .inactive
    
    // Храним порядок блоков в памяти приложения (@AppStorage, чтобы порядок не сбрасывался)
    @AppStorage("menu_order") private var menuOrderData: String = "cards,quiz,dictionary"
    
    // Исходный список доступных разделов
    @State private var menuItems: [MenuItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель управления с кнопкой "Изменить / Готово"
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }) {
                    Text(editMode.isEditing ? "Готово" : "Изменить меню")
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 25)
            .padding(.top, 15)
            
            Spacer()
            
            // Логотип приложения
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
            
            // БЛОЧНАЯ СИСТЕМА (Интерактивный список кнопок)
            List {
                ForEach(menuItems) { item in
                    Button(action: {
                        // Кнопки работают только когда мы НЕ находимся в режиме сортировки
                        if !editMode.isEditing {
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
                            
                            // Если режим редактирования выключен, показываем стрелочку перехода
                            if !editMode.isEditing {
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
                            .fill(item.color)
                            .padding(.vertical, 6)
                    )
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: moveBlock) // Включаем встроенную сортировку блоков
            }
            .listStyle(PlainListStyle())
            .environment(\.editMode, $editMode) // Передаем состояние режима редактирования в список
            .frame(height: 280) // Ограничиваем контейнер блоков, чтобы они не растягивались на весь экран
            .padding(.horizontal, 25)
            
            Spacer()
        }
        .onAppear(perform: loadMenuOrder) // Загружаем сохраненный пользователем порядок при старте
    }
    
    // Функция перетаскивания блоков
    private func moveBlock(from source: IndexSet, to destination: Int) {
        menuItems.move(fromOffsets: source, toOffset: destination)
        
        // Сразу сохраняем новый порядок в память телефона
        let newOrder = menuItems.map { $0.id }.joined(separator: ",")
        menuOrderData = newOrder
    }
    
    // Функция сборки меню на основе сохраненного порядка
    private func loadMenuOrder() {
        let allItems = [
            "cards": MenuItem(id: "cards", title: "Карточки с вводом", icon: "keyboard", color: Color.blue),
            "quiz": MenuItem(id: "quiz", title: "Викторина (Выбор ответа)", icon: "checkmark.seal.fill", color: Color.purple),
            "dictionary": MenuItem(id: "dictionary", title: "Открыть словарь", icon: "book.fill", color: Color.orange)
        ]
        
        let ids = menuOrderData.components(separatedBy: ",")
        var orderedList: [MenuItem] = []
        
        for id in ids {
            if let item = allItems[id] {
                orderedList.append(item)
            }
        }
        
        // Защитная проверка: если что-то пошло не так, загружаем дефолтный порядок
        if orderedList.count != 3 {
            menuItems = [allItems["cards"]!, allItems["quiz"]!, allItems["dictionary"]!]
        } else {
            menuItems = orderedList
        }
    }
}
