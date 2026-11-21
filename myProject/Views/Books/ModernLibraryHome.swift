import SwiftUI
import SwiftData

/// Главная «Библиотеки» в новом стиле: приветствие, поиск, круглые разделы, синий блок «Мои книги»
struct ModernLibraryHome: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    let openSubscriptions: () -> Void
    let openBookmarks: () -> Void

    @State private var searchText = ""
    @State private var openedBook: Book?
    @State private var showAll: LibraryTab?
    @State private var isShowingSettings = false

    private var profile: UserProfile? { profiles.first }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "Доброе утро"
        case 12..<18: "Добрый день"
        case 18..<23: "Добрый вечер"
        default: "Доброй ночи"
        }
    }

    /// Последняя открытая сверху; поиск — по названию и автору
    private var shown: [Book] {
        let sorted = books.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                search
                sections
                myBooks
            }
            .padding(.top, 8)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $openedBook) { book in
            BookDetailView(book: book).toolbar(.hidden, for: .tabBar)
        }
        .navigationDestination(item: $showAll) { tab in
            BooksView(hasTabBar: true, fixedTab: tab, backTitle: "Библиотека")
                .toolbar(.hidden, for: .tabBar)
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(profile: profile ?? UserProfile.ensureSingle(in: modelContext))
                .appThemedColorScheme()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { isShowingSettings = true } label: {
                Text(String((profile?.name ?? "С").prefix(1)).uppercased())
                    .scaledFont(size: 22, weight: .semibold)
                    .foregroundStyle(Color.brandDark)
                    .frame(width: 56, height: 56)
                    .background(NewStyle.pastels[0], in: Circle())
                    .overlay(Circle().stroke(NewStyle.outline, lineWidth: NewStyle.lineWidth))
            }
            .accessibilityLabel("Настройки")
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).scaledFont(size: 13).foregroundStyle(Color.brandMuted)
                Text(profile?.name ?? "").scaledFont(size: 22, weight: .bold).foregroundStyle(Color.brandDark).lineLimit(1)
            }
            Spacer()
            Button { showAll = .mine } label: {
                Image(systemName: "plus")
                    .scaledFont(size: 20, weight: .medium)
                    .foregroundStyle(Color.brandDark)
                    .frame(width: 46, height: 46)
                    .newCard(radius: 12)
            }
            .accessibilityLabel("Добавить книгу")
        }
        .padding(.horizontal, 20)
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.brandMuted)
            TextField("Искать книги и слова", text: $searchText)
                .scaledFont(size: 16)
                .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .newCard(radius: 14)
        .padding(.horizontal, 20)
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Разделы").scaledFont(size: 22, weight: .bold).foregroundStyle(Color.brandDark)
            HStack(alignment: .top) {
                sectionButton("Читаю", "book", 0) { showAll = .mine }
                Spacer(minLength: 0)
                sectionButton("Слушаю", "headphones", 1) { showAll = .audio }
                Spacer(minLength: 0)
                sectionButton("Закладки", "bookmark", 2, action: openBookmarks)
                Spacer(minLength: 0)
                sectionButton("Подписки", "arrow.down.to.line", 3, action: openSubscriptions)
            }
        }
        .padding(.horizontal, 20)
    }

    private func sectionButton(_ title: String, _ icon: String, _ index: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .scaledFont(size: 24)
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(width: 66, height: 66)
                    .background {
                        ZStack {
                            Circle().fill(NewStyle.blue).offset(x: 2, y: 3)
                            Circle().fill(NewStyle.pastels[index])
                        }
                    }
                    .overlay(Circle().stroke(NewStyle.outline, lineWidth: NewStyle.lineWidth))
                Text(title).scaledFont(size: 13).foregroundStyle(Color.brandDark)
            }
        }
        .buttonStyle(.plain)
    }

    private var myBooks: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Мои книги").scaledFont(size: 24, weight: .bold).foregroundStyle(Color.black.opacity(0.9))
                Spacer()
                Button { showAll = .mine } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.brandDark)
                        .frame(width: 42, height: 42)
                        .newCard(radius: 12, fill: Color.white, shadow: Color.black.opacity(0.0))
                }
                .accessibilityLabel("Все книги")
            }
            if shown.isEmpty {
                Text(books.isEmpty ? "Книг пока нет: нажмите «+», чтобы добавить." : "Ничего не найдено.")
                    .scaledFont(size: 15)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(shown.prefix(12)) { book in
                            ModernBookCard(book: book) { openedBook = book }
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
        }
        .padding(.leading, 20)
        .padding(.top, 22)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40).fill(NewStyle.blue).ignoresSafeArea(edges: .bottom))
    }
}

/// Карточка книги в строке «Мои книги»
struct ModernBookCard: View {
    let book: Book
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                NewCover(book: book, shadow: NewStyle.yellow, offset: 5)
                    .frame(width: 140)
                if !book.author.isEmpty {
                    Text(book.author).scaledFont(size: 12).foregroundStyle(Color.black.opacity(0.7)).lineLimit(1)
                }
                Text(book.title).scaledFont(size: 15, weight: .semibold).foregroundStyle(Color.black.opacity(0.9)).lineLimit(1)
                ProgressView(value: book.progress)
                    .tint(NewStyle.yellow)
                    .background(Capsule().fill(Color.white))
            }
            .frame(width: 145, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
