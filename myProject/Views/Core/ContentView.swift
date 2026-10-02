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

    var id: String { "\(self)" }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var activeScreen: ActiveScreen?
    @AppStorage(MainMenuLayout.storageKey) private var menuLayout = MainMenuLayout.standard
    @State private var expandedGroups: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        VStack(spacing: 24) {
                            Spacer()
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                            
                            Text("WordLearner")
                                .scaledFont(size: 34, weight: .bold, design: .serif)
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 80)
                        .padding(.bottom, 20)
                        
                        VStack(spacing: 14) {
                            
                            MenuCardButton(
                                title: "Мой профиль",
                                icon: "person.fill",
                                themeColor: .teal
                            ) {
                                activeScreen = .profile
                            }
                            
                            // Порядок и видимость — в настройках профиля: ⚙️ → «Главное меню»
                            ForEach(menuLayout.visibleItems, id: \.self) { item in
                                switch item {
                                case .section(let section):
                                    sectionButton(section)
                                case .group(let id):
                                    if let group = menuLayout.groups[id] {
                                        groupCard(group)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            // Разделы открываются переходом: свайп от левого края возвращает в меню
            .navigationDestination(item: $activeScreen) { screen in
                destination(for: screen)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private func sectionButton(_ section: MenuSection) -> some View {
        MenuCardButton(title: section.menuTitle, icon: section.icon, themeColor: section.color) {
            activeScreen = section.screen
        }
    }

    /// Раскрывающаяся группа разделов
    private func groupCard(_ group: MenuGroup) -> some View {
        let isExpanded = expandedGroups.contains(group.id)
        return VStack(alignment: .leading, spacing: 14) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded { expandedGroups.remove(group.id) } else { expandedGroups.insert(group.id) }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: group.icon)
                        .foregroundColor(group.color)
                        .scaledFont(size: 18)
                    Text(group.name)
                        .scaledFont(size: 20, weight: .bold, design: .default)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 14) {
                    ForEach(menuLayout.visibleSections(in: group.id), id: \.self) { section in
                        sectionButton(section)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(14)
        .background(Color.brandFill)
        .cornerRadius(24)
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
        }
    }
}
