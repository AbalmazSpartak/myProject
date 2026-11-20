import SwiftUI
import SwiftData

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

/// С какого места открыть «Папки»
enum FoldersStart: Identifiable {
    case root, topics

    var id: Self { self }
}

/// «Словарь» по дизайну LexiStream: чипы списка, папок и ошибок, поиск, состояния слов, список или таблица
struct DictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    /// Читаем только слова выбранного раздела, запросом к базе. Все слова (10 000+ с книгами) не читаем:
    /// на iPhone 12 это ~2 с подвисания при первом открытии «Словаря». И не через @Query — тот перечитывает
    /// при каждой перерисовке
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
    /// Первое чтение прошло — до него не показываем «пустой словарь»
    @State private var hasLoaded = false
    @State private var mistakeCount = 0
    /// Сколько слов в выбранном разделе (с учётом уровня) — число на чипе списка
    @State private var totalCount = 0

    @State private var filter: DictionaryFilter
    /// Фильтры под поиском: состояние слова и уровень
    @State private var statusFilter: WordStatus?
    @State private var levelFilter: String?
    @AppStorage("dictionary_table_mode") private var tableMode = false
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning

    /// `initialFilter` — открыть сразу нужную подборку (например, из «Подборок сообщества»)
    /// Во вкладке «Словарь» возвращаться некуда; из подборки на «Обзоре» — кнопка «Обзор»
    private let showsBackButton: Bool
    private let backTitle: String

    init(initialFilter: DictionaryFilter = .general, showsBackButton: Bool = true, backTitle: String = "Обзор") {
        _filter = State(initialValue: initialFilter)
        self.showsBackButton = showsBackButton
        self.backTitle = backTitle
    }

    /// Открытые «Папки»: с начала или сразу на «Темах»
    @State private var foldersStart: FoldersStart?
    @State private var isShowingAddWord = false
    @State private var isShowingSearch = false
    @State private var isShowingScan = false
    @State private var wordToEdit: Word?
    /// Нажали на строку — карточка слова
    @State private var wordToShow: Word?

    // MARK: - Чтение слов

    private func reloadWords() {
        mistakeCount = DictionaryCounts.mistakes(in: modelContext)
        refilter(keepingLoaded: true)
    }

    /// Условие выбранного раздела
    private func scopePredicate() -> Predicate<Word> {
        switch filter {
        case .general:
            return #Predicate<Word> { $0.category == nil }
        case .category(let category):
            let catID = category.id
            return #Predicate<Word> { $0.category?.id == catID }
        case .list(let list):
            let listID = list.id
            return #Predicate<Word> { word in word.lists.contains { $0.id == listID } }
        case .mistakes:
            return #Predicate<Word> { $0.isMistake }
        case .oxford(let level):
            let oxford = StudyScope.oxfordTag
            if let level {
                return #Predicate<Word> { !$0.isCustom && $0.tags == oxford && $0.cefrLevel == level }
            }
            return #Predicate<Word> { !$0.isCustom && $0.tags == oxford }
        case .extra:
            let oxford = StudyScope.oxfordTag
            return #Predicate<Word> { !$0.isCustom && $0.tags != oxford }
        }
    }

    /// Первая часть слов раздела; при перечитывании — столько, сколько уже было загружено, чтобы список не прыгал
    private func refilter(keepingLoaded: Bool = false) {
        var base = scopePredicate()
        if let level = levelFilter {
            base = StudyWords.all(base, #Predicate<Word> { $0.cefrLevel == level })
        }
        totalCount = StudyWords.count(base, in: modelContext)

        if statusFilter == .learning || statusFilter == .known {
            // Состояние FSRS в запросе к базе не сравнить — берём начатые слова раздела (их сотни, а не тысячи)
            // и отбираем по состоянию
            let started = StudyWords.all(base, #Predicate<Word> { $0.reps > 0 })
            let target = statusFilter
            pagePredicate = nil
            filteredWords = words(matching: started).filter { $0.studyStatus == target }
            hasMoreWords = false
        } else {
            var predicate = base
            if statusFilter == .new {
                predicate = StudyWords.all(base, #Predicate<Word> { $0.reps == 0 })
            }
            let limit = keepingLoaded ? max(Self.pageSize, filteredWords.count) : Self.pageSize
            pagePredicate = predicate
            filteredWords = words(matching: predicate, limit: limit)
            hasMoreWords = filteredWords.count == limit
        }
        needsReload = false
        hasLoaded = true
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

    // MARK: - Названия

    /// Длинное название словаря (книги) — первые 20 символов и «...»: «Adventures of Huckle...»
    static func shortName(_ name: String, limit: Int = 20) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return trimmed.prefix(limit).trimmingCharacters(in: .whitespaces) + "..."
    }

    private var filterTitle: String {
        switch filter {
        case .general: "Общий"
        case .category(let category): category.name
        case .list(let list): Self.shortName(list.name)
        case .mistakes: "С ошибками"
        case .oxford(let level): level.map { "Oxford · \($0)" } ?? "Oxford 5000"
        case .extra: "Дополнения"
        }
    }

    /// Новое слово попадает в открытую папку или словарь; из остальных разделов — в «Общий»
    private var addTargetName: String {
        if case .list(let list) = filter { return list.name }
        return currentCategoryForNewWord?.name ?? "Общий"
    }

    private var currentCategoryForNewWord: Category? {
        if case .category(let category) = filter { return category }
        return nil
    }

    private var currentListForNewWord: WordList? {
        if case .list(let list) = filter { return list }
        return nil
    }

    /// Папки пользователя — без тем встроенной базы
    private var userFolders: [Category] {
        let names = DataPreloader.bundledTopicNames
        return categories.filter { !names.contains($0.name) }
    }

    /// Совсем пустой «Общий»: показываем приглашение вместо списка
    private var showsEmptyState: Bool {
        hasLoaded && filteredWords.isEmpty && filter == .general && statusFilter == nil && levelFilter == nil
    }

    // MARK: - Экран

    var body: some View {
        VStack(spacing: 0) {
            header
            if showsEmptyState {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        controls
                        wordsList
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            isOnScreen = true
            // Ответы в тренировках меняют ошибки — их число и раздел «Ошибки» обновляем всегда, остальное — если менялся состав
            if needsReload || filter == .mistakes {
                reloadWords()
            } else {
                mistakeCount = DictionaryCounts.mistakes(in: modelContext)
            }
        }
        .onDisappear { isOnScreen = false }
        .onChange(of: filter) { _, _ in refilter() }
        .onChange(of: statusFilter) { _, _ in refilter() }
        .onChange(of: levelFilter) { _, _ in refilter() }
        // Любое сохранение (правка, скан, удаление темы со словами) — перечитываем, чтобы не показать удалённые слова.
        // Не на экране — не перечитываем: тренировки сохраняют каждый ответ. Вернутся на «Словарь» — onAppear перечитает
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
            if isOnScreen {
                reloadWords()
            } else if Self.addsOrRemovesWords(notification) {
                needsReload = true
            }
        }
        .sheet(item: $foldersStart) { start in
            FoldersView(filter: $filter, startsOnTopics: start == .topics)
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingAddWord, onDismiss: { modelContext.saveReporting() }) {
            AddWordView(category: currentCategoryForNewWord, list: currentListForNewWord, targetName: addTargetName)
                .appThemedColorScheme()
        }
        // Правка могла сменить тему или написание — сохраняем, список перечитается
        .sheet(item: $wordToEdit, onDismiss: { modelContext.saveReporting() }) { word in
            EditWordView(word: word)
                .appThemedColorScheme()
        }
        .sheet(item: $wordToShow, onDismiss: { modelContext.saveReporting() }) { word in
            WordDetailView(word: word)
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingSearch, onDismiss: { modelContext.saveReporting() }) {
            WordSearchView()
                .appThemedColorScheme()
        }
        .fullScreenCover(isPresented: $isShowingScan) {
            TextScanView { list in
                filter = .list(list)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            if showsBackButton {
                LXBackButton(label: backTitle) { dismiss() }
            }
            Text("Словарь")
                .scaledFont(size: 32, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
            Spacer(minLength: 8)
            Button { tableMode.toggle() } label: {
                LXIconLabel(systemImage: tableMode ? "list.bullet" : "tablecells",
                            label: tableMode ? "Режим ленты" : "Режим таблицы")
            }
            .buttonStyle(.plain)
            Menu {
                Button { isShowingAddWord = true } label: { Label("Добавить слово", systemImage: "plus") }
                Button { isShowingScan = true } label: { Label("Слова из текста", systemImage: "text.viewfinder") }
            } label: {
                LXIconLabel(systemImage: "plus", label: "Добавить", isSoft: true)
            }
        }
        .padding(.leading, showsBackButton ? 8 : 16)
        .padding(.trailing, 8)
        .frame(minHeight: 52)
    }

    /// Чипы списка, папок и ошибок, поиск, состояния слов и заголовок списка
    private var controls: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Menu {
                        quickPickMenu
                    } label: {
                        LXChipLabel(title: filterTitle, detail: "· \(totalCount.formatted())", isOn: true, chevron: true)
                    }
                    .frame(maxWidth: 190)
                    .padding(.vertical, 4)
                    LXChip(title: "Папки", systemImage: "folder") { foldersStart = .root }
                    LXChip(title: "С ошибками", systemImage: "flag", isOn: filter == .mistakes) {
                        filter = filter == .mistakes ? .general : .mistakes
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 2)

            Button { isShowingSearch = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").scaledFont(size: 17)
                    Text("Искать в словаре").scaledFont(size: 16)
                    Spacer()
                }
                .foregroundStyle(Color.brandMuted)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .accessibilityLabel("Искать в словаре")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LXChip(title: "Все", isOn: statusFilter == nil) { statusFilter = nil }
                    ForEach(WordStatus.allCases) { status in
                        LXChip(title: status.title, status: status, isOn: statusFilter == status) {
                            statusFilter = statusFilter == status ? nil : status
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 8)

            HStack {
                LXSectionLabel(text: "По алфавиту")
                Spacer()
                levelMenu
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .frame(minHeight: 44)
        }
    }

    /// Быстрый выбор списка; полный перечень — в «Папках»
    @ViewBuilder
    private var quickPickMenu: some View {
        pickButton("Общий", systemImage: "book.closed", item: .general)
        pickButton("Слова с ошибками (\(mistakeCount))", systemImage: "flag", item: .mistakes)
        if !lists.isEmpty || !userFolders.isEmpty {
            Divider()
            ForEach(lists.prefix(6)) { list in
                pickButton(Self.shortName(list.name), systemImage: "text.book.closed", item: .list(list))
            }
            ForEach(userFolders.prefix(6)) { folder in
                pickButton(folder.name, systemImage: "folder", item: .category(folder))
            }
        }
        Divider()
        pickButton("Oxford 5000", systemImage: "books.vertical", item: .oxford(level: nil))
        pickButton("Дополнения", systemImage: "books.vertical", item: .extra)
        Button { foldersStart = .topics } label: { Label("Темы…", systemImage: "square.grid.2x2") }
        Button { foldersStart = .root } label: { Label("Все папки…", systemImage: "folder.badge.gearshape") }
    }

    private func pickButton(_ title: String, systemImage: String, item: DictionaryFilter) -> some View {
        Button { filter = item } label: {
            Label(title, systemImage: filter == item ? "checkmark" : systemImage)
        }
    }

    /// Уровень слов: A1–C2 или один
    private var levelMenu: some View {
        Menu {
            levelButton("Все уровни", level: nil)
            ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                levelButton(level.rawValue, level: level.rawValue)
            }
        } label: {
            HStack(spacing: 4) {
                Text(levelFilter ?? "A1–C2")
                Image(systemName: "line.3.horizontal.decrease")
            }
            .scaledFont(size: 13, weight: .medium)
            .foregroundStyle(levelFilter == nil ? Color.brandMuted : Color.brandTint)
            .frame(minHeight: 44)
        }
        .accessibilityLabel("Уровень слов")
    }

    private func levelButton(_ title: String, level: String?) -> some View {
        Button { levelFilter = level } label: {
            if levelFilter == level {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    // MARK: - Список

    @ViewBuilder
    private var wordsList: some View {
        if filteredWords.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: filter == .mistakes ? "checkmark.circle" : "tray")
                    .scaledFont(size: 40)
                    .foregroundStyle(filter == .mistakes ? Color.statusKnown : Color.brandMuted)
                Text(filter == .mistakes ? "Слов с ошибками нет" : "В этом разделе пока нет слов")
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundStyle(Color.brandMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        } else {
            if tableMode { LXTableHeader() }
            LazyVStack(spacing: 0) {
                ForEach(filteredWords) { word in
                    Group {
                        if tableMode { LXTableRow(word: word) } else { LXWordRow(word: word) }
                    }
                    .onTapGesture { wordToShow = word }
                    .contextMenu {
                        Button { wordToEdit = word } label: { Label("Изменить", systemImage: "pencil") }
                        // Открыт свой словарь — слово можно убрать из него, не удаляя совсем
                        if case .list(let list) = filter {
                            Button(role: .destructive) {
                                word.lists.removeAll { $0.id == list.id }
                                modelContext.saveReporting()
                            } label: { Label("Удалить из словаря", systemImage: "minus.circle") }
                        }
                    }
                    .onAppear {
                        if word.id == filteredWords.last?.id { loadMoreWords() }
                    }
                }
            }
        }
    }

    /// Пустой словарь: приглашение читать, выбрать слова по уровню или сфотографировать текст
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                OpenBookIllustration()
                    .frame(width: 160, height: 120)
                Text("Здесь появятся ваши слова")
                    .scaledFont(size: 28, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                Text("Читайте книгу и касайтесь незнакомых слов. Каждое сохранится сюда вместе с примером и названием книги.")
                    .scaledFont(size: 15)
                    .foregroundStyle(Color.brandMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                LXButton(title: "Открыть читалку", systemImage: "book.closed") { mode = .reading }
                LXButton(title: "Выбрать слова по уровню", style: .soft) { foldersStart = .root }
                LXButton(title: "Сканировать текст", systemImage: "text.viewfinder", style: .text) { isShowingScan = true }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

/// Раскрытая книга с закладкой — картинка пустого словаря (холст «Словарь»)
struct OpenBookIllustration: View {
    var body: some View {
        ZStack {
            Self.book.fill(Color.brandAccent)
            Self.book.stroke(Color.brandTint, style: Self.style)
            Self.spine.stroke(Color.brandTint, style: Self.style)
            Self.lines.stroke(Color.brandTint, style: Self.style)
            Self.bookmark.stroke(Color.statusLearning, style: Self.style)
        }
        .accessibilityLabel("Раскрытая книга")
    }

    private static let style = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

    private static var book: Path {
        var p = Path()
        p.move(to: CGPoint(x: 80, y: 28))
        p.addCurve(to: CGPoint(x: 18, y: 20), control1: CGPoint(x: 64, y: 16), control2: CGPoint(x: 38, y: 14))
        p.addLine(to: CGPoint(x: 18, y: 94))
        p.addCurve(to: CGPoint(x: 80, y: 102), control1: CGPoint(x: 38, y: 88), control2: CGPoint(x: 64, y: 90))
        p.addCurve(to: CGPoint(x: 142, y: 94), control1: CGPoint(x: 96, y: 90), control2: CGPoint(x: 122, y: 88))
        p.addLine(to: CGPoint(x: 142, y: 20))
        p.addCurve(to: CGPoint(x: 80, y: 28), control1: CGPoint(x: 122, y: 14), control2: CGPoint(x: 96, y: 16))
        p.closeSubpath()
        return p
    }

    private static var spine: Path {
        var p = Path()
        p.move(to: CGPoint(x: 80, y: 28))
        p.addLine(to: CGPoint(x: 80, y: 102))
        return p
    }

    private static var lines: Path {
        var p = Path()
        for (start, end, c1, c2) in [
            (CGPoint(x: 34, y: 40), CGPoint(x: 66, y: 43), CGPoint(x: 44, y: 38), CGPoint(x: 56, y: 39)),
            (CGPoint(x: 34, y: 54), CGPoint(x: 66, y: 57), CGPoint(x: 44, y: 52), CGPoint(x: 56, y: 53)),
            (CGPoint(x: 94, y: 43), CGPoint(x: 126, y: 40), CGPoint(x: 104, y: 39), CGPoint(x: 116, y: 38)),
            (CGPoint(x: 94, y: 57), CGPoint(x: 126, y: 54), CGPoint(x: 104, y: 53), CGPoint(x: 116, y: 52))
        ] {
            p.move(to: start)
            p.addCurve(to: end, control1: c1, control2: c2)
        }
        return p
    }

    private static var bookmark: Path {
        var p = Path()
        p.move(to: CGPoint(x: 112, y: 14))
        p.addLine(to: CGPoint(x: 112, y: 36))
        p.addLine(to: CGPoint(x: 120, y: 30))
        p.addLine(to: CGPoint(x: 128, y: 36))
        p.addLine(to: CGPoint(x: 128, y: 16))
        return p
    }
}
