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
    /// Тема сообщества из «Ваших подборок»
    case topic(CommunityTopic)

    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                OverviewView { activeScreen = $0 }
                    .navigationBarHidden(true)
                    // Разделы открываются переходом: свайп от левого края возвращает на «Обзор»
                    .navigationDestination(item: $activeScreen) { screen in
                        destination(for: screen)
                            .toolbar(.hidden, for: .navigationBar)
                            // Внутри раздела — на весь экран, без вкладок
                            .toolbar(.hidden, for: .tabBar)
                    }
            }
            .tabItem { Label("Обзор", systemImage: "safari.fill") }
            .tag(0)

            ProfileView()
                .readableColumn()
                .tabItem { Label("Профиль", systemImage: "person.fill") }
                .tag(1)

            DictionaryView(showsBackButton: false)
                .readableColumn()
                .tabItem { Label("Словарь", systemImage: "book.closed.fill") }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, _ in Haptics.tap() }
        .tint(.brandTint)
        .toolbarBackground(Color.brandFill, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    @ViewBuilder
    private func destination(for screen: ActiveScreen) -> some View {
        switch screen {
        case .profile:
            ProfileView()
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
        case .help:
            HelpView()
                .readableColumn()
        // «Сообщество» и «Книги» — во всю ширину: ленты и сетка обложек на iPad занимают место с пользой
        case .community:
            CommunityView()
        case .books:
            BooksView()
        case .topic(let topic):
            TopicView(topic: topic, backTitle: "Обзор")
        }
    }
}
