import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// «Книги»: библиотека — книги из «Файлов» и из каталога Project Gutenberg; нажатие открывает страницу книги, оттуда — читалка
struct BooksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    @Query private var profiles: [UserProfile]
    /// Главный экран режима «Чтение»: вместо «‹ Обзор» — Настройки
    var isHome = false
    /// Внутри нижней панели «Чтения»: настройки открываются из «Профиля», шестерёнки здесь нет
    var hasTabBar = false
    /// Раздел зафиксирован (отдельная вкладка «Аудио»): плашка разделов скрыта
    var fixedTab: LibraryTab? = nil

    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue
    @State private var openedBook: Book?
    @State private var listenBook: Book?
    @State private var isImporting = false
    @State private var isShowingCatalog = false
    @State private var isParsing = false
    @State private var importProgress = BookImportProgress()
    @State private var errorMessage: String?
    /// Файл похож на книгу из библиотеки — ждёт решения человека
    @State private var pendingImport: PendingBookImport?
    @State private var bookToDelete: Book?
    @State private var isShowingSettings = false
    @State private var searchText = ""
    @AppStorage("books_tab") private var tab: LibraryTab = .mine
    @AppStorage("books_sort") private var sort: BookSort = .opened

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    /// Разделы плашки: при нижней панели «Чтения» у «Подписок» своя вкладка — здесь их не повторяем
    private var tabs: [LibraryTab] {
        hasTabBar ? LibraryTab.allCases.filter { $0 != .subscriptions } : LibraryTab.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let fixedTab {
                Group {
                    switch fixedTab {
                    case .mine: grid(sortedBooks, withAddCard: true, withSearch: true)
                    case .audio: AudioLibraryView(books: books) { listenBook = $0 }
                    case .subscriptions: subscriptions
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
            // Вкладки — и в пустой библиотеке: сразу видно, где будут книги и откуда их взять
            if design == AppDesign.sketch.rawValue {
                // Отступы как у сетки книг (20), снизу — просвет, чтобы обложки не подходили вплотную к вкладкам
                SketchTabs(items: tabs, title: \.title, selection: $tab)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Picker("Раздел", selection: $tab.animation()) {
                    ForEach(tabs) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Разделы листаются и свайпом, плашка переключается вместе с ними
            TabView(selection: $tab) {
                Group {
                    grid(sortedBooks, withAddCard: true, withSearch: true)
                        .tag(LibraryTab.mine)
                    AudioLibraryView(books: books) { listenBook = $0 }
                        .tag(LibraryTab.audio)
                    if tabs.contains(.subscriptions) {
                        subscriptions
                            .tag(LibraryTab.subscriptions)
                    }
                }
                .background {
                    // В «Изучении» библиотека открыта с «Обзора» — свайп от левого края должен вести назад
                    if !isHome { BackSwipePriority() }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Раздела нет в плашке, а запомнен он — открываем «Мои книги»
            .onAppear { if !tabs.contains(tab) { tab = .mine } }
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { AudiobookRecordingBar() }
        .overlay {
            if isParsing { BookImportProgressView(progress: importProgress) }
        }
        .bookImportPrompts(pending: $pendingImport, books: books, onAdded: { openedBook = $0 }, onOpenExisting: { openedBook = $0 })
        .navigationDestination(item: $openedBook) { book in
            BookDetailView(book: book)
                .toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(item: $listenBook) { book in
            BookDetailView(book: book, startsListening: true)
                .toolbar(.hidden, for: .tabBar)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: UTType.readableBookFiles) { result in
            if case .success(let url) = result {
                Task { await importBook(url) }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(profile: profiles.first ?? UserProfile.ensureSingle(in: modelContext))
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingCatalog) {
            GutenbergCatalogView()
                .appThemedColorScheme()
        }
        .lxAlert("Не получилось", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .lxAlert("Удалить книгу?", isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let bookToDelete {
                    DailyReminder.forgetBook(bookToDelete.title)
                    if LiveAudioPlayer.shared.isCurrent(bookToDelete.id) { LiveAudioPlayer.shared.stop() }
                    if LiveAudioDownloader.shared.isDownloading(bookToDelete.id) { LiveAudioDownloader.shared.cancel() }
                    LiveAudioStore.delete(book: bookToDelete.id)
                    modelContext.delete(bookToDelete)
                }
                modelContext.saveReporting()
            }
        } message: {
            Text("Словарь из этой книги и добавленные слова останутся.")
        }
    }

    /// Книги в выбранном порядке; books уже идут от новых добавленных к старым — при равенстве порядок остаётся таким
    private var sortedBooks: [Book] {
        switch sort {
        case .added:
            return books
        case .opened:
            // Открытые — последняя прочитанная сверху, потом неоткрытые по дате добавления
            return books.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        case .title:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            return books.sorted { $0.progress > $1.progress }
        }
    }

    /// withAddCard — первой карточкой «＋ Добавить книгу» (в «Моих книгах»); withSearch — сверху поле поиска по названию и автору
    private func grid(_ items: [Book], withAddCard: Bool = false, withSearch: Bool = false) -> some View {
        let searching = withSearch && !Self.normalized(searchText).isEmpty
        let shown = searching ? filtered(items) : items
        return ScrollView {
            VStack(spacing: 16) {
                if withSearch, !items.isEmpty { searchField }
                if searching, shown.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 40)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                    // При поиске карточка «Добавить книгу» не нужна — только найденное
                    if withAddCard, !searching {
                        AddBookCard { isImporting = true }
                    }
                    ForEach(shown) { book in
                        BookCard(book: book) { openedBook = book }
                            .contextMenu {
                                Button(role: .destructive) { bookToDelete = book } label: {
                                    Label("Удалить книгу", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// Поле поиска книг: плашка с лупой и крестиком очистки, рядом — выбор порядка
    private var searchField: some View {
        HStack(spacing: 10) {
            searchBox
            Menu {
                Picker("Порядок", selection: $sort) {
                    ForEach(BookSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .scaledFont(size: 16)
                    .foregroundColor(.brandDark)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .sketchFrame(design == AppDesign.sketch.rawValue)
            }
            .accessibilityLabel("Порядок книг: \(sort.title)")
        }
    }

    private var searchBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.brandMuted)
            TextField("Поиск книг", text: $searchText)
                .scaledFont(size: 16)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.brandMuted)
                }
                .accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sketchFrame(design == AppDesign.sketch.rawValue)
    }

    /// Книги, у которых название или автор содержат запрос
    private func filtered(_ items: [Book]) -> [Book] {
        let query = Self.normalized(searchText)
        guard !query.isEmpty else { return items }
        return items.filter { Self.normalized($0.title).contains(query) || Self.normalized($0.author).contains(query) }
    }

    /// Без регистра, ё как е, ’ как '
    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "’", with: "'")
    }

    /// Источники книг; пока один — каталог Gutenberg
    private var subscriptions: some View {
        ScrollView {
            VStack(spacing: 14) {
                Button { isShowingCatalog = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.brandTint)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Каталог бесплатных книг")
                                .scaledFont(size: 17, weight: .semibold)
                                .foregroundColor(.brandDark)
                            Text("Классика на английском — бесплатно")
                                .scaledFont(size: 14)
                                .foregroundColor(Color.brandMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.brandMuted)
                    }
                    .padding(16)
                    .background(Color.brandTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("Скоро: другие каталоги и сайты")
                    .scaledFont(size: 14)
                    .foregroundColor(Color.brandMuted)
            }
            .padding(20)
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            if !isHome {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Обзор")
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                HelpButton(topic: .books)
                // Книга из «Файлов» — первая карточка «Моих книг», каталог — в «Подписках»
                if !hasTabBar {
                    Button { isShowingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .scaledFont(size: 20)
                            .foregroundColor(.brandDark)
                    }
                    .accessibilityLabel("Настройки")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(minHeight: isHome ? 52 : nil)
        .overlay {
            if isHome {
                // Крупный заголовок слева, как в дизайне LexiStream
                HStack {
                    Text(fixedTab?.title ?? "Библиотека")
                        .scaledFont(size: design == AppDesign.sketch.rawValue ? 38 : 34, weight: .semibold, design: design == AppDesign.sketch.rawValue ? .rounded : .serif)
                        .foregroundColor(.brandDark)
                        .padding(.leading, 20)
                    Spacer()
                }
                .padding(.top, 8)
                .allowsHitTesting(false)
            } else {
                Text("Книги")
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundColor(.brandDark)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Загрузка из «Файлов»

    private func importBook(_ url: URL) async {
        isParsing = true
        importProgress.reset()
        defer { isParsing = false }
        do {
            let report = importProgress.report
            let parsed = try await Task.detached(priority: .userInitiated) { try BookImport.parse(url, progress: report) }.value
            // Дубль или другое издание — спросим; новая книга добавляется сразу
            if let book = await BookImportCheck.add(parsed, books: books, context: modelContext, pending: $pendingImport) {
                openedBook = book
            }
        } catch {
            errorMessage = BookImport.message(for: error)
        }
    }
}

/// Разделы библиотеки на плашке
enum LibraryTab: String, CaseIterable, Identifiable {
    case mine, audio, subscriptions

    var id: Self { self }

    var title: String {
        switch self {
        case .mine: "Мои книги"
        case .audio: "Аудио"
        case .subscriptions: "Подписки"
        }
    }
}

/// Порядок книг в «Моих книгах»
enum BookSort: String, CaseIterable, Identifiable {
    case opened, added, title, progress

    var id: Self { self }

    var title: String {
        switch self {
        case .opened: "Недавно открытые"
        case .added: "Недавно добавленные"
        case .title: "По алфавиту"
        case .progress: "По прогрессу чтения"
        }
    }
}

/// Листание разделов не перехватывает свайп от левого края: сначала iOS проверяет, не «назад» ли это
private struct BackSwipePriority: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { Probe() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class Probe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // Иерархия страниц собирается чуть позже — связываем жесты на следующем шаге
            Task { @MainActor [weak self] in self?.connect() }
        }

        private func connect() {
            var view = superview
            while let current = view, !((current as? UIScrollView)?.isPagingEnabled ?? false) { view = current.superview }
            var responder: UIResponder? = self
            while let current = responder, !(current is UIViewController) { responder = current.next }
            guard let pager = view as? UIScrollView,
                  let back = (responder as? UIViewController)?.navigationController?.interactivePopGestureRecognizer else { return }
            pager.panGestureRecognizer.require(toFail: back)
        }
    }
}

/// Пустой раздел: значок, заголовок и пояснение
struct TabPlaceholder: View {
    let icon: String
    var title: String?
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Color.brandTint.opacity(0.6))
            if let title {
                Text(title)
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.center)
            }
            Text(text)
                .scaledFont(size: 16)
                .foregroundColor(Color.brandMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity)
    }
}

/// Первая карточка «Моих книг»: книга или текст из «Файлов»
private struct AddBookCard: View {
    let action: () -> Void
    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .scaledFont(size: 30, weight: .medium)
                            Text("Добавить книгу")
                                .scaledFont(size: 15, weight: .semibold)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(Color.brandTint)
                        .padding(12)
                    }
                    .background(Color.brandTint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(design == AppDesign.sketch.rawValue ? NewStyle.outline : Color.brandTint.opacity(0.45),
                                          style: StrokeStyle(lineWidth: design == AppDesign.sketch.rawValue ? NewStyle.lineWidth : 1.5, dash: [6, 5]))
                    }
                    .background {
                        if design == AppDesign.sketch.rawValue {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NewStyle.pastels[1]).offset(x: 5, y: 5)
                        }
                    }
                Text("EPUB, FB2, TXT, PDF")
                    .scaledFont(size: 15, design: AppDesign.isSketch ? .rounded : .default)
                    .tracking(AppDesign.isSketch ? 0.3 : 0)
                    .foregroundColor(Color.brandMuted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить книгу из «Файлов»")
    }
}

/// Обложка, автор и сколько прочитано
struct BookCard: View {
    let book: Book
    let action: () -> Void
    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue

    var body: some View {
        if design == AppDesign.sketch.rawValue {
            sketch
        } else {
            classic
        }
    }

    /// «Скетч»: контур и жёлтая смещённая тень, полоска прогресса с контуром
    private var sketch: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                NewCover(book: book, shadow: NewStyle.yellow, offset: 5)
                    .padding(.trailing, 5)
                if !book.author.isEmpty {
                    Text(book.author)
                        .scaledFont(size: 15, design: .rounded)
                        .tracking(0.3)
                        .foregroundColor(Color.brandMuted)
                        .lineLimit(1)
                }
                SketchProgress(value: book.progress)
            }
        }
        .buttonStyle(.plain)
    }

    private var classic: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Пропорция книги 2:3 — карточка растёт с шириной колонки, а не режет обложку
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay { BookCover(data: book.coverData, title: book.title) }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                // Название — на обложке, под ней только автор
                if !book.author.isEmpty {
                    Text(book.author)
                        .scaledFont(size: 13)
                        .foregroundColor(Color.brandMuted)
                        .lineLimit(1)
                }
                ProgressView(value: book.progress)
                    .tint(Color.brandTint)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Обложка книги; без картинки — цветная плашка с названием
struct BookCover: View {
    let data: Data?
    let title: String
    /// Автор — только для «Скетча»: на макете он мелкими буквами внизу обложки
    var author: String = ""

    /// Заливка и цвет текста пяти обложек макета «Скетча»; выбор по названию — у книги всегда одна и та же
    private static let sketchCovers: [(fill: Color, text: Color)] = [
        (Color(hex: 0xB8AFA0), Color(hex: 0x1E1E1C)),
        (Color(hex: 0x3E4A3A), .white),
        (Color(hex: 0x7B4433), .white),
        (Color(hex: 0x5A6E8C), .white),
        (Color(hex: 0xE2EFDC), Color(hex: 0x1E1E1C))
    ]

    var body: some View {
        if let data, let image = CoverCache.image(data) {
            // Обложка целиком; поля другой пропорции — размытая копия, без обрезки
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .opacity(0.6)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        } else if AppDesign.isSketch {
            let look = Self.sketchCovers[Int(StableSeed.of(title) % UInt64(Self.sketchCovers.count))]
            ZStack(alignment: .topLeading) {
                look.fill
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .scaledFont(size: 19, weight: .bold, design: .serif)
                        .lineSpacing(1)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 8)
                    if !author.isEmpty {
                        Text(author.uppercased())
                            .scaledFont(size: 9)
                            .tracking(1.2)
                            .lineLimit(2)
                    }
                }
                .foregroundStyle(look.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            ZStack {
                LinearGradient(colors: [Color.brandTint.opacity(0.75), Color.brandTint.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(title)
                    .scaledFont(size: 17, weight: .semibold, design: .serif)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(12)
            }
        }
    }
}
