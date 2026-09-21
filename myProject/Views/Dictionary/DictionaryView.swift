import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Word.english) private var allWords: [Word]
    
    @State private var selectedCategory: Category?
    @State private var searchText = ""
    @State private var isImporting = false
    @State private var isShowingAddWord = false
    
    var filteredWords: [Word] {
        allWords.filter { word in
            let matchesCategory = selectedCategory == nil || word.category?.id == selectedCategory?.id
            let matchesSearch = searchText.isEmpty ||
                word.english.localizedCaseInsensitiveContains(searchText) ||
                word.russian.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Меню выбора категории
                categoryHeaderView
                
                // Список слов
                if filteredWords.isEmpty {
                    ContentUnavailableView(
                        "Слова не найдены",
                        systemImage: "book.closed",
                        description: Text("Добавьте новое слово или импортируйте словарь.")
                    )
                } else {
                    List {
                        ForEach(filteredWords) { word in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(word.english)
                                            .font(.headline)
                                        
                                        if !word.transcription.isEmpty {
                                            Text("[\(word.transcription)]")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    if !word.example.isEmpty {
                                        Text(word.example)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(word.russian)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteWords)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Словарь")
            .searchable(text: $searchText, prompt: "Поиск слова...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { isImporting = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        Button(action: { isShowingAddWord = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let selectedFile = urls.first else { return }
                    importWords(from: selectedFile)
                case .failure(let error):
                    print("Ошибка импорта: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: $isShowingAddWord) {
                AddWordFormView(selectedCategory: selectedCategory)
            }
        }
    }
    
    // MARK: - Subviews
    
    // ИСПРАВЛЕНО: Заменили View на `some View`
    private var categoryHeaderView: some View {
        Menu {
            Button("Все категории (\(allWords.count))") {
                selectedCategory = nil
            }
            
            Divider()
            
            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                } label: {
                    HStack {
                        Text("\(category.name) (\(countWords(for: category)))")
                        if selectedCategory?.id == category.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedCategory?.name ?? "Все категории")
                    .font(.headline)
                
                if let category = selectedCategory {
                    Text("(\(countWords(for: category)))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteWords(at offsets: IndexSet) {
        for index in offsets {
            let word = filteredWords[index]
            modelContext.delete(word)
        }
    }
    
    private func countWords(for category: Category) -> Int {
        let categoryID = category.id
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                if let cat = word.category {
                    return cat.id == categoryID
                } else {
                    return false
                }
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
    
    private func importWords(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        let currentCategory = selectedCategory
        
        Task.detached(priority: .userInitiated) {
            defer { url.stopAccessingSecurityScopedResource() }
            
            guard let fileContent = try? String(contentsOf: url, encoding: .utf8) else { return }
            let lines = fileContent.components(separatedBy: .newlines)
            
            var parsedDTOs: [(eng: String, trans: String, rus: String, ex: String)] = []
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                
                let components = trimmed.components(separatedBy: CharacterSet(charactersIn: ";|\t"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                
                if components.count >= 2 {
                    let eng = components[0]
                    let rus = components[1]
                    let trans = components.count > 2 ? components[2] : ""
                    let ex = components.count > 3 ? components[3] : ""
                    
                    parsedDTOs.append((eng: eng, trans: trans, rus: rus, ex: ex))
                }
            }
            
            // ИСПРАВЛЕНО: Передаем неизменяемую копию для безопасности потоков Swift 6
            let itemsToInsert = parsedDTOs
            
            await MainActor.run {
                for item in itemsToInsert {
                    let newWord = Word(
                        english: item.eng,
                        russian: item.rus,
                        example: item.ex,
                        transcription: item.trans,
                        category: currentCategory
                    )
                    modelContext.insert(newWord)
                }
            }
        }
    }
}
