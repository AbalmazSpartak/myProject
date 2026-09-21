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
            
            // Раскрывающийся список категорий (папок) на базе нативного Menu
            Menu {
                // 1. Пункт "Общий словарь"
                Button(action: { selectedCategory = nil }) {
                    HStack {
                        Text("Общий")
                        Spacer()
                        // Если выбран "Общий", подсветим его галочкой
                        if selectedCategory == nil { Image(systemName: "checkmark") }
                    }
                }
                
                Divider() // Визуальный разделитель между Общим и кастомными папками
                
                // 2. Список всех доступных папок
                ForEach(categories) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack {
                            Text("\(category.name) (\(category.words.count))")
                            Spacer()
                            if selectedCategory?.id == category.id { Image(systemName: "checkmark") }
                        }
                    }
                    // Безопасное удаление конкретной папки прямо из выпадающего списка
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteCategory(category)
                        } label: {
                            Label("Удалить папку", systemImage: "trash")
                        }
                    }
                }
                
                Divider()
                
                // 3. Кнопка создания новой папки прямо внутри меню
                Button(action: { isAddingCategory = true }) {
                    Label("Создать новую папку...", systemImage: "folder.badge.plus")
                }
                
            } label: {
                // Внешний вид кнопки раскрывающегося списка (занимает место старой ленты)
                HStack {
                    Image(systemName: selectedCategory == nil ? "folder.fill" : "folder.fill.badge.gearshape")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(selectedCategory == nil ? "Общий словарь" : selectedCategory!.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 26/255, green: 37/255, blue: 68/255))
                    
                    // Маленький счетчик слов для выбранной в данный момент папки
                    Text(selectedCategory == nil ? "" : "(\(selectedCategory!.words.count))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
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
