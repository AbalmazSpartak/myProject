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
    /// Словарь сразу на нужной подборке
    case collection(DictionaryFilter)
    /// Раздел, который ещё не сделан
    case stub(title: String, message: String)

    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?

    var body: some View {
        TabView {
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

            ProfileView()
                .tabItem { Label("Профиль", systemImage: "person.fill") }

            DictionaryView(showsBackButton: false)
                .tabItem { Label("Словарь", systemImage: "book.closed.fill") }
        }
        .tint(.brandDark)
        .toolbarBackground(Color.brandFill, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    @ViewBuilder
    private func destination(for screen: ActiveScreen) -> some View {
        switch screen {
        case .profile:
            ProfileView()
        case .flashcardsFSRS:
            FlashcardsView()
        case .quiz:
            QuizView()
        case .cloze:
            ClozeView()
        case .inputCards:
            InputFlashcardsView()
        case .dictionary:
            DictionaryView()
        case .tetris:
            TetrisView()
        case .race:
            RaceLobbyView()
        case .help:
            HelpView()
        case .collection(let filter):
            DictionaryView(initialFilter: filter)
        case .stub(let title, let message):
            StubView(title: title, message: message)
        }
    }
}
