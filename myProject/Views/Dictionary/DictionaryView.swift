import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var currentScreen: String
    
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var selectedCategory: Category? = nil // nil = "Общий словарь"
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var isImporting = false
    @State private var editingWord: Word? = nil
    
    // Системный триггер для закрытия клавиатур
    @State private var closeKeyboardsTrigger = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя навигационная панель под светлую тему
            HStack {
                Button(action: {
                    closeKeyboardsTrigger.toggle()
                    DispatchQueue.main.async { currentScreen = "menu" }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Меню")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
                }
                Spacer()
                Text("Мой словарь")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 26/255, green: 37/255, blue: 68/255)) // Темно-синий заголовок
                Spacer()
                
                Button(action: { isImporting = true }) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            // Горизонтальный селектор категорий (папок)
            // Горизонтальный селектор категорий (папок)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Кнопка "Общий словарь"
                    Button(action: { selectedCategory = nil }) {
                        Text("Общий")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == nil ? Color.orange : Color.white)
                            .foregroundColor(selectedCategory == nil ? .white : Color(red: 26/255, green: 37/255, blue: 68/255))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                    }
                    
                    // Кастомные папки пользователя и из JSON
                    ForEach(categories) { category in
                        Text(category.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory?.id == category.id ? Color.orange : Color.white)
                            .foregroundColor(selectedCategory?.id == category.id ? .white : Color(red: 26/255, green: 37/255, blue: 68/255))
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                            .onTapGesture { selectedCategory = category }
                            // Безопасное удаление папки по долгому нажатию
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteCategory(category)
                                } label: {
                                    Label("Удалить папку", systemImage: "trash")
                                }
                            }
                    }
                    
                    // Кнопка добавления новой папки
                    Button(action: { isAddingCategory = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Папка")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.08))
                        .foregroundColor(.blue)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            // Форма добавления новых слов
            AddWordFormView(selectedCategory: selectedCategory)
                .id(closeKeyboardsTrigger)
            
            // Оптимизированный список слов
            WordListView(selectedCategory: selectedCategory, editingWord: $editingWord)
        }
        // ИСПРАВЛЕНИЕ: красим весь главный экран словаря в фирменный светлый цвет
        .background(Color(red: 247/255, green: 249/255, blue: 253/255).ignoresSafeArea())
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { closeKeyboardsTrigger.toggle() }
        )
        .sheet(item: $editingWord) { word in
            EditWordView(word: word)
        }
        .alert("Новая категория", isPresented: $isAddingCategory) {
            TextField("Название папки", text: $newCategoryName)
                .autocapitalization(.words)
            Button("Отмена", role: .cancel) { newCategoryName = "" }
            Button("Создать") {
                let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    let newCat = Category(name: name)
                    modelContext.insert(newCat)
                }
                newCategoryName = ""
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let fileURL = urls.first { importWords(url: fileURL) }
            case .failure(let error):
                print("Ошибка импорта: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteCategory(_ category: Category) {
        if selectedCategory?.id == category.id { selectedCategory = nil }
        modelContext.delete(category)
    }
    
    private func importWords(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            let lines = fileContent.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty { continue }
                
                let normalizedLine = trimmedLine
                    .replacingOccurrences(of: " — ", with: " | ")
                    .replacingOccurrences(of: " – ", with: " | ")
                    .replacingOccurrences(of: " - ", with: " | ")
                
                let parts = normalizedLine.components(separatedBy: " | ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                if parts.count == 4 {
                    let englishPart = parts[0]
                    var transcriptionPart = parts[1]
                    transcriptionPart = transcriptionPart.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if !transcriptionPart.isEmpty { transcriptionPart = "[\(transcriptionPart)]" }
                    
                    let russianPart = parts[2]
                    var examplePart = parts[3]
                    examplePart = examplePart.trimmingCharacters(in: CharacterSet(charactersIn: "\"‘'—«»"))
                    
                    if !englishPart.isEmpty && !russianPart.isEmpty {
                        let newWord = Word(english: englishPart, russian: russianPart, example: examplePart, transcription: transcriptionPart, category: selectedCategory)
                        modelContext.insert(newWord)
                    }
                }
            }
        } catch { print("Ошибка импорта: \(error.localizedDescription)") }
    }
}
