import SwiftUI
import SwiftData
@preconcurrency import Translation

enum DictionaryFilter: Hashable {
    case general
    case category(Category)
    case list(WordList)
    case mistakes
    /// Встроенные слова из списков Oxford 3000/5000; level — один уровень или все
    case oxford(level: String?)
    /// Встроенные слова не из Oxford: фразовые глаголы, выражения, предметы
    case extra
}

struct DictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    /// Читаем только слова выбранного раздела, запросом к базе. Все слова (10 000+ с книгами) не читаем:
    /// на iPhone 12 это ~2 с подвисания при первом открытии «Словаря». И не через @Query — тот перечитывает
    /// при каждой перерисовке, то есть на каждую букву в форме добавления
    @State private var filteredWords: [Word] = []
    /// Список подгружается частями: «Общий» со словами из книг — тысячи слов (~0,8 с на iPhone 12 целиком)
    private static let pageSize = 100
    @State private var pagePredicate: Predicate<Word>?
    @State private var hasMoreWords = false
    /// Слова добавили или удалили, пока «Словарь» был под другой вкладкой, — перечитать при возвращении.
    /// Без этого список перечитывался при каждом переключении на вкладку
    @State private var needsReload = true
    /// Вкладка «Словарь» живёт и под другими экранами — перечитывать базу на каждое сохранение стоит только на экране
    @State private var isOnScreen = false
    /// Сколько слов в каждой теме — считается, только когда открыт список тем
    @State private var categoryCounts: [UUID: Int] = [:]
    @State private var mistakeCount = 0
    /// Такое же слово уже есть (в базе или среди своих) — при добавлении берём его, а не делаем дубль
    @State private var existingMatches: [Word] = []
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
    /// Нажали на строку — карточка слова
    @State private var wordToShow: Word?
    @State private var isShowingSearch = false
    @State private var isShowingScan = false
    @State private var listToRename: WordList?
    @State private var listToDelete: WordList?
    /// Идёт удаление словаря — в словаре из книги тысячи слов, это заметное время
    @State private var isDeletingList = false
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
    /// Кнопка «Перевести» у нового слова — тот же переводчик и те же проверки, что у слов из книг
    @State private var newTranslationConfig: TranslationSession.Configuration?
    @State private var isTranslatingNew = false
    @State private var newTranslationNote: String?
    
    private func reloadWords() {
        mistakeCount = (try? modelContext.fetchCount(FetchDescriptor<Word>(predicate: #Predicate { $0.isMistake }))) ?? 0
        if isDropdownExpanded { reloadCategoryCounts() }
        refilter(keepingLoaded: true)
        refreshExistingMatches()
    }

    /// Первая часть слов раздела; при перечитывании — столько, сколько уже было загружено, чтобы список не прыгал
    private func refilter(keepingLoaded: Bool = false) {
        let predicate: Predicate<Word>
        switch filter {
        case .general:
            predicate = #Predicate { $0.category == nil }
        case .category(let category):
            let catID = category.id
            predicate = #Predicate { $0.category?.id == catID }
        case .list(let list):
            let listID = list.id
            predicate = #Predicate { word in word.lists.contains { $0.id == listID } }
        case .mistakes:
            predicate = #Predicate { $0.isMistake }
        case .oxford(let level):
            let oxford = StudyScope.oxfordTag
            if let level {
                predicate = #Predicate { !$0.isCustom && $0.tags == oxford && $0.cefrLevel == level }
            } else {
                predicate = #Predicate { !$0.isCustom && $0.tags == oxford }
            }
        case .extra:
            let oxford = StudyScope.oxfordTag
            predicate = #Predicate { !$0.isCustom && $0.tags != oxford }
        }
        let limit = keepingLoaded ? max(Self.pageSize, filteredWords.count) : Self.pageSize
        pagePredicate = predicate
        filteredWords = words(matching: predicate, limit: limit)
        hasMoreWords = filteredWords.count == limit
        needsReload = false
    }

    /// Сохранение добавило или удалило слова — список раздела под другой вкладкой устарел
    private static func addsOrRemovesWords(_ notification: Notification) -> Bool {
        [ModelContext.NotificationKey.insertedIdentifiers, .deletedIdentifiers].contains { key in
            let ids = notification.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
            return ids.contains { $0.entityName == "Word" }
        }
    }

    /// Следующая часть — когда долистали до конца загруженного
    private func loadMoreWords() {
        guard hasMoreWords, let pagePredicate else { return }
        let next = words(matching: pagePredicate, limit: Self.pageSize, offset: filteredWords.count)
        filteredWords += next
        hasMoreWords = next.count == Self.pageSize
    }

    /// Слова по запросу, по алфавиту без учёта регистра
    private func words(matching predicate: Predicate<Word>, limit: Int? = nil, offset: Int = 0) -> [Word] {
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\Word.english, comparator: .localizedStandard)])
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Счётчики тем — запросом «сколько», без чтения самих слов (~1 мс на тему)
    private func reloadCategoryCounts() {
        var counts: [UUID: Int] = [:]
        for category in categories {
            let catID = category.id
            counts[catID] = StudyWords.cachedCount("словарь|\(catID)", #Predicate<Word> { $0.category?.id == catID }, in: modelContext)
        }
        categoryCounts = counts
    }

    /// Слово с тем же написанием: как введено, строчными и с заглавной (April, I)
    private func refreshExistingMatches() {
        let typed = newEnglish.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else {
            existingMatches = []
            return
        }
        let lower = typed.lowercased()
        let capitalized = lower.prefix(1).uppercased() + lower.dropFirst()
        existingMatches = words(matching: #Predicate { $0.english == typed || $0.english == lower || $0.english == capitalized })
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
        case .oxford(let level):
            return level.map { "Oxford 5000 · \($0)" } ?? "Oxford 5000"
        case .extra:
            return "Дополнения"
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
                            if case .list(let list) = filter, list.photosData != nil {
                                ListPhotosStrip(list: list)
                                    .padding(.top, 4)
                            }
                            // Встроенные словари только для чтения — добавлять в них нечего
                            if !isBuiltInDictionary {
                                addWordCard
                                    .padding(.top, 4)
                            }
                            
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
                                        .contentShape(Rectangle())
                                        .onTapGesture { wordToShow = word }
                                        .onAppear {
                                            if word.id == filteredWords.last?.id { loadMoreWords() }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    // Прокрутка списка тоже убирает клавиатуру
                    .scrollDismissesKeyboard(.immediately)
                } else {
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Нажатие мимо полей и кнопок — клавиатура прячется
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                if isDropdownExpanded {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDropdownExpanded = false
                    }
                }
            }
        }
        .onAppear {
            isOnScreen = true
            // Ответы в тренировках меняют ошибки — их число и раздел «Ошибки» обновляем всегда, остальное — если менялся состав
            if needsReload || filter == .mistakes {
                reloadWords()
            } else {
                mistakeCount = (try? modelContext.fetchCount(FetchDescriptor<Word>(predicate: #Predicate { $0.isMistake }))) ?? 0
            }
        }
        .onDisappear { isOnScreen = false }
        .onChange(of: filter) { _, _ in refilter() }
        .onChange(of: isDropdownExpanded) { _, expanded in
            if expanded { reloadCategoryCounts() }
        }
        .onChange(of: newEnglish) { _, _ in
            refreshExistingMatches()
            newTranslationNote = nil
        }
        // Любое сохранение (правка, скан, удаление темы со словами) — перечитываем, чтобы не показать удалённые слова.
        // Не на экране — не перечитываем: тренировки сохраняют каждый ответ. Вернутся на «Словарь» — onAppear перечитает
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
            if isOnScreen {
                reloadWords()
            } else if Self.addsOrRemovesWords(notification) {
                needsReload = true
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
        .overlay {
            if isDeletingList {
                ProgressView("Удаляю словарь…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .sheet(isPresented: $isShowingManageCategories) {
            ManageCategoriesView()
        }
        // Правка могла сменить тему или написание — сохраняем, список перечитается
        .sheet(item: $wordToEdit, onDismiss: { try? modelContext.save() }) { word in
            EditWordView(word: word)
        }
        .sheet(item: $wordToShow, onDismiss: { try? modelContext.save() }) { word in
            WordDetailView(word: word)
                .appThemedColorScheme()
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
                        .lineLimit(1)
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
                            // Слова с ошибками — сразу под «Общим»: к ним возвращаются чаще всего
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
                            Divider().padding(.horizontal, 16)
                            
                            builtInRows
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
        case .oxford, .extra: return "books.vertical.fill"
        default: return "folder.fill"
        }
    }

    /// Длинное название словаря (книги) — первые 20 символов и «...»: «Adventures of Huckle... (4 173)»
    static func shortName(_ name: String, limit: Int = 20) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return trimmed.prefix(limit).trimmingCharacters(in: .whitespaces) + "..."
    }

    /// Встроенные словари основной базы: Oxford 5000 (с уровнями) и наши дополнения. Не удаляются и не переименовываются
    private var builtInRows: some View {
        VStack(spacing: 0) {
            builtInRow(.oxford(level: nil), title: "Oxford 5000", count: builtInCount(.oxford(level: nil)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CEFRLevel.allCases.map(\.rawValue).filter { builtInCount(.oxford(level: $0)) > 0 }, id: \.self) { level in
                        let item = DictionaryFilter.oxford(level: level)
                        Button { selectFilterAndClose(item) } label: {
                            Text("\(level) · \(builtInCount(item).formatted())")
                                .scaledFont(size: 13, weight: .semibold)
                                .foregroundColor(filter == item ? .white : .brandDark)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(filter == item ? Color.orange : Color.brandBackground)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 6)
            }
            builtInRow(.extra, title: "Дополнения", count: builtInCount(.extra))
        }
    }

    private func builtInRow(_ item: DictionaryFilter, title: String, count: Int) -> some View {
        let isSelected = filter == item
        return Button(action: { selectFilterAndClose(item) }) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .scaledFont(size: 14)
                    .foregroundColor(.indigo)
                Text("\(title) (\(count.formatted()))")
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

    /// Счётчики встроенных словарей — запомненные запросы «сколько»
    private func builtInCount(_ item: DictionaryFilter) -> Int {
        let oxford = StudyScope.oxfordTag
        switch item {
        case .oxford(let level?):
            return StudyWords.cachedCount("словарь|oxford|\(level)",
                                          #Predicate<Word> { !$0.isCustom && $0.tags == oxford && $0.cefrLevel == level }, in: modelContext)
        case .oxford(nil):
            return StudyWords.cachedCount("словарь|oxford", #Predicate<Word> { !$0.isCustom && $0.tags == oxford }, in: modelContext)
        case .extra:
            return StudyWords.cachedCount("словарь|extra", #Predicate<Word> { !$0.isCustom && $0.tags != oxford }, in: modelContext)
        default:
            return 0
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
                    Text("\(Self.shortName(list.name)) (\(list.words.count.formatted()))")
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
        isDeletingList = true
        Task {
            // Сначала кадр с «Удаляю словарь…», потом работа на главном потоке
            try? await Task.sleep(for: .milliseconds(50))
            let onlyHere = list.words.filter { $0.isCustom && $0.category == nil && $0.lists.count == 1 }
            // Отвязываем все слова разом: при удалении по одному каждое перестраивало список слов словаря,
            // и словарь из книги (тысячи слов) вешал приложение
            list.words = []
            for word in onlyHere { modelContext.delete(word) }
            studyScope.enabledLists.remove(list.id)
            if filter == .list(list) { filter = .general }
            modelContext.delete(list)
            try? modelContext.save()
            isDeletingList = false
        }
    }

    /// Переносит слова в другой свой словарь (без повторов) и удаляет исходный; сами слова не удаляются
    private func merge(_ source: WordList, into target: WordList) {
        for word in Array(source.words) where !word.lists.contains(where: { $0.id == target.id }) {
            word.lists.append(target)
        }
        for photo in source.photos { target.addPhoto(photo) }
        // Был включён в изучение — включаем словарь, в который перешли слова
        if studyScope.enabledLists.remove(source.id) != nil {
            studyScope.enabledLists.insert(target.id)
        }
        if filter == .list(source) { filter = .list(target) }
        modelContext.delete(source)
        try? modelContext.save()
    }

    private var isBuiltInDictionary: Bool {
        switch filter {
        case .oxford, .extra: return true
        default: return false
        }
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
            HStack(spacing: 10) {
                customTextField(placeholder: "Перевод на русский", text: $newRussian)
                translateNewWordButton
            }
            if let newTranslationNote {
                Text(newTranslationNote)
                    .scaledFont(size: 13)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        .translationTask(newTranslationConfig) { session in
            await translateNewWord(with: session)
        }
    }

    private var translateNewWordButton: some View {
        Button {
            newTranslationNote = nil
            if newTranslationConfig == nil {
                newTranslationConfig = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                                        target: Locale.Language(identifier: "ru"))
            } else {
                newTranslationConfig?.invalidate()
            }
        } label: {
            Group {
                if isTranslatingNew {
                    ProgressView()
                } else {
                    Image(systemName: "character.bubble")
                        .scaledFont(size: 20, weight: .semibold)
                }
            }
            .foregroundColor(.orange)
            .frame(width: 48, height: 48)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(12)
        }
        .disabled(newEnglish.trimmingCharacters(in: .whitespaces).isEmpty || isTranslatingNew)
        .accessibilityLabel("Перевести")
    }

    private func translateNewWord(with session: TranslationSession) async {
        let word = newEnglish.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }
        isTranslatingNew = true
        defer { isTranslatingNew = false }
        do {
            let result = try await WordTranslator.translate(word, session: session)
            newRussian = result.text
            if result.doubtful {
                newTranslationNote = result.text.isEmpty
                    ? "Подходящего перевода нет — впишите свой."
                    : "Перевод под вопросом — проверьте."
            }
        } catch {
            newTranslationNote = "Переводчик недоступен — проверьте, скачан ли русский язык в настройках iPhone «Перевод»."
        }
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
        newTranslationNote = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
