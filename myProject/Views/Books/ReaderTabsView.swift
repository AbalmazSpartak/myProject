import SwiftUI
import SwiftData

/// Режим «Чтение»: нижняя панель — Главная, Библиотека, Закладки, Профиль.
/// «Главная» и «Закладки» пока заглушки, «Профиль» — временный макет (потом разделим по назначению)
struct ReaderTabsView: View {
    enum Tab: Hashable { case home, library, bookmarks, profile }

    @State private var tab: Tab = .library
    /// Тот же ключ, что у библиотеки: «Профиль» может открыть её сразу на «Подписках»
    @AppStorage("books_tab") private var libraryTab: LibraryTab = .mine

    var body: some View {
        TabView(selection: $tab) {
            ReaderSoonView(icon: "house", title: "Главная",
                           text: "Скоро: здесь будет то, с чего удобно начать чтение.")
                .tabItem { Label("Главная", systemImage: "house") }
                .tag(Tab.home)

            NavigationStack { BooksView(isHome: true, hasTabBar: true) }
                .tabItem { Label("Библиотека", systemImage: "books.vertical") }
                .tag(Tab.library)

            ReaderSoonView(icon: "bookmark", title: "Закладки",
                           text: "Скоро: закладки и заметки из всех книг — в одном месте.")
                .tabItem { Label("Закладки", systemImage: "bookmark") }
                .tag(Tab.bookmarks)

            NavigationStack {
                ReaderProfileView(
                    openLibrary: { section in
                        libraryTab = section
                        tab = .library
                    },
                    openBookmarks: { tab = .bookmarks }
                )
            }
            .tabItem { Label("Профиль", systemImage: "person") }
            .tag(Tab.profile)
        }
        .onChange(of: tab) { _, _ in Haptics.tap() }
        .tint(.brandTint)
        .toolbarBackground(Color.brandFill, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

/// Вкладка, которой ещё нет: значок и пояснение
private struct ReaderSoonView: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        TabPlaceholder(icon: icon, title: title, text: text)
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
                header
                sections
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
                    .foregroundColor(.gray)
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
                    .foregroundColor(.gray)
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
