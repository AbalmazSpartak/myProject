import SwiftUI
import SwiftData

/// Вкладка «Закладки» режима «Чтение» по холсту (экран 9): закладки из всех книг в одном месте, фильтр по книге.
/// «Заметки» (экран 10) — пока пустой раздел: где и как выделять текст, решаем отдельно
struct ReaderBookmarksTab: View {
    private enum Section: String, CaseIterable { case bookmarks = "Закладки", notes = "Заметки" }

    /// Закладка вместе с книгой, где она стоит
    private struct Entry: Identifiable {
        let book: Book
        let bookmark: BookBookmark
        var id: UUID { bookmark.id }
    }

    /// Начала глав книги и их названия — читаем один раз, когда вкладка открыта
    private struct Places {
        let starts: [Int]
        let titles: [String]
    }

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Book> { $0.bookmarksData != nil }, sort: \Book.title) private var books: [Book]

    @State private var section = Section.bookmarks
    /// nil — «Все книги»
    @State private var bookFilter: UUID?
    @State private var places: [UUID: Places] = [:]
    @State private var openedBook: Book?

    private var entries: [Entry] {
        books.filter { bookFilter == nil || $0.id == bookFilter }
            .flatMap { book in book.bookmarks.map { Entry(book: book, bookmark: $0) } }
            .sorted { $0.bookmark.created > $1.bookmark.created }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Закладки")
                        .scaledFont(size: 34, weight: .semibold, design: .serif)
                        .foregroundStyle(Color.brandDark)
                    Picker("Раздел", selection: $section) {
                        ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if section == .bookmarks, books.count > 1 { bookChips }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                switch section {
                case .bookmarks:
                    if entries.isEmpty {
                        TabPlaceholder(icon: "bookmark", title: "Закладок пока нет",
                                       text: "В читалке нажмите «Меню» → «Закладка здесь», и место появится здесь.")
                    } else {
                        list
                    }
                case .notes:
                    TabPlaceholder(icon: "note.text", title: "Заметок пока нет",
                                   text: "Скоро: выделенные места из книг с вашими пояснениями.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.brandBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openedBook) { book in
                BookReaderView(book: book)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
            }
            .task(id: books.map(\.id)) { loadPlaces() }
        }
    }

    // MARK: - Части

    private var bookChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                LXChip(title: "Все книги", isOn: bookFilter == nil) { bookFilter = nil }
                ForEach(books) { book in
                    LXChip(title: DictionaryView.shortName(book.title, limit: 24), isOn: bookFilter == book.id) {
                        bookFilter = book.id
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 18) {
                LXGroup {
                    ForEach(entries) { entry in row(entry) }
                }
                Text("Закладка — просто место в книге. Нажмите, чтобы вернуться к нему.")
                    .scaledFont(size: 13)
                    .foregroundStyle(Color.brandMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func row(_ entry: Entry) -> some View {
        Button {
            // Как «слушать с главы»: читалка открывается там, где стоит закладка
            entry.book.position = entry.bookmark.paragraph
            try? modelContext.save()
            openedBook = entry.book
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bookmark").scaledFont(size: 20).foregroundStyle(Color.brandTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: entry))
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundStyle(Color.brandDark)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle(for: entry))
                        .scaledFont(size: 13)
                        .foregroundStyle(Color.brandMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(dateText(entry.bookmark.created))
                    .scaledFont(size: 13)
                    .foregroundStyle(Color.brandMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { remove(entry) } label: {
                Label("Удалить закладку", systemImage: "trash")
            }
        }
        .accessibilityHint("Открыть книгу на этом месте")
    }

    // MARK: - Данные

    /// Заметка к закладке, а если её нет — глава, где закладка стоит
    private func title(for entry: Entry) -> String {
        if !entry.bookmark.note.isEmpty { return entry.bookmark.note }
        return chapterTitle(for: entry) ?? entry.book.title
    }

    private func subtitle(for entry: Entry) -> String {
        let percent = Int((Double(entry.bookmark.paragraph) / Double(max(entry.book.paragraphCount, 1)) * 100).rounded())
        var parts = [DictionaryView.shortName(entry.book.title, limit: 28)]
        if !entry.bookmark.note.isEmpty, let chapter = chapterTitle(for: entry) { parts.append(chapter) }
        parts.append("\(percent)%")
        return parts.joined(separator: " · ")
    }

    private func chapterTitle(for entry: Entry) -> String? {
        guard let place = places[entry.book.id],
              let index = place.starts.lastIndex(where: { $0 <= entry.bookmark.paragraph }),
              place.titles.indices.contains(index) else { return nil }
        return place.titles[index]
    }

    private func dateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Главы книг с закладками: JSON книги разбирается один раз на книгу
    private func loadPlaces() {
        for book in books where places[book.id] == nil {
            let chapters = book.chapters
            var start = 0
            let starts = chapters.map { chapter -> Int in
                defer { start += chapter.paragraphs.count }
                return start
            }
            let numbering = ChapterNumbering(titles: chapters.map(\.title))
            let titles = chapters.indices.map { numbering.listTitle(for: $0, title: chapters[$0].title) }
            places[book.id] = Places(starts: starts, titles: titles)
        }
    }

    private func remove(_ entry: Entry) {
        var list = entry.book.bookmarks
        list.removeAll { $0.id == entry.bookmark.id }
        entry.book.bookmarks = list
        try? modelContext.save()
    }
}
