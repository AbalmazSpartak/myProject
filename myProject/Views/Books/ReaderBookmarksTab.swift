import SwiftUI
import SwiftData

/// Вкладка «Закладки» режима «Чтение» по холсту (экран 9): закладки из всех книг в одном месте, фильтр по книге.
/// «Заметки» (экран 10) — пока пустой раздел: где и как выделять текст, решаем отдельно
struct ReaderBookmarksTab: View {
    private enum Section: String, CaseIterable, Identifiable { case bookmarks = "Закладки", notes = "Заметки"
        var id: String { rawValue }
    }

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
    @Query(filter: #Predicate<Book> { $0.bookmarksData != nil || $0.notesData != nil }, sort: \Book.title) private var allBooks: [Book]

    @State private var section = Section.bookmarks
    /// nil — «Все книги»
    @State private var bookFilter: UUID?
    @State private var places: [UUID: Places] = [:]
    @State private var openedBook: Book?
    /// Править описание заметки
    @State private var editingNote: NoteEntry?
    @State private var editText = ""

    /// Заметка вместе с книгой
    private struct NoteEntry: Identifiable {
        let book: Book
        let note: BookNote
        var id: UUID { note.id }
    }

    /// Книги раздела: с закладками на вкладке «Закладки», с заметками — на «Заметки»
    private var books: [Book] {
        allBooks.filter { section == .bookmarks ? !$0.bookmarks.isEmpty : !$0.notes.isEmpty }
    }

    private var noteEntries: [NoteEntry] {
        books.filter { bookFilter == nil || $0.id == bookFilter }
            .flatMap { book in book.notes.map { NoteEntry(book: book, note: $0) } }
            .sorted { $0.note.created > $1.note.created }
    }

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
                        .scaledFont(size: AppDesign.isSketch ? 38 : 34, weight: .semibold, design: AppDesign.isSketch ? .rounded : .serif)
                        .foregroundStyle(Color.brandDark)
                    if AppDesign.isSketch {
                        SketchTabs(items: Section.allCases, title: \.rawValue, selection: $section)
                    } else {
                        Picker("Раздел", selection: $section) {
                            ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if books.count > 1 { bookChips }
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
                    if noteEntries.isEmpty {
                        TabPlaceholder(icon: "note.text", title: "Заметок пока нет",
                                       text: "В читалке выделите фразу долгим нажатием и выберите «Заметка».")
                    } else {
                        notesList
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.brandBackground.ignoresSafeArea())
            .sketchTabBarInset()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openedBook) { book in
                BookReaderView(book: book)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
            }
            .task(id: allBooks.map(\.id)) { await loadPlaces() }
            .onChange(of: section) { _, _ in bookFilter = nil }
            .lxAlert("Описание заметки", isPresented: Binding(get: { editingNote != nil }, set: { if !$0 { editingNote = nil } })) {
                TextField("Описание", text: $editText)
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") { saveEdit() }
            }
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
            modelContext.saveReporting()
            openedBook = entry.book
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bookmark").scaledFont(size: 20).foregroundStyle(AppDesign.isSketch ? Color.brandDark : Color.brandTint)
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
        .lxContextMenu {
            Button(role: .destructive) { remove(entry) } label: {
                Label("Удалить закладку", systemImage: "trash")
            }
        }
        .accessibilityHint("Открыть книгу на этом месте")
    }

    private var notesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(noteEntries) { entry in noteCard(entry) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    /// Карточка заметки по холсту: выделенная фраза на мягкой подложке, описание, глава · % · дата
    private func noteCard(_ entry: NoteEntry) -> some View {
        let percent = Int((Double(entry.note.paragraph) / Double(max(entry.book.paragraphCount, 1)) * 100).rounded())
        var place = [DictionaryView.shortName(entry.book.title, limit: 24)]
        if let chapter = chapterTitle(forParagraph: entry.note.paragraph, in: entry.book) { place.append(chapter) }
        place.append("\(percent)%")
        place.append(dateText(entry.note.created))
        return Button {
            entry.book.position = entry.note.paragraph
            modelContext.saveReporting()
            openedBook = entry.book
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.note.text)
                    .scaledFont(size: 17, design: .serif)
                    .foregroundStyle(Color.brandOnSoft)
                    .padding(.horizontal, 3)
                    .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 3))
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                if entry.note.note.isEmpty {
                    Label("Добавить описание", systemImage: "pencil")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(Color.brandTint)
                        .frame(minHeight: 36, alignment: .leading)
                } else {
                    Text(entry.note.note)
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.brandDark)
                        .multilineTextAlignment(.leading)
                }
                Text(place.joined(separator: " · "))
                    .scaledFont(size: 12)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppDesign.isSketch ? Color.clear : Color.brandBorder, lineWidth: 1))
            .sketchFrame(AppDesign.isSketch, radius: 16, shadow: NewStyle.blue, offset: 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lxContextMenu {
            Button {
                editText = entry.note.note
                editingNote = entry
            } label: { Label("Изменить описание", systemImage: "pencil") }
            Button(role: .destructive) { removeNote(entry) } label: {
                Label("Удалить заметку", systemImage: "trash")
            }
        }
        .accessibilityHint("Открыть книгу на этом месте")
    }

    private func saveEdit() {
        guard let entry = editingNote else { return }
        var list = entry.book.notes
        if let index = list.firstIndex(where: { $0.id == entry.note.id }) {
            list[index].note = editText.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.book.notes = list
            modelContext.saveReporting()
        }
        editingNote = nil
    }

    private func removeNote(_ entry: NoteEntry) {
        var list = entry.book.notes
        list.removeAll { $0.id == entry.note.id }
        entry.book.notes = list
        modelContext.saveReporting()
    }

    private func chapterTitle(forParagraph paragraph: Int, in book: Book) -> String? {
        guard let place = places[book.id],
              let index = place.starts.lastIndex(where: { $0 <= paragraph }),
              place.titles.indices.contains(index) else { return nil }
        return place.titles[index]
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
        chapterTitle(forParagraph: entry.bookmark.paragraph, in: entry.book)
    }

    private func dateText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Главы книг с закладками: JSON книги разбирается один раз на книгу и в фоне
    private func loadPlaces() async {
        let pending = allBooks.filter { places[$0.id] == nil }.map { ($0.id, $0.chaptersData) }
        guard !pending.isEmpty else { return }
        let loaded = await Task.detached(priority: .userInitiated) { () -> [(UUID, Places)] in
            pending.map { id, data in
                let chapters = (try? JSONDecoder().decode([BookChapter].self, from: data)) ?? []
                var start = 0
                let starts = chapters.map { chapter -> Int in
                    defer { start += chapter.paragraphs.count }
                    return start
                }
                let numbering = ChapterNumbering(titles: chapters.map(\.title))
                let titles = chapters.indices.map { numbering.listTitle(for: $0, title: chapters[$0].title) }
                return (id, Places(starts: starts, titles: titles))
            }
        }.value
        for (id, place) in loaded { places[id] = place }
    }

    private func remove(_ entry: Entry) {
        var list = entry.book.bookmarks
        list.removeAll { $0.id == entry.bookmark.id }
        entry.book.bookmarks = list
        modelContext.saveReporting()
    }
}
