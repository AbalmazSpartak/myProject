import SwiftUI
import SwiftData

/// Режим «Чтение» (LexiStream): нижняя панель — Библиотека (Мои книги и Аудио), Подписки, Закладки, Профиль; сверху — переключатель режимов.
/// «Закладки» — закладки из всех книг («Заметки» пока пустые), «Профиль» — временный макет (потом разделим по назначению)
struct ReaderTabsView: View {
    enum Tab: Hashable { case library, subscriptions, bookmarks, profile }

    @State private var tab: Tab = .library
    /// Общий с «Обучением» признак «открыт Профиль»: при смене режима остаёмся в нём
    @Binding var onProfile: Bool
    /// Тот же ключ, что у библиотеки: «Профиль» может открыть её сразу на «Подписках»
    @AppStorage("books_tab") private var libraryTab: LibraryTab = .mine
    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { BooksView(isHome: true, hasTabBar: true).modeSwitcherInset() }
                .tabItem { Label("Библиотека", systemImage: "book") }
                .tag(Tab.library)

            NavigationStack { BooksView(isHome: true, hasTabBar: true, fixedTab: .subscriptions).modeSwitcherInset() }
                .tabItem { Label("Подписки", systemImage: "arrow.down.circle") }
                .tag(Tab.subscriptions)

            ReaderBookmarksTab()
                .modeSwitcherInset()
                .tabItem { Label("Закладки", systemImage: "bookmark") }
                .tag(Tab.bookmarks)

            NavigationStack {
                ReaderProfileView(
                    openLibrary: { section in
                        if section == .subscriptions {
                            tab = .subscriptions
                        } else {
                            libraryTab = section
                            tab = .library
                        }
                    },
                    openBookmarks: { tab = .bookmarks }
                )
                .modeSwitcherInset()
            }
            .tabItem { Label("Профиль", systemImage: "person") }
            .tag(Tab.profile)
        }
        .onAppear { if onProfile { tab = .profile } }
        .onChange(of: tab) { _, new in
            Haptics.tap()
            onProfile = new == .profile
        }
        .tint(design == AppDesign.sketch.rawValue ? Color.brandDark : Color.brandTint)
        .toolbarBackground(design == AppDesign.sketch.rawValue ? Color.cardBackground : Color.brandBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

/// Временный «Профиль»: приветствие, разделы и последние книги. Настройки открываются шестерёнкой
private struct ReaderProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    let openLibrary: (_ section: LibraryTab) -> Void
    let openBookmarks: () -> Void

    @AppStorage("profile_section") private var section = ProfileSection.account
    @State private var isShowingSettings = false
    @State private var openedBook: Book?

    private var profile: UserProfile? { profiles.first }

    /// Открытые хоть раз — последняя прочитанная сверху, потом остальные по дате добавления
    private var shelf: [Book] {
        Array(books.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }.prefix(10))
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Доброе утро"
        case 12..<18: "Добрый день"
        case 18..<23: "Добрый вечер"
        default: "Доброй ночи"
        }
    }

    var body: some View {
        ScrollView {
            // Отступы — как у профиля «Обучения»: карточка на 8 ниже переключателя, промежутки 20
            VStack(alignment: .leading, spacing: 20) {
                ProfileHeaderCard()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                ProfileSectionTabs(selection: $section)
                Group {
                    switch section {
                    case .account:
                        ProfileAccountTab()
                    case .stats:
                        readingStats
                    }
                }
                .padding(.horizontal, 20)
                Spacer().frame(height: 20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { if SettingsReturn.consume() { isShowingSettings = true } }
        .navigationDestination(item: $openedBook) { book in
            BookDetailView(book: book)
                .toolbar(.hidden, for: .tabBar)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(profile: profile ?? UserProfile.ensureSingle(in: modelContext))
                .appThemedColorScheme()
        }
    }

    // MARK: - Части экрана

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .scaledFont(size: 13)
                    .foregroundColor(Color.brandMuted)
                Text(profile?.name ?? "")
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundColor(.brandDark)
                    .lineLimit(1)
            }
            Spacer()
            Button { isShowingSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .scaledFont(size: 20)
                    .foregroundColor(.brandDark)
                    .frame(width: 44, height: 44)
                    .background(Color.brandFill, in: Circle())
            }
            .accessibilityLabel("Настройки")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = profile?.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            Text(String((profile?.name ?? "").prefix(1)).uppercased())
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .frame(width: 48, height: 48)
                .background(Color.brandFill, in: Circle())
        }
    }

    private var sections: some View {
        VStack(spacing: 14) {
            Text("Разделы")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
            // Четыре равные колонки на всю ширину — ряд по центру на любом экране
            HStack(spacing: 0) {
                section("Читаю", icon: "book") { openLibrary(.mine) }
                section("Аудио", icon: "headphones") { openLibrary(.audio) }
                section("Закладки", icon: "bookmark") { openBookmarks() }
                section("Подписки", icon: "arrow.down.circle") { openLibrary(.subscriptions) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func section(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .scaledFont(size: 26)
                    .foregroundColor(.brandTint)
                    .frame(width: 66, height: 66)
                    .background(Color.brandFill, in: Circle())
                Text(title)
                    .scaledFont(size: 14)
                    .foregroundColor(.brandDark)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    /// Статистика «Чтения» — вариант «Графики»: книги считаются по-настоящему, остальное — заглушки «скоро» до появления данных
    private var readingStats: some View {
        let reading = books.filter { $0.progress > 0 && $0.progress < 0.98 }.count
        let finished = books.filter { $0.progress >= 0.98 }.count
        return VStack(spacing: 10) {
            StatCard(title: "Книги", note: "всего \(books.count) в библиотеке") {
                HStack(alignment: .bottom, spacing: 28) {
                    statNumber("Читаю", reading, .brandScale2)
                    statNumber("Прочитано", finished, .brandScale4)
                    Spacer(minLength: 0)
                }
                if reading + finished > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            if finished > 0 { Rectangle().fill(Color.brandScale4).frame(width: geo.size.width * CGFloat(finished) / CGFloat(reading + finished)) }
                            if reading > 0 { Rectangle().fill(Color.brandScale2) }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)
                }
            }
            soonCard("Время чтения", note: "минут в день")
            soonCard("Страницы по месяцам", note: "последние 6 месяцев")
            HStack(spacing: 10) {
                soonTile("Слова из книг в словаре")
                soonTile("Прослушано в аудио")
            }
        }
    }

    private func statNumber(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 9, height: 9)
                Text(title).scaledFont(size: 12).foregroundColor(.brandMuted)
            }
            Text("\(value)").scaledFont(size: 34, weight: .medium, design: .serif).foregroundColor(.brandDark)
        }
    }

    private func soonCard(_ title: String, note: String) -> some View {
        StatCard(title: title, note: note) {
            Text("Скоро: график появится, когда приложение начнёт считать.")
                .scaledFont(size: 13).foregroundColor(.brandMuted)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }
    }

    private func soonTile(_ title: String) -> some View {
        StatCard {
            Text(title).scaledFont(size: 12).foregroundColor(.brandMuted)
            Text("—").scaledFont(size: 30, weight: .medium, design: .serif).foregroundColor(.brandMuted)
            Text("скоро").scaledFont(size: 11).foregroundColor(.brandMuted)
        }
    }

    private var booksShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Мои книги")
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundColor(.brandDark)
                Spacer()
                Button { openLibrary(.mine) } label: {
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 14, weight: .bold)
                        .foregroundColor(.brandDark)
                        .frame(width: 34, height: 34)
                        .background(Color.brandFill, in: Circle())
                }
                .accessibilityLabel("Все книги")
            }
            if shelf.isEmpty {
                Text("Книг пока нет. Добавьте первую в «Библиотеке».")
                    .scaledFont(size: 15)
                    .foregroundColor(Color.brandMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(shelf) { book in
                            BookCard(book: book) { openedBook = book }
                                .frame(width: 142)
                        }
                    }
                }
                // Ряд книг идёт до края экрана, а не обрывается полями
                .padding(.horizontal, -20)
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
    }
}
