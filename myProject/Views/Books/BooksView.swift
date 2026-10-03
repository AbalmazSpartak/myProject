import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// «Книги»: библиотека — книги из «Файлов» и из каталога Project Gutenberg; нажатие открывает читалку
struct BooksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]

    @State private var openedBook: Book?
    @State private var isImporting = false
    @State private var isShowingCatalog = false
    @State private var isParsing = false
    @State private var errorMessage: String?
    @State private var bookToDelete: Book?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            header

            if books.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach(books) { book in
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.epub, .plainText]) { result in
            if case .success(let url) = result {
                Task { await importBook(url) }
            }
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
                if let bookToDelete { modelContext.delete(bookToDelete) }
                try? modelContext.save()
            }
        } message: {
            Text("Словарь из этой книги и добавленные слова останутся.")
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Обзор")
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            }
            Spacer()
            HStack(spacing: 16) {
                HelpButton(topic: .books)
                addMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .overlay {
            Text("Книги")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    private var addMenu: some View {
        Menu {
            Button { isShowingCatalog = true } label: {
                Label("Каталог бесплатных книг", systemImage: "books.vertical")
            }
            Button { isImporting = true } label: {
                Label("Из «Файлов» (.epub, .txt)", systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .scaledFont(size: 22)
                .foregroundColor(.brandDark)
        }
        .accessibilityLabel("Добавить книгу")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 52))
                .foregroundColor(.brown.opacity(0.6))
            Text("Здесь будут ваши книги")
                .scaledFont(size: 24, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
            Text("Читайте на английском: нажмите на слово — увидите перевод и сможете добавить его в словарь книги.")
                .scaledFont(size: 16)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button { isShowingCatalog = true } label: {
                Label("Каталог бесплатных книг", systemImage: "books.vertical")
                    .scaledFont(size: 17, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandDark)
            Button("Добавить из «Файлов»") { isImporting = true }
                .scaledFont(size: 16)
                .foregroundColor(.brandDark)
            Spacer()
        }
        .padding(.horizontal, 36)
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
            errorMessage = "Не получилось открыть книгу. Подходят .epub без защиты (например, не из Apple Books) и .txt."
        }
    }
}

/// Обложка, название, автор и сколько прочитано
private struct BookCard: View {
    let book: Book
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                BookCover(data: book.coverData, title: book.title)
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                Text(book.title)
                    .scaledFont(size: 15, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
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
