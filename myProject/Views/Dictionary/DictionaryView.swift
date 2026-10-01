import SwiftUI
import SwiftData

enum DictionaryFilter: Equatable {
    case general
    case category(Category)
    case list(WordList)
    case mistakes
}

struct DictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Word.english) private var allWords: [Word]
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    
    @State private var filter: DictionaryFilter = .general
    @State private var isDropdownExpanded = false
    @State private var isShowingManageCategories = false
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var wordToEdit: Word?
    @State private var isShowingSearch = false
    @State private var listToRename: WordList?
    @State private var listToDelete: WordList?
    @State private var listName = ""
    
    @State private var newEnglish = ""
    @State private var newTranscription = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    @State private var newLevel: String = "A1"
    
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
        case .list(let list):
            return list.words.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .mistakes:
            return mistakeWords
        }
    }
    
    private var addTargetName: String {
        if case .list(let list) = filter { return list.name }
        return currentCategoryForNewWord?.name ?? "Общий"
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
        case .list(let list):
            return list.name
        case .mistakes:
            return "⚠️ Слова с ошибками (\(mistakeWords.count))"
        }
    }
    
    private func countWords(for category: Category) -> Int {
        let catID = category.id
        return allWords.filter { $0.category?.id == catID }.count
    }
    
    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()
            
            VStack(spacing: 12) {
                customHeader
                
                categoryDropdownCard
                    .padding(.horizontal, 16)
                
                if !isDropdownExpanded {
                    ScrollView {
                        VStack(spacing: 12) {
                            addWordCard
                                .padding(.top, 4)
                            
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
        .alert("Переименовать словарь", isPresented: Binding(get: { listToRename != nil }, set: { if !$0 { listToRename = nil } })) {
            TextField("Название", text: $listName)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                let trimmed = listName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { listToRename?.name = trimmed }
            }
        }
        .alert("Удалить словарь «\(listToDelete?.name ?? "")»?", isPresented: Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let list = listToDelete { delete(list) }
            }
        } message: {
            Text("Новые слова, добавленные только в этот словарь, тоже удалятся. Слова из основной базы останутся в своих темах.")
        }
        .sheet(isPresented: $isShowingManageCategories) {
            ManageCategoriesView()
        }
        .sheet(item: $wordToEdit) { word in
            EditWordView(word: word)
        }
        .sheet(isPresented: $isShowingSearch) {
            WordSearchView()
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
            HStack(spacing: 18) {
                Button(action: { isShowingSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
                .accessibilityLabel("Поиск слов")
                Button(action: { isShowingManageCategories = true }) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var categoryDropdownCard: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDropdownExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: dropdownIcon)
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
                            
                            if !lists.isEmpty {
                                myListsRows
                                Divider().padding(.horizontal, 16)
                            }
                            
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
    
    private var dropdownIcon: String {
        switch filter {
        case .mistakes: return "exclamationmark.triangle.fill"
        case .list: return "text.book.closed.fill"
        default: return "folder.fill"
        }
    }

    /// Свои словари (например, из скана текста) — над темами; долгое нажатие: переименовать или удалить
    private var myListsRows: some View {
        ForEach(lists) { list in
            let isSelected = filter == .list(list)
            Button(action: { selectFilterAndClose(.list(list)) }) {
                HStack(spacing: 8) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.teal)
                    Text("\(list.name) (\(list.words.count))")
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
            .contextMenu {
                Button {
                    listName = list.name
                    listToRename = list
                } label: { Label("Переименовать", systemImage: "pencil") }
                Button(role: .destructive) { listToDelete = list } label: { Label("Удалить", systemImage: "trash") }
            }
        }
    }

    /// Удаляет словарь и свои слова, которые были только в нём; встроенные слова остаются в своих темах
    private func delete(_ list: WordList) {
        for word in list.words where word.isCustom && word.category == nil && word.lists.count == 1 {
            modelContext.delete(word)
        }
        studyScope.enabledLists.remove(list.id)
        if filter == .list(list) { filter = .general }
        modelContext.delete(list)
        try? modelContext.save()
    }

    private func selectFilterAndClose(_ selectedFilter: DictionaryFilter) {
        withAnimation(.easeInOut(duration: 0.2)) {
            filter = selectedFilter
            isDropdownExpanded = false
        }
    }
    
    private var addWordCard: some View {
        VStack(spacing: 14) {
            customTextField(placeholder: "Слово на английском", text: $newEnglish)
            customTextField(placeholder: "Транскрипция (необязательно)", text: $newTranscription)
            customTextField(placeholder: "Перевод на русский", text: $newRussian)
            customTextField(placeholder: "Пример фразы (необязательно)", text: $newExample)
            
            Picker("Уровень", selection: $newLevel) {
                ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                    Text(level.rawValue).tag(level.rawValue)
                }
            }
            .pickerStyle(.segmented)
            
            Button(action: addNewWord) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Добавить в \(addTargetName)")
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
    
    private func customTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray5))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandDark.opacity(0.25), lineWidth: 1.5)
            )
    }

    private func addNewWord() {
        let trimmedEng = newEnglish.trimmingCharacters(in: .whitespaces)
        let trimmedRus = newRussian.trimmingCharacters(in: .whitespaces)

        guard !trimmedEng.isEmpty && !trimmedRus.isEmpty else { return }

        let word = Word(
            english: trimmedEng,
            russian: trimmedRus,
            transcription: Word.bareTranscription(newTranscription),
            example: newExample.trimmingCharacters(in: .whitespaces),
            category: currentCategoryForNewWord,
            cefrLevel: newLevel,
            isCustom: true
        )
        
        modelContext.insert(word)
        if case .list(let list) = filter {
            word.lists.append(list)
        }
        newEnglish = ""
        newTranscription = ""
        newRussian = ""
        newExample = ""
        
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
