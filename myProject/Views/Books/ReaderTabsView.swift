import SwiftUI
import SwiftData

/// Режим «Чтение» (LexiStream): нижняя панель — Библиотека, Аудио, Закладки, Профиль; сверху — переключатель режимов.
/// «Закладки» пока заглушка, «Профиль» — временный макет (потом разделим по назначению)
struct ReaderTabsView: View {
    enum Tab: Hashable { case library, audio, bookmarks, profile }

    @State private var tab: Tab = .library
    /// Тот же ключ, что у библиотеки: «Профиль» может открыть её сразу на «Подписках»
    @AppStorage("books_tab") private var libraryTab: LibraryTab = .mine

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { BooksView(isHome: true, hasTabBar: true).modeSwitcherInset() }
                .tabItem { Label("Библиотека", systemImage: "book") }
                .tag(Tab.library)

            NavigationStack { BooksView(isHome: true, hasTabBar: true, fixedTab: .audio).modeSwitcherInset() }
                .tabItem { Label("Аудио", systemImage: "headphones") }
                .tag(Tab.audio)

            ReaderMarksStubView()
                .modeSwitcherInset()
                .tabItem { Label("Закладки", systemImage: "bookmark") }
                .tag(Tab.bookmarks)

            NavigationStack {
                ReaderProfileView(
                    openLibrary: { section in
                        if section == .audio {
                            tab = .audio
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
        .onChange(of: tab) { _, _ in Haptics.tap() }
        .tint(.brandTint)
        .toolbarBackground(Color.brandBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

/// «Закладки» и «Заметки» — заглушка по дизайну LexiStream: вкладки есть, функционала пока нет
private struct ReaderMarksStubView: View {
    private enum Section: String, CaseIterable { case bookmarks = "Закладки", notes = "Заметки" }
    @State private var section = Section.bookmarks

    var body: some View {
        VStack(spacing: 0) {
            Text("Закладки и заметки")
                .scaledFont(size: 34, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Picker("Раздел", selection: $section) {
                ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(20)
            TabPlaceholder(icon: section == .bookmarks ? "bookmark" : "note.text",
                           title: section == .bookmarks ? "Закладок пока нет" : "Заметок пока нет",
                           text: "Скоро: закладки и заметки из всех книг — в одном месте.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandBackground.ignoresSafeArea())
    }
}

/// Временный «Профиль»: приветствие, разделы и последние книги. Настройки открываются шестерёнкой
private struct ReaderProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    let openLibrary: (_ section: LibraryTab) -> Void
    let openBookmarks: () -> Void

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
            VStack(alignment: .leading, spacing: 24) {
                Text("Профиль")
                    .scaledFont(size: 34, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                header
                sections
                readingStats
                booksShelf
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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

    /// Статистика «Чтения»: книги считаются по-настоящему, остальное — заглушки до появления данных
    private var readingStats: some View {
        let reading = books.filter { $0.progress > 0 && $0.progress < 0.98 }.count
        let finished = books.filter { $0.progress >= 0.98 }.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("Статистика")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statTile("Читаю", "\(reading)")
                statTile("Прочитано", "\(finished)")
                statTile("Страницы", "—", soon: true)
                statTile("Время чтения", "—", soon: true)
                statTile("Слова из книг", "—", soon: true)
                statTile("Прослушано", "—", soon: true)
            }
        }
    }

    private func statTile(_ title: String, _ value: String, soon: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).scaledFont(size: 12).foregroundColor(.brandMuted)
            Text(value)
                .scaledFont(size: 30, weight: .medium, design: .serif)
                .foregroundColor(soon ? .brandMuted : .brandDark)
            if soon { Text("скоро").scaledFont(size: 11).foregroundColor(.brandMuted) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
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
