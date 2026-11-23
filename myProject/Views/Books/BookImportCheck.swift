import SwiftUI
import SwiftData
import PhotosUI

/// Книга разобрана и ждёт решения: она похожа на книгу из библиотеки
struct PendingBookImport: Identifiable {
    let id = UUID()
    let parsed: ParsedBook
    let gutenbergID: Int?
    let existing: Book
    let verdict: BookDuplicates.Verdict
    let similarity: Double
}

@MainActor
enum BookImportCheck {
    /// Добавить книгу или остановиться и спросить, если она похожа на уже имеющуюся. Возвращает добавленную книгу
    static func add(_ parsed: ParsedBook, gutenbergID: Int? = nil, books: [Book], context: ModelContext,
                    pending: Binding<PendingBookImport?>) async -> Book? {
        let candidates = books.map {
            BookDuplicates.Candidate(title: $0.title, author: $0.author, paragraphCount: $0.paragraphCount, chaptersData: $0.chaptersData)
        }
        let match = await Task.detached(priority: .userInitiated) { BookDuplicates.find(parsed, among: candidates) }.value
        if let match, books.indices.contains(match.index) {
            pending.wrappedValue = PendingBookImport(parsed: parsed, gutenbergID: gutenbergID, existing: books[match.index],
                                                     verdict: match.verdict, similarity: match.similarity)
            return nil
        }
        return await insert(parsed, gutenbergID: gutenbergID, title: nil, author: nil, cover: nil, context: context)
    }

    /// Вставить книгу; название, автор и обложка — свои, если заданы (подпись издания)
    static func insert(_ parsed: ParsedBook, gutenbergID: Int?, title: String?, author: String?, cover: Data?,
                       context: ModelContext) async -> Book {
        let book = await Book.make(parsed, gutenbergID: gutenbergID)
        if let title, !title.isEmpty { book.title = title }
        if let author { book.author = author }
        if let cover { book.coverData = cover }
        context.insert(book)
        context.saveReporting()
        return book
    }

    /// Предложение для названия другого издания: «Название (издание 2)», следующее свободное число
    static func suggestedTitle(for parsed: ParsedBook, books: [Book]) -> String {
        let base = parsed.title
        let taken = Set(books.map { BookDuplicates.normalized($0.title) })
        guard taken.contains(BookDuplicates.normalized(base)) else { return base }
        for number in 2...20 {
            let candidate = "\(base) (издание \(number))"
            if !taken.contains(BookDuplicates.normalized(candidate)) { return candidate }
        }
        return base + " (другое издание)"
    }
}

/// «Эта книга уже есть» (дубль) и «Другое издание» (подпись издания: название, автор, обложка)
private struct BookImportPrompts: ViewModifier {
    @Binding var pending: PendingBookImport?
    let books: [Book]
    /// Книга добавлена после решения человека
    let onAdded: (Book) -> Void
    /// Человек выбрал открыть уже имеющуюся книгу
    let onOpenExisting: (Book) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var editionFor: PendingBookImport?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(dialogTitle, isPresented: Binding(get: { duplicate != nil }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible) {
                Button("Открыть эту книгу") {
                    if let existing = duplicate?.existing { onOpenExisting(existing) }
                    pending = nil
                }
                Button("Это другое издание…") {
                    editionFor = duplicate
                    pending = nil
                }
                Button("Не добавлять", role: .cancel) { pending = nil }
            } message: {
                Text("Текст совпадает на \(Int(((duplicate?.similarity ?? 1) * 100).rounded()))%. Скорее всего, это та же книга.")
            }
            .sheet(item: Binding(get: { edition ?? editionFor }, set: { if $0 == nil { pending = nil; editionFor = nil } })) { item in
                BookEditionSheet(item: item, books: books) { title, author, cover in
                    pending = nil
                    editionFor = nil
                    Task {
                        let book = await BookImportCheck.insert(item.parsed, gutenbergID: item.gutenbergID, title: title, author: author,
                                                                cover: cover, context: modelContext)
                        onAdded(book)
                    }
                } onCancel: {
                    pending = nil
                    editionFor = nil
                }
                .appThemedColorScheme()
            }
    }

    private var duplicate: PendingBookImport? { pending?.verdict == .duplicate ? pending : nil }
    private var edition: PendingBookImport? { pending?.verdict == .edition ? pending : nil }
    private var dialogTitle: String { "«\(duplicate?.existing.title ?? "")» уже есть в библиотеке" }
}

extension View {
    func bookImportPrompts(pending: Binding<PendingBookImport?>, books: [Book], onAdded: @escaping (Book) -> Void,
                           onOpenExisting: @escaping (Book) -> Void) -> some View {
        modifier(BookImportPrompts(pending: pending, books: books, onAdded: onAdded, onOpenExisting: onOpenExisting))
    }
}

/// Другое издание: подпишите его названием, автором или обложкой, чтобы не путать с книгой, что уже есть
struct BookEditionSheet: View {
    let item: PendingBookImport
    let books: [Book]
    let onAdd: (_ title: String, _ author: String, _ cover: Data?) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var author: String
    @State private var coverItem: PhotosPickerItem?
    @State private var cover: Data?

    init(item: PendingBookImport, books: [Book], onAdd: @escaping (String, String, Data?) -> Void, onCancel: @escaping () -> Void) {
        self.item = item
        self.books = books
        self.onAdd = onAdd
        self.onCancel = onCancel
        _title = State(initialValue: BookImportCheck.suggestedTitle(for: item.parsed, books: books))
        _author = State(initialValue: item.parsed.author)
    }

    private var previewCover: Data? { cover ?? item.parsed.cover }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Похоже на «\(item.existing.title)», но текст отличается (общее — \(Int((item.similarity * 100).rounded()))%). Если это другое издание или перевод, подпишите его: так книги не перепутаются.")
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.brandMuted)

                    HStack(alignment: .top, spacing: 16) {
                        Color.clear
                            .aspectRatio(2.0 / 3.0, contentMode: .fit)
                            .frame(width: 96)
                            .overlay { BookCover(data: previewCover, title: title) }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .sketchFrame(AppDesign.isSketch, radius: 6, shadow: NewStyle.peach, offset: 4)
                            .padding(.trailing, AppDesign.isSketch ? 4 : 0)
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $coverItem, matching: .images) {
                                Label("Другая обложка", systemImage: "photo")
                                    .scaledFont(size: 15, weight: .semibold)
                                    .foregroundStyle(AppDesign.isSketch ? Color.brandDark : Color.brandTint)
                                    .frame(minHeight: 44, alignment: .leading)
                            }
                            if cover != nil {
                                Button("Вернуть обложку из файла") { cover = nil; coverItem = nil }
                                    .scaledFont(size: 14)
                                    .foregroundStyle(Color.brandMuted)
                            }
                        }
                    }

                    field("Название", text: $title)
                    field("Автор или издание", text: $author)

                    LXButton(title: "Добавить книгу", action: { onAdd(title.trimmingCharacters(in: .whitespaces), author.trimmingCharacters(in: .whitespaces), cover) })
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Другое издание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Отмена", action: onCancel) }
            }
            .onChange(of: coverItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) { cover = data }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LXSectionLabel(text: label)
            TextField(label, text: text)
                .scaledFont(size: 16)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .lxPlate(radius: 12)
        }
    }
}
