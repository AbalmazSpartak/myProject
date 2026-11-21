import SwiftUI
import SwiftData

enum ActiveScreen: Hashable, Identifiable {
    case profile
    case flashcardsFSRS
    case quiz
    case cloze
    case inputCards
    case dictionary
    case tetris
    case race
    case help
    case community
    case books
    case polyglot
    case review
    case schulte
    case speak
    /// Тема сообщества из «Ваших подборок»
    case topic(CommunityTopic)
    /// Все «Ваши подборки» — кнопка «Все» на «Обзоре»
    case bookmarks

    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?
    /// Книга, открытая нажатием на виджет «Продолжить чтение»
    @State private var widgetBook: Book?
    /// Виджет «Сейчас слушаете»: открыть книгу и сразу продолжить озвучку
    @State private var widgetListens = false
    /// Файл книги из «Открыть в…»: ошибка импорта
    @State private var importError: String?
    /// Файл из «Открыть в…» похож на книгу из библиотеки — ждёт решения
    @State private var pendingImport: PendingBookImport?
    @State private var libraryForPrompt: [Book] = []
    /// iOS иногда вызывает «Открыть в…» дважды подряд — второй раз тот же файл не добавляем
    @State private var lastOpened: (url: URL, at: Date)?
    /// «Практика» — свои переходы, чтобы экран не открылся сразу в двух вкладках
    @State private var practiceScreen: ActiveScreen?
    @State private var selectedTab = 0
    /// Открыт «Профиль» — при смене режима общий раздел остаётся открытым, а не прыгает на «Библиотеку» / «Обзор»
    @State private var onProfile = SettingsReturn.isPending
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.chosenKey) private var modeChosen = false
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false
    @AppStorage(AppMode.learningOnlyKey) private var learningOnly = false
    /// «Спрашивать при запуске» — читается один раз: включили в Настройках — спросит со следующего запуска
    @State private var asksOnLaunch = UserDefaults.standard.bool(forKey: AppMode.askKey)

    var body: some View {
        Group {
            switch readerOnly ? AppMode.reading : (learningOnly ? AppMode.learning : mode) {
            case .learning: learningTabs
            // «Чтение» — библиотека с нижней панелью (Главная, Библиотека, Закладки, Профиль), без тренировок и игр
            case .reading: ReaderTabsView(onProfile: $onProfile)
            }
        }
        .onOpenURL { url in
            // Файл книги из «Файлов» или «Поделиться»: импортируем и сразу открываем
            if url.isFileURL, BookImport.isBookFile(url) {
                if let last = lastOpened, last.url == url, Date().timeIntervalSince(last.at) < 5 { return }
                lastOpened = (url, Date())
                Task {
                    do {
                        let parsed = try await Task.detached(priority: .userInitiated) { try BookImport.parse(url) }.value
                        let books = (try? modelContext.fetch(FetchDescriptor<Book>())) ?? []
                        libraryForPrompt = books
                        if let book = await BookImportCheck.add(parsed, books: books, context: modelContext, pending: $pendingImport) {
                            widgetListens = false
                            widgetBook = book
                        }
                    } catch {
                        importError = BookImport.message(for: error)
                    }
                }
                return
            }
            // lexistream://read/<id книги> или lexistream://listen/<id книги>
            guard url.scheme == "lexistream", url.host == "read" || url.host == "listen",
                  let id = UUID(uuidString: url.lastPathComponent) else { return }
            widgetListens = url.host == "listen"
            var descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            widgetBook = try? modelContext.fetch(descriptor).first
        }
        .bookImportPrompts(pending: $pendingImport, books: libraryForPrompt, onAdded: { book in
            widgetListens = false
            widgetBook = book
        }, onOpenExisting: { book in
            widgetListens = false
            widgetBook = book
        })
        .alert("Не удалось сохранить", isPresented: Binding(get: { SaveIssue.shared.message != nil }, set: { if !$0 { SaveIssue.shared.message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(SaveIssue.shared.message ?? "")
        }
        .alert("Не получилось", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .fullScreenCover(item: $widgetBook) { book in
            NavigationStack {
                BookReaderView(book: book, listensOnOpen: widgetListens)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .appThemedColorScheme()
        }
        .fullScreenCover(isPresented: Binding(get: { !readerOnly && !learningOnly && (!modeChosen || asksOnLaunch) }, set: { _ in })) {
            ModeChoiceView { asksOnLaunch = false }
                .appThemedColorScheme()
        }
    }

    /// «Обучение» — минимум для запоминания слов: Обзор («Повторить сейчас»), Практика (все тренировки), Словарь и Профиль
    private var learningTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LearningOverviewView(open: { activeScreen = $0 })
                    .readableColumn()
                    .modeSwitcherInset()
                    .toolbar(.hidden, for: .navigationBar)
                    // Раздел открывается переходом на весь экран: свайп от левого края возвращает на «Обзор»
                    .navigationDestination(item: $activeScreen) { screen in
                        destination(for: screen)
                            .toolbar(.hidden, for: .navigationBar)
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem { Label("Обзор", systemImage: "house") }
            .tag(0)

            NavigationStack {
                PracticeView(open: { practiceScreen = $0 })
                    .readableColumn()
                    .modeSwitcherInset()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(item: $practiceScreen) { screen in
                        destination(for: screen)
                            .toolbar(.hidden, for: .navigationBar)
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem { Label("Практика", systemImage: "square.stack.3d.up") }
            .tag(1)

            DictionaryView(showsBackButton: false)
                .readableColumn()
                .modeSwitcherInset()
                .tabItem { Label("Словарь", systemImage: "books.vertical") }
                .tag(2)

            NavigationStack {
                ProfileView(showsBackButton: false)
                    .readableColumn()
                    .modeSwitcherInset()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Профиль", systemImage: "person") }
            .tag(3)
        }
        .onAppear {
            if onProfile { selectedTab = 3 } else if selectedTab == 3 { selectedTab = 0 }
        }
        .onChange(of: selectedTab) { _, new in
            Haptics.tap()
            onProfile = new == 3
        }
        .tint(.brandTint)
        .toolbarBackground(Color.brandBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    @ViewBuilder
    private func destination(for screen: ActiveScreen) -> some View {
        switch screen {
        case .profile:
            ProfileView(showsBackButton: true)
                .readableColumn()
        case .flashcardsFSRS:
            FlashcardsView()
                .readableColumn()
        case .quiz:
            QuizView()
                .readableColumn()
        case .cloze:
            ClozeView()
                .readableColumn()
        case .inputCards:
            InputFlashcardsView()
                .readableColumn()
        case .dictionary:
            DictionaryView()
                .readableColumn()
        case .tetris:
            TetrisView()
                .readableColumn()
        case .race:
            RaceLobbyView()
                .readableColumn()
        case .polyglot:
            PolyglotView()
                .readableColumn()
        case .review:
            ReviewSetupView()
                .readableColumn()
        case .schulte:
            SchulteView()
                .readableColumn()
        case .speak:
            SpeakTrainingView()
                .readableColumn()
        case .help:
            HelpView()
                .readableColumn()
        // «Сообщество» и «Книги» — во всю ширину: ленты и сетка обложек на iPad занимают место с пользой
        case .community:
            // Сюда не попадаем: «Сообщество» открывается вкладкой (см. OverviewView open) — на всякий случай переключаем
            Color.clear.onAppear {
                activeScreen = nil
                selectedTab = 3
            }
        case .books:
            BooksView()
        case .topic(let topic):
            TopicView(topic: topic, backTitle: "Обзор")
        case .bookmarks:
            BookmarksView()
                .readableColumn()
        }
    }
}
