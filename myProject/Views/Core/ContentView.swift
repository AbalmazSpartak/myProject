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
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.chosenKey) private var modeChosen = false
    /// «Спрашивать при запуске» — читается один раз: включили в Настройках — спросит со следующего запуска
    @State private var asksOnLaunch = UserDefaults.standard.bool(forKey: AppMode.askKey)

    var body: some View {
        Group {
            switch mode {
            case .learning: learningTabs
            // «Чтение» — библиотека с нижней панелью (Главная, Библиотека, Закладки, Профиль), без тренировок и игр
            case .reading: ReaderTabsView()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !modeChosen || asksOnLaunch }, set: { _ in })) {
            ModeChoiceView { asksOnLaunch = false }
                .appThemedColorScheme()
        }
    }

    private var learningTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                // «Сообщество» с «Обзора» — вкладка, а не вторая копия поверх «Обзора»: у него своя история переходов
                OverviewView(open: { $0 == .community ? (selectedTab = 3) : (activeScreen = $0) },
                             openProfile: { activeScreen = .profile })
                    .modeSwitcherInset()
                    .navigationBarHidden(true)
                    // Разделы открываются переходом: свайп от левого края возвращает на «Обзор»
                    .navigationDestination(item: $activeScreen) { screen in
                        destination(for: screen)
                            .toolbar(.hidden, for: .navigationBar)
                            // Внутри раздела — на весь экран, без вкладок
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

            // Карточки — вкладкой, как в дизайне LexiStream
            NavigationStack {
                FlashcardsView()
                    .readableColumn()
                    .modeSwitcherInset()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Карточки", systemImage: "rectangle.stack") }
            .tag(2)

            // Сообщество — вкладкой: темы открываются переходом внутри её стека
            CommunityView(showsBackButton: false)
                .modeSwitcherInset()
                .tabItem { Label("Сообщество", systemImage: "person.3") }
                .tag(3)
        }
        .onChange(of: selectedTab) { _, _ in Haptics.tap() }
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
