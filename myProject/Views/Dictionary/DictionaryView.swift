import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var currentScreen: String
    
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var selectedCategory: Category? = nil
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var isImporting = false
    @State private var editingWord: Word? = nil
    
    @State private var isManagingCategories = false
    @State private var closeKeyboardsTrigger = false
    @State private var isDropdownExpanded = false
    
    var body: some View {
        ZStack(alignment: .top) {
            // Задний фон экрана
            Color(red: 247/255, green: 249/255, blue: 253/255)
                .ignoresSafeArea()
            
            // 1. ОСНОВНОЙ ИНТЕРФЕЙС ЭКРАНА
            VStack(spacing: 0) {
                // Верхняя навигационная панель
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
                        .foregroundColor(Color(red: 26/255, green: 37/255, blue: 68/255))
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
                
                // Кнопка выбора категории папок
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDropdownExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: selectedCategory == nil ? "folder.fill" : "folder.fill.badge.gearshape")
                            .foregroundColor(.orange)
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text(selectedCategory == nil ? "Общий словарь" : selectedCategory!.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 26/255, green: 37/255, blue: 68/255))
                        
                        Text(selectedCategory == nil ? "" : "(\(selectedCategory!.words.count))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray.opacity(0.5))
                            .rotationEffect(.degrees(isDropdownExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // Форма ручной добавки слов
                AddWordFormView(selectedCategory: selectedCategory)
                    .id(closeKeyboardsTrigger)
                
                // Список слов
                WordListView(selectedCategory: selectedCategory, editingWord: $editingWord)
            }
            
            // 2. ВЫПАДАЮЩЕЕ МЕНЮ (Верхний независимый слой ZStack)
            if isDropdownExpanded {
                // Невидимый слой для закрытия меню по клику в любую точку экрана
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDropdownExpanded = false
                        }
                    }
                
                // Окно выбора папок с четко заданным контейнером
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            Button(action: {
                                selectedCategory = nil
                                withAnimation { isDropdownExpanded = false }
                            }) {
                                DropdownRow(title: "Общий", isSelected: selectedCategory == nil)
                            }
                            
                            Divider().padding(.horizontal, 16)
                            
                            ForEach(categories) { category in
                                Button(action: {
                                    selectedCategory = category
                                    withAnimation { isDropdownExpanded = false }
                                }) {
                                    DropdownRow(
                                        title: "\(category.name) (\(category.words.count))",
                                        isSelected: selectedCategory?.id == category.id
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 390)
                    
                    Divider()
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            isDropdownExpanded = false
                            isAddingCategory = true
                        }) {
                            DropdownServiceRow(title: "Создать новую папку...", icon: "folder.badge.plus", color: .blue)
                        }
                        Divider().padding(.horizontal, 16)
                        Button(action: {
                            isDropdownExpanded = false
                            isManagingCategories = true
                        }) {
                            DropdownServiceRow(title: "Управление папками...", icon: "folder.badge.gearshape", color: .gray)
                        }
                    }
                    .background(Color(red: 250/255, green: 251/255, blue: 253/255))
                }
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 24)
                .padding(.top, 105) // Позиционирование меню четко под кнопкой выбора
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheet(item: $editingWord) { word in
            EditWordView(word: word)
        }
        .sheet(isPresented: $isManagingCategories) {
            NavigationStack {
                List {
                    ForEach(categories) { category in
                        HStack {
                            Label(category.name, systemImage: "folder")
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundColor(Color(red: 26/255, green: 37/255, blue: 68/255))
                            Spacer()
                            Text("\(category.words.count) слов")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let categoryToDelete = categories[index]
                            deleteCategory(categoryToDelete)
                        }
                    }
                }
                .navigationTitle("Папки")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") { isManagingCategories = false }
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                .preferredColorScheme(.light)
            }
            .presentationDetents([.medium, .large])
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

// MARK: - Вспомогательные компоненты списка
struct DropdownRow: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .orange : Color(red: 26/255, green: 37/255, blue: 68/255))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.orange.opacity(0.04) : Color.clear)
    }
}

struct DropdownServiceRow: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
        }
        .foregroundColor(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
