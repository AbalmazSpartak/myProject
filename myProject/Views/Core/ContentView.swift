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
    @State private var selectedTab = 0
    /// Открыт «Профиль» — при смене режима общий раздел остаётся открытым, а не прыгает на «Библиотеку» / «Обзор»
    @State private var onProfile = false
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.chosenKey) private var modeChosen = false
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false
    /// «Спрашивать при запуске» — читается один раз: включили в Настройках — спросит со следующего запуска
    @State private var asksOnLaunch = UserDefaults.standard.bool(forKey: AppMode.askKey)

    var body: some View {
        Group {
            switch readerOnly ? AppMode.reading : mode {
            case .learning: learningTabs
            // «Чтение» — библиотека с нижней панелью (Главная, Библиотека, Закладки, Профиль), без тренировок и игр
            case .reading: ReaderTabsView(onProfile: $onProfile)
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !readerOnly && (!modeChosen || asksOnLaunch) }, set: { _ in })) {
            ModeChoiceView { asksOnLaunch = false }
                .appThemedColorScheme()
        }
    }

    /// «Обучение» — минимум для запоминания слов: Обзор (три раздела), Словарь и Профиль
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

            DictionaryView(showsBackButton: false)
                .readableColumn()
                .modeSwitcherInset()
                .tabItem { Label("Словарь", systemImage: "books.vertical") }
                .tag(1)

            NavigationStack {
                ProfileView(showsBackButton: false)
                    .readableColumn()
                    .modeSwitcherInset()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Профиль", systemImage: "person") }
            .tag(2)
        }
        .onAppear {
            if onProfile { selectedTab = 2 } else if selectedTab == 2 { selectedTab = 0 }
        }
        .onChange(of: selectedTab) { _, new in
            Haptics.tap()
            onProfile = new == 2
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
