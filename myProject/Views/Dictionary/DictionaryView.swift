import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var currentScreen: String
    
    @Query(sort: \Word.english) private var allWords: [Word]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var selectedCategory: Category? = nil // nil = "Общий словарь"
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var isImporting = false
    
    // Состояние для редактирования слова
    @State private var editingWord: Word? = nil
    
    @State private var closeKeyboardsTrigger = false
    
    var filteredWords: [Word] {
        if let selected = selectedCategory {
            return allWords.filter { $0.category?.id == selected.id }
        } else {
            return allWords
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхняя навигационная панель
            HStack {
                Button(action: { currentScreen = "menu" }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Меню")
                    }
                    .font(.headline)
                }
                Spacer()
                Text("Мой словарь (\(filteredWords.count))")
                    .font(.headline)
                    .bold()
                Spacer()
                
                Button(action: { isImporting = true }) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            
            // Горизонтальный селектор категорий (папок)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button(action: { selectedCategory = nil }) {
                        Text("Общий")
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == nil ? Color.orange : Color.secondary.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    
                    ForEach(categories) { category in
                        HStack(spacing: 4) {
                            Text(category.name)
                                .fontWeight(.medium)
                                .onTapGesture { selectedCategory = category }
                            
                            Button(action: { deleteCategory(category) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedCategory?.id == category.id ? Color.orange : Color.secondary.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    
                    Button(action: { isAddingCategory = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Папка")
                        }
                        .fontWeight(.bold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.blue)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            
            // Форма добавления новых слов
            AddWordFormView(selectedCategory: selectedCategory)
                .id(closeKeyboardsTrigger)
            
            // Список слов
            List {
                ForEach(filteredWords) { word in
                    Button(action: { editingWord = word }) { // Клик по строке открывает редактор
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(word.english)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(word.russian)
                                    .foregroundColor(.gray)
                            }
                            if !word.example.isEmpty {
                                Text(word.example)
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            if selectedCategory == nil, let cat = word.category {
                                Text(cat.name)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteWord)
            }
            .listStyle(PlainListStyle())
            .onTapGesture { closeKeyboardsTrigger.toggle() }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { closeKeyboardsTrigger.toggle() }
        )
        // Модальное окно редактирования слова (Берется теперь из отдельного файла)
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
                if let fileURL = urls.first {
                    importWords(url: fileURL)
                }
            case .failure(let error):
                print("Ошибка импорта: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteWord(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredWords[index])
        }
    }
    
    func deleteCategory(_ category: Category) {
        if selectedCategory?.id == category.id {
            selectedCategory = nil
        }
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
                
                let parts = trimmedLine.components(separatedBy: " — ")
                
                if parts.count == 4 {
                    let englishPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let russianPart = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    var examplePart = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    examplePart = examplePart.trimmingCharacters(in: CharacterSet(charactersIn: "\"‘'—«»"))
                    
                    if !englishPart.isEmpty && !russianPart.isEmpty {
                        let newWord = Word(english: englishPart, russian: russianPart, example: examplePart, category: selectedCategory)
                        modelContext.insert(newWord)
                    }
                }
            }
        } catch {
            print("Ошибка импорта: \(error.localizedDescription)")
        }
    }
}
