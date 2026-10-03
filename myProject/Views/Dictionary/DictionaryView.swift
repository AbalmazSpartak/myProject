import SwiftUI
import SwiftData

enum DictionaryFilter: Hashable {
    case general
    case category(Category)
    case list(WordList)
    case mistakes
}

struct DictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    /// Слова читаем при открытии и после сохранения базы, а не через @Query:
    /// тот перечитывает все слова при каждой перерисовке, то есть на каждую букву в форме добавления
    @State private var allWords: [Word] = []
    @State private var filteredWords: [Word] = []
    @State private var categoryCounts: [UUID: Int] = [:]
    @State private var mistakeCount = 0
    /// Слова по написанию (нижний регистр) — чтобы при добавлении брать слово из базы, а не делать дубль
    @State private var wordsByEnglish: [String: [Word]] = [:]
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    
    @State private var filter: DictionaryFilter

    /// `initialFilter` — открыть сразу нужную подборку (например, из «Подборок сообщества»)
    /// Во вкладке «Словарь» возвращаться некуда; из подборки на «Обзоре» — кнопка «Обзор»
    private let showsBackButton: Bool

    private let backTitle: String

    init(initialFilter: DictionaryFilter = .general, showsBackButton: Bool = true, backTitle: String = "Обзор") {
        _filter = State(initialValue: initialFilter)
        self.showsBackButton = showsBackButton
        self.backTitle = backTitle
    }
    @State private var isDropdownExpanded = false
    @State private var isShowingManageCategories = false
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var wordToEdit: Word?
    @State private var isShowingSearch = false
    @State private var isShowingScan = false
    @State private var listToRename: WordList?
    @State private var listToDelete: WordList?
    @State private var listName = ""
    @State private var listMerge: ListMerge?

    /// Переименование своего словаря в название другого своего словаря
    private struct ListMerge {
        let source: WordList
        let target: WordList
    }
    
    @State private var newEnglish = ""
    @State private var newTranscription = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    @State private var newLevel: String = "A1"
    
    private func reloadWords() {
        allWords = modelContext.fetchAllWords(sortBy: [SortDescriptor(\Word.english)])
        var counts: [UUID: Int] = [:]
        for word in allWords {
            if let id = word.category?.id { counts[id, default: 0] += 1 }
        }
        categoryCounts = counts
        mistakeCount = allWords.count(where: \.isMistake)
        wordsByEnglish = Dictionary(grouping: allWords) { $0.english.lowercased() }
        refilter()
    }

    private func refilter() {
        switch filter {
        case .general:
            filteredWords = allWords.filter { $0.category == nil }
        case .category(let category):
            let catID = category.id
            filteredWords = allWords.filter { $0.category?.id == catID }
        case .list(let list):
            filteredWords = list.words.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .mistakes:
            filteredWords = allWords.filter { $0.isMistake }
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
            return "⚠️ Слова с ошибками (\(mistakeCount))"
        }
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
                                        .scaledFont(size: 15, weight: .medium)
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
        .onAppear(perform: reloadWords)
        .onChange(of: filter) { _, _ in refilter() }
        // Любое сохранение (правка, скан, удаление темы со словами) — перечитываем, чтобы не показать удалённые слова
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in reloadWords() }
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
                guard !trimmed.isEmpty, let list = listToRename else { return }
                // Такое название уже у другого своего словаря — предлагаем объединить, а не заводить второй
                if let existing = lists.first(where: {
                    $0.id != list.id && $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(trimmed) == .orderedSame
                }) {
                    listMerge = ListMerge(source: list, target: existing)
                } else {
                    list.name = trimmed
                }
            }
        }
        .alert("Словарь «\(listMerge?.target.name ?? "")» уже есть", isPresented: Binding(get: { listMerge != nil }, set: { if !$0 { listMerge = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Объединить") {
                if let merge = listMerge { self.merge(merge.source, into: merge.target) }
            }
        } message: {
            Text("Слова из «\(listMerge?.source.name ?? "")» перейдут в него, без повторов, а «\(listMerge?.source.name ?? "")» удалится.")
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
        // Правка могла сменить тему или написание — сохраняем, список перечитается
        .sheet(item: $wordToEdit, onDismiss: { try? modelContext.save() }) { word in
            EditWordView(word: word)
        }
        .sheet(isPresented: $isShowingSearch, onDismiss: { try? modelContext.save() }) {
            WordSearchView()
        }
        .fullScreenCover(isPresented: $isShowingScan) {
            TextScanView { list in
                filter = .list(list)
            }
        }
    }

    
    private var customHeader: some View {
        HStack {
            if showsBackButton {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) { Image(systemName: "chevron.left"); Text(backTitle) }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.orange)
                }
            }
            Spacer()
            HStack(spacing: 18) {
                HelpButton(topic: .dictionary)
                Button(action: { isShowingSearch = true }) {
                    Image(systemName: "magnifyingglass")
                        .scaledFont(size: 20)
                        .foregroundColor(.orange)
                }
                .accessibilityLabel("Поиск слов")
                Button(action: { isShowingScan = true }) {
                    Image(systemName: "text.viewfinder")
                        .scaledFont(size: 20)
                        .foregroundColor(.orange)
                }
                .accessibilityLabel("Слова из текста")
                Button(action: { isShowingManageCategories = true }) {
                    Image(systemName: "doc.badge.plus")
                        .scaledFont(size: 20)
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
                        .scaledFont(size: 18)
                    Text(dropdownTitle)
                        .scaledFont(size: 17, weight: .bold)
                        .foregroundColor(.brandDark)
                    Spacer()
                    Image(systemName: isDropdownExpanded ? "chevron.up" : "chevron.down")
                        .scaledFont(size: 14, weight: .semibold)
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
                                    Text("Общий").scaledFont(size: 16, weight: .bold).foregroundColor(filter == .general ? .orange : .brandDark)
                                    Spacer()
                                    if filter == .general { Image(systemName: "checkmark").scaledFont(size: 14, weight: .bold).foregroundColor(.orange) }
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
                                        Text("\(category.name) (\(categoryCounts[category.id, default: 0]))")
                                            .scaledFont(size: 16, weight: isSelected ? .bold : .semibold)
                                            .foregroundColor(isSelected ? .orange : .brandDark)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .scaledFont(size: 14, weight: .bold)
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
                                        .scaledFont(size: 15)
                                    Text("Слова с ошибками (\(mistakeCount))")
                                        .scaledFont(size: 16, weight: .bold)
                                        .foregroundColor(.orange)
                                    Spacer()
                                    if filter == .mistakes {
                                        Image(systemName: "checkmark")
                                            .scaledFont(size: 14, weight: .bold)
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
                            Image(systemName: "folder.badge.plus").scaledFont(size: 16)
                            Text("Создать новую папку...").scaledFont(size: 15, weight: .semibold)
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
                            Image(systemName: "folder.badge.gearshape").scaledFont(size: 16)
                            Text("Управление папками...").scaledFont(size: 15, weight: .semibold)
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
                        .scaledFont(size: 14)
                        .foregroundColor(.teal)
                    Text("\(list.name) (\(list.words.count))")
                        .scaledFont(size: 16, weight: isSelected ? .bold : .semibold)
                        .foregroundColor(isSelected ? .orange : .brandDark)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .scaledFont(size: 14, weight: .bold)
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

    /// Переносит слова в другой свой словарь (без повторов) и удаляет исходный; сами слова не удаляются
    private func merge(_ source: WordList, into target: WordList) {
        for word in Array(source.words) where !word.lists.contains(where: { $0.id == target.id }) {
            word.lists.append(target)
        }
        // Был включён в изучение — включаем словарь, в который перешли слова
        if studyScope.enabledLists.remove(source.id) != nil {
            studyScope.enabledLists.insert(target.id)
        }
        if filter == .list(source) { filter = .list(target) }
        modelContext.delete(source)
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
            if !existingMatches.isEmpty {
                existingMatchesCard
            }
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
                        .scaledFont(size: 16, weight: .bold)
                    Text("Добавить в \(addTargetName)")
                        .scaledFont(size: 16, weight: .bold, design: .rounded)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canAddNewWord ? Color.orange : Color.gray.opacity(0.3))
                .cornerRadius(14)
            }
            .disabled(!canAddNewWord)
        }
        .padding(18)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    /// Такое же слово уже есть (в базе или среди своих) — по написанию без учёта регистра
    private var existingMatches: [Word] {
        let key = newEnglish.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return [] }
        return wordsByEnglish[key] ?? []
    }

    private var canAddNewWord: Bool {
        !newEnglish.trimmingCharacters(in: .whitespaces).isEmpty
            && !newRussian.trimmingCharacters(in: .whitespaces).isEmpty
            && existingMatches.isEmpty
    }

    /// Вместо дубля — взять слово из базы: в свой словарь добавить ссылку, в темах — открыть правку
    private var existingMatchesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Уже есть")
                .scaledFont(size: 14, weight: .bold, design: .rounded)
                .foregroundColor(.orange)

            ForEach(existingMatches.prefix(3)) { word in
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(word.english)\(word.partOfSpeech.isEmpty ? "" : " (\(word.partOfSpeech))") — \(word.russian)")
                            .scaledFont(size: 15, weight: .semibold, design: .rounded)
                            .foregroundColor(.brandDark)
                        Text(matchDetails(word))
                            .scaledFont(size: 12, weight: .medium, design: .rounded)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    matchAction(for: word)
                }
            }

            // Нужного значения нет (bank — «берег», а в базе только «банк») — своё слово, но только явно
            Button("Другое значение — добавить своё", action: addNewWord)
                .scaledFont(size: 13, weight: .semibold, design: .rounded)
                .foregroundColor(.gray)
                .disabled(newRussian.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
    }

    private func matchDetails(_ word: Word) -> String {
        let place = word.category.map { "тема «\($0.name)»" } ?? (word.isCustom ? "ваше слово" : "Общий")
        return "\(word.cefrLevel) · \(place)"
    }

    @ViewBuilder
    private func matchAction(for word: Word) -> some View {
        if case .list(let list) = filter {
            if word.lists.contains(where: { $0.id == list.id }) {
                Text("уже в словаре")
                    .scaledFont(size: 12, weight: .medium, design: .rounded)
                    .foregroundColor(.gray)
            } else {
                Button("Добавить") { add(word, to: list) }
                    .scaledFont(size: 14, weight: .bold, design: .rounded)
                    .foregroundColor(.orange)
            }
        } else {
            Button("Открыть") { wordToEdit = word }
                .scaledFont(size: 14, weight: .bold, design: .rounded)
                .foregroundColor(.orange)
        }
    }

    /// Ссылка на существующее слово в своём словаре — без копии
    private func add(_ word: Word, to list: WordList) {
        word.lists.append(list)
        try? modelContext.save()
        clearNewWordForm()
    }

    private func customTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .scaledFont(size: 16, weight: .medium, design: .rounded)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.brandFill)
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
        try? modelContext.save()
        clearNewWordForm()
    }

    private func clearNewWordForm() {
        newEnglish = ""
        newTranscription = ""
        newRussian = ""
        newExample = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
