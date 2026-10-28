import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// «Книги»: библиотека — книги из «Файлов» и из каталога Project Gutenberg; нажатие открывает читалку
struct BooksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]
    @Query private var profiles: [UserProfile]
    /// Главный экран режима «Чтение»: вместо «‹ Обзор» — Настройки
    var isHome = false

    @State private var openedBook: Book?
    @State private var isImporting = false
    @State private var isShowingCatalog = false
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var bookToDelete: Book?
    @State private var isShowingSettings = false
    @AppStorage("books_tab") private var tab: LibraryTab = .recent

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            header

            // Вкладки — и в пустой библиотеке: сразу видно, где будут книги и откуда их взять
            Picker("Раздел", selection: $tab.animation()) {
                ForEach(LibraryTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Разделы листаются и свайпом, плашка переключается вместе с ними
            TabView(selection: $tab) {
                Group {
                    Group {
                        if books.isEmpty {
                            TabPlaceholder(icon: "books.vertical.fill", title: "Здесь будут ваши книги",
                                           text: "Добавьте книгу в «Мои книги» или скачайте бесплатную в «Подписках».")
                        } else if recentBooks.isEmpty {
                            TabPlaceholder(icon: "clock",
                                           text: "Откройте книгу — она появится здесь.")
                        } else {
                            grid(recentBooks)
                        }
                    }
                    .tag(LibraryTab.recent)
                    grid(books, withAddCard: true)
                        .tag(LibraryTab.mine)
                    subscriptions
                        .tag(LibraryTab.subscriptions)
                }
                .background {
                    // В «Изучении» библиотека открыта с «Обзора» — свайп от левого края должен вести назад
                    if !isHome { BackSwipePriority() }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .overlay {
            if isParsing {
                ProgressView("Открываю книгу…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .navigationDestination(item: $openedBook) { book in
            BookReaderView(book: book)
                .toolbar(.hidden, for: .navigationBar)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: UTType.bookFiles) { result in
            if case .success(let url) = result {
                Task { await importBook(url) }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(profile: profiles.first ?? UserProfile.ensureSingle(in: modelContext))
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingCatalog) {
            GutenbergCatalogView()
                .appThemedColorScheme()
        }
        .alert("Не получилось", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Удалить книгу?", isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let bookToDelete {
                    DailyReminder.forgetBook(bookToDelete.title)
                    modelContext.delete(bookToDelete)
                }
                try? modelContext.save()
            }
        } message: {
            Text("Словарь из этой книги и добавленные слова останутся.")
        }
    }

    /// Открытые хоть раз — последняя прочитанная сверху
    private var recentBooks: [Book] {
        books.filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    /// withAddCard — первой карточкой «＋ Добавить книгу» (в «Моих книгах»)
    private func grid(_ items: [Book], withAddCard: Bool = false) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                if withAddCard {
                    AddBookCard { isImporting = true }
                }
                ForEach(items) { book in
                    BookCard(book: book) { openedBook = book }
                        .contextMenu {
                            Button(role: .destructive) { bookToDelete = book } label: {
                                Label("Удалить книгу", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(20)
        }
    }

    /// Источники книг; пока один — каталог Gutenberg
    private var subscriptions: some View {
        ScrollView {
            VStack(spacing: 14) {
                Button { isShowingCatalog = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.brown)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Каталог бесплатных книг")
                                .scaledFont(size: 17, weight: .semibold)
                                .foregroundColor(.brandDark)
                            Text("Классика на английском — бесплатно")
                                .scaledFont(size: 14)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.brown.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("Скоро: другие каталоги и сайты")
                    .scaledFont(size: 14)
                    .foregroundColor(.gray)
            }
            .padding(20)
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            if !isHome {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Обзор")
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                HelpButton(topic: .books)
                // Книга из «Файлов» — первая карточка «Моих книг», каталог — в «Подписках»
                Button { isShowingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .scaledFont(size: 20)
                        .foregroundColor(.brandDark)
                }
                .accessibilityLabel("Настройки")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .overlay {
            Text(isHome ? "Библиотека" : "Книги")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Загрузка из «Файлов»

    private func importBook(_ url: URL) async {
        isParsing = true
        defer { isParsing = false }
        do {
            let parsed = try await Task.detached(priority: .userInitiated) { try BookParser.parse(url) }.value
            let book = Book(parsed)
            modelContext.insert(book)
            try? modelContext.save()
            openedBook = book
        } catch {
            errorMessage = "Не получилось открыть книгу. Подходят .epub без защиты (например, не из Apple Books), .fb2 и .txt."
        }
    }
}

/// Разделы библиотеки на плашке
enum LibraryTab: String, CaseIterable, Identifiable {
    case recent, mine, subscriptions

    var id: Self { self }

    var title: String {
        switch self {
        case .recent: "Недавние"
        case .mine: "Мои книги"
        case .subscriptions: "Подписки"
        }
    }
}

/// Листание разделов не перехватывает свайп от левого края: сначала iOS проверяет, не «назад» ли это
private struct BackSwipePriority: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { Probe() }
    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class Probe: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // Иерархия страниц собирается чуть позже — связываем жесты на следующем шаге
            Task { @MainActor [weak self] in self?.connect() }
        }

        private func connect() {
            var view = superview
            while let current = view, !((current as? UIScrollView)?.isPagingEnabled ?? false) { view = current.superview }
            var responder: UIResponder? = self
            while let current = responder, !(current is UIViewController) { responder = current.next }
            guard let pager = view as? UIScrollView,
                  let back = (responder as? UIViewController)?.navigationController?.interactivePopGestureRecognizer else { return }
            pager.panGestureRecognizer.require(toFail: back)
        }
    }
}

/// Пустой раздел: значок, заголовок и пояснение
private struct TabPlaceholder: View {
    let icon: String
    var title: String?
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.brown.opacity(0.6))
            if let title {
                Text(title)
                    .scaledFont(size: 22, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.center)
            }
            Text(text)
                .scaledFont(size: 16)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity)
    }
}

/// Первая карточка «Моих книг»: книга или текст из «Файлов»
private struct AddBookCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .scaledFont(size: 30, weight: .medium)
                            Text("Добавить книгу")
                                .scaledFont(size: 15, weight: .semibold)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.brown)
                        .padding(12)
                    }
                    .background(Color.brown.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.brown.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    }
                Text("EPUB, FB2, TXT")
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить книгу из «Файлов»")
    }
}

/// Обложка, автор и сколько прочитано
private struct BookCard: View {
    let book: Book
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Пропорция книги 2:3 — карточка растёт с шириной колонки, а не режет обложку
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay { BookCover(data: book.coverData, title: book.title) }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                // Название — на обложке, под ней только автор
                if !book.author.isEmpty {
                    Text(book.author)
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                ProgressView(value: book.progress)
                    .tint(.brown)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Обложка книги; без картинки — цветная плашка с названием
struct BookCover: View {
    let data: Data?
    let title: String

    var body: some View {
        if let data, let image = UIImage(data: data) {
            // Обложка целиком; поля другой пропорции — размытая копия, без обрезки
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .opacity(0.6)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            ZStack {
                LinearGradient(colors: [Color.brown.opacity(0.75), Color.brown.opacity(0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(title)
                    .scaledFont(size: 17, weight: .semibold, design: .serif)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(12)
            }
        }
    }
}
