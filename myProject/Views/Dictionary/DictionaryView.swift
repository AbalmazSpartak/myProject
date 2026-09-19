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
    @State private var closeKeyboardsTrigger = false
    
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
                Text("Мой словарь")
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
            
            // Оптимизированный список слов (подтягивается из отдельного файла)
            WordListView(selectedCategory: selectedCategory, editingWord: $editingWord)
        }
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
                if let fileURL = urls.first {
                    importWords(url: fileURL)
                }
            case .failure(let error):
                print("Ошибка импорта: \(error.localizedDescription)")
            }
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
                
                // Стандартизируем все виды тире
                let normalizedLine = trimmedLine
                    .replacingOccurrences(of: " — ", with: " | ")
                    .replacingOccurrences(of: " – ", with: " | ")
                    .replacingOccurrences(of: " - ", with: " | ")
                
                // Фильтруем пустые элементы, которые могли возникнуть из-за лишних пробелов вокруг дефисов
                let parts = normalizedLine.components(separatedBy: " | ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // Защитная проверка: строго контролируем наличие 4 колонок данных перед обращением по индексу
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
        } catch {
            print("Ошибка импорта: \(error.localizedDescription)")
        }
    }
}
