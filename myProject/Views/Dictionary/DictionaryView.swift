import SwiftUI
import SwiftData

struct DictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Word.english) private var allWords: [Word]
    
    @State private var selectedCategory: Category?
    @State private var isDropdownExpanded = false
    @State private var isShowingManageCategories = false
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var wordToEdit: Word?
    
    @State private var newEnglish = ""
    @State private var newTranscription = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    
    var filteredWords: [Word] {
        allWords.filter { word in
            if let selected = selectedCategory {
                return word.category?.id == selected.id
            } else {
                return word.category == nil
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()
            VStack(spacing: 12) {
                customHeader
                ScrollView {
                    VStack(spacing: 12) {
                        categoryDropdownCard
                        if !isDropdownExpanded {
                            addWordCard
                            LazyVStack(spacing: 12) {
                                ForEach(filteredWords) { word in
                                    WordRowCard(word: word) {
                                        wordToEdit = word
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .alert("Новая категория", isPresented: $isShowingAddCategoryAlert) {
            TextField("Название категории", text: $newCategoryName)
            Button("Отмена", role: .cancel) { newCategoryName = "" }
            Button("Создать") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let newCat = Category(name: trimmed)
                    modelContext.insert(newCat)
                    selectedCategory = newCat
                    newCategoryName = ""
                }
            }
        }
        .sheet(isPresented: $isShowingManageCategories) {
            ManageCategoriesView()
        }
        .sheet(item: $wordToEdit) { word in
            EditWordView(word: word)
        }
    }
    
    private var customHeader: some View {
        HStack {
            Button(action: { dismiss() }) { // Изменено
                HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Меню") }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.orange)
            }
            Spacer()
            Text("Мой словарь")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.brandDark)
            Spacer()
            Button(action: { isShowingManageCategories = true }) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var categoryDropdownCard: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDropdownExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill").foregroundColor(.orange).font(.system(size: 18))
                    Text(selectedCategory?.name ?? "Общий словарь").font(.system(size: 17, weight: .bold)).foregroundColor(.brandDark)
                    Spacer()
                    Image(systemName: isDropdownExpanded ? "chevron.up" : "chevron.down").font(.system(size: 14, weight: .semibold)).foregroundColor(.gray)
                }
                .padding(16)
            }
            
            if isDropdownExpanded {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            Button(action: { selectCategoryAndClose(nil) }) {
                                HStack {
                                    Text("Общий").font(.system(size: 16, weight: .bold)).foregroundColor(selectedCategory == nil ? .orange : .brandDark)
                                    Spacer()
                                    if selectedCategory == nil { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.orange) }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                            Divider().padding(.horizontal, 16)
                            ForEach(categories) { category in
                                let isSelected = selectedCategory?.id == category.id
                                Button(action: { selectCategoryAndClose(category) }) {
                                    HStack {
                                        Text("\(category.name) (\(countWords(for: category)))").font(.system(size: 16, weight: isSelected ? .bold : .semibold)).foregroundColor(isSelected ? .orange : .brandDark)
                                        Spacer()
                                        if isSelected { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.orange) }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 440)
                    Divider().padding(.horizontal, 16)
                    Button(action: { isDropdownExpanded = false; isShowingAddCategoryAlert = true }) {
                        HStack(spacing: 10) { Image(systemName: "folder.badge.plus").font(.system(size: 16)); Text("Создать новую папку...").font(.system(size: 15, weight: .semibold)); Spacer() }
                        .foregroundColor(Color(red: 0/255, green: 112/255, blue: 243/255)).padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    Button(action: { isDropdownExpanded = false; isShowingManageCategories = true }) {
                        HStack(spacing: 10) { Image(systemName: "folder.badge.gearshape").font(.system(size: 16)); Text("Управление папками...").font(.system(size: 15, weight: .semibold)); Spacer() }
                        .foregroundColor(.gray).padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    private func selectCategoryAndClose(_ category: Category?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCategory = category
            isDropdownExpanded = false
        }
    }
    
    private var addWordCard: some View {
        VStack(spacing: 12) {
            customTextField(placeholder: "Слово на английском", text: $newEnglish)
            customTextField(placeholder: "Транскрипция (необязательно)", text: $newTranscription)
            customTextField(placeholder: "Перевод на русский", text: $newRussian)
            customTextField(placeholder: "Пример фразы (необязательно)", text: $newExample)
            
            Button(action: addNewWord) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Добавить в \(selectedCategory?.name ?? "Общий")")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .disabled(newEnglish.isEmpty || newRussian.isEmpty)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
    
    private func customTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.brandInputBg)
            .cornerRadius(10)
            .font(.system(size: 15))
    }
    
    private func addNewWord() {
        let trimmedEng = newEnglish.trimmingCharacters(in: .whitespaces)
        let trimmedRus = newRussian.trimmingCharacters(in: .whitespaces)
        var trans = newTranscription.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedEng.isEmpty && !trimmedRus.isEmpty else { return }
        
        if !trans.isEmpty && !trans.hasPrefix("[") {
            trans = "[\(trans)]"
        }
        
        let word = Word(
            english: trimmedEng,
            russian: trimmedRus,
            example: newExample.trimmingCharacters(in: .whitespaces),
            transcription: trans,
            category: selectedCategory
        )
        
        modelContext.insert(word)
        newEnglish = ""
        newTranscription = ""
        newRussian = ""
        newExample = ""
    }
    
    private func countWords(for category: Category) -> Int {
        let categoryID = category.id
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                if let cat = word.category { return cat.id == categoryID } else { return false }
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}

struct WordRowCard: View {
    let word: Word
    var onEdit: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    private var formattedTranscription: String {
        let trimmed = word.transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") { return trimmed }
        return "[\(trimmed)]"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text(word.english).font(.system(size: 18, weight: .bold)).foregroundColor(.brandDark)
                    if !formattedTranscription.isEmpty {
                        Text(formattedTranscription).font(.system(size: 15, weight: .medium)).foregroundColor(.orange)
                    }
                }
                Spacer()
                Text(word.russian).font(.system(size: 16, weight: .bold)).foregroundColor(Color(.systemGray))
            }
            if !word.example.isEmpty {
                Text(word.example).font(.system(size: 14)).foregroundColor(Color(.systemGray2))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
        .contextMenu {
            Button(action: onEdit) {
                Label("Редактировать", systemImage: "pencil")
            }
            Button(role: .destructive) {
                modelContext.delete(word)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var newCategoryName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Создать категорию") {
                    HStack {
                        TextField("Название категории", text: $newCategoryName)
                        Button("Добавить") {
                            let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            modelContext.insert(Category(name: trimmed))
                            newCategoryName = ""
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Существующие категории") {
                    ForEach(categories) { category in Text(category.name) }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(categories[index]) }
                    }
                }
            }
            .navigationTitle("Категории")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
        }
    }
}
