import SwiftUI
import SwiftData

enum DictionaryFilter: Equatable {
    case general
    case category(Category)
    case mistakes
}

struct DictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Word.english) private var allWords: [Word]
    
    @State private var filter: DictionaryFilter = .general
    @State private var isDropdownExpanded = false
    @State private var isShowingManageCategories = false
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var wordToEdit: Word?
    
    @State private var newEnglish = ""
    @State private var newTranscription = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    
    private var mistakeWords: [Word] {
        allWords.filter { $0.isMistake }
    }
    
    var filteredWords: [Word] {
        switch filter {
        case .general:
            return allWords.filter { $0.category == nil }
        case .category(let category):
            let catID = category.id
            return allWords.filter { $0.category?.id == catID }
        case .mistakes:
            return mistakeWords
        }
    }
    
    private var currentCategoryForNewWord: Category? {
        if case .category(let cat) = filter {
            return cat
        }
        return nil
    }
    
    private var dropdownTitle: String {
        switch filter {
        case .general:
            return "Общий словарь"
        case .category(let category):
            return category.name
        case .mistakes:
            return "⚠️ Слова с ошибками (\(mistakeWords.count))"
        }
    }
    
    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()
            
            // Главный контейнер ловит тапы на любом пустом месте экрана
            VStack(spacing: 12) {
                customHeader
                
                categoryDropdownCard
                    .padding(.horizontal, 16)
                
                if !isDropdownExpanded {
                    // Переносим ScrollView так, чтобы он включал в себя и поля ввода
                    ScrollView {
                        VStack(spacing: 12) {
                            addWordCard
                                .padding(.top, 4) // Небольшой отступ сверху
                            
                            if filteredWords.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: filter == .mistakes ? "checkmark.circle.fill" : "doc.text.magnifyingglass")
                                        .font(.system(size: 44))
                                        .foregroundColor(filter == .mistakes ? .green : .gray)
                                    Text(filter == .mistakes ? "В этом разделе нет ошибочных слов!" : "В выбранном разделе нет слов.")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(.top, 30)
                            } else {
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
                } else {
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isDropdownExpanded {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDropdownExpanded = false
                    }
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
                    filter = .category(newCat)
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
            Button(action: { dismiss() }) {
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
                    Image(systemName: filter == .mistakes ? "exclamationmark.triangle.fill" : "folder.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 18))
                    Text(dropdownTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.brandDark)
                    Spacer()
                    Image(systemName: isDropdownExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(16)
            }
            if isDropdownExpanded {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            Button(action: { selectFilterAndClose(.general) }) {
                                HStack {
                                    Text("Общий").font(.system(size: 16, weight: .bold)).foregroundColor(filter == .general ? .orange : .brandDark)
                                    Spacer()
                                    if filter == .general { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(.orange) }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                            Divider().padding(.horizontal, 16)
                            
                            ForEach(categories) { category in
                                let isSelected = filter == .category(category)
                                Button(action: { selectFilterAndClose(.category(category)) }) {
                                    HStack {
                                        Text("\(category.name) (\(countWords(for: category)))")
                                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                                            .foregroundColor(isSelected ? .orange : .brandDark)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                }
                            }
                            Divider().padding(.horizontal, 16)
                            
                            Button(action: { selectFilterAndClose(.mistakes) }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 15))
                                    Text("Слова с ошибками (\(mistakeWords.count))")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.orange)
                                    Spacer()
                                    if filter == .mistakes {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                        }
                    }
                    .frame(maxHeight: 440)
                    
                    Divider().padding(.horizontal, 16)
                    
                    Button(action: { isDropdownExpanded = false; isShowingAddCategoryAlert = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus").font(.system(size: 16))
                            Text("Создать новую папку...").font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(Color(red: 0/255, green: 112/255, blue: 243/255))
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    Button(action: {
                        isDropdownExpanded = false
                        isShowingManageCategories = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.badge.gearshape").font(.system(size: 16))
                            Text("Управление папками...").font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.gray).padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    private func selectFilterAndClose(_ selectedFilter: DictionaryFilter) {
        withAnimation(.easeInOut(duration: 0.2)) {
            filter = selectedFilter
            isDropdownExpanded = false
        }
    }
    
    // ВЫРАЗИТЕЛЬНАЯ КАРТОЧКА ДОБАВЛЕНИЯ СЛОВ
    private var addWordCard: some View {
        VStack(spacing: 14) {
            customTextField(placeholder: "Слово на английском", text: $newEnglish)
            customTextField(placeholder: "Транскрипция (необязательно)", text: $newTranscription)
            customTextField(placeholder: "Перевод на русский", text: $newRussian)
            customTextField(placeholder: "Пример фразы (необязательно)", text: $newExample)
            
            Button(action: addNewWord) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Добавить в \(currentCategoryForNewWord?.name ?? "Общий")")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(newEnglish.isEmpty || newRussian.isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                .cornerRadius(14)
            }
            .disabled(newEnglish.isEmpty || newRussian.isEmpty)
        }
        .padding(18)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // ВЫРАЗИТЕЛЬНОЕ И ЯРКОЕ ТЕКСТОВОЕ ПОЛЕ
    private func customTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            // Используем системный цвет systemGray5, который в темной теме значительно ярче вашего brandInputBg
            .background(Color(.systemGray5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    // Увеличили прозрачность рамки с 0.1 до 0.25 для максимальной выразительности границ
                    .stroke(Color.brandDark.opacity(0.25), lineWidth: 1.5)
            )
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
            transcription: trans,
            example: newExample.trimmingCharacters(in: .whitespaces),
            category: currentCategoryForNewWord
        )
        
        modelContext.insert(word)
        newEnglish = ""
        newTranscription = ""
        newRussian = ""
        newExample = ""
        
        // Скрываем клавиатуру
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func countWords(for category: Category) -> Int {
        let catID = category.id
        return allWords.filter { $0.category?.id == catID }.count
    }
}

// MARK: - Вспомогательные представления

struct WordRowCard: View {
    let word: Word
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.english)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                    
                    if !word.transcription.isEmpty {
                        Text(word.transcription)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
                
                Text(word.russian)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                
                if !word.example.isEmpty {
                    Text(word.example)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            Button(action: {
                TextToSpeechManager.shared.speak(word.english)
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            
            Button(action: onEdit) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    Text(category.name)
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Управление папками")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}
