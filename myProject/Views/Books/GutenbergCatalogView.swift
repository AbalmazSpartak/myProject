import SwiftUI
import SwiftData

/// Что показывает каталог: книги Gutenberg или аудиокниги LibriVox с живым голосом
enum CatalogKind: String, CaseIterable, Identifiable {
    case books, audiobooks
    var id: Self { self }
    var title: String { self == .books ? "Книги" : "Аудиокниги" }
}

/// Каталог Project Gutenberg: самые популярные книги или поиск; книга скачивается в библиотеку одной кнопкой.
/// «Аудиокниги» — записи LibriVox: в библиотеку ложится текст из Gutenberg вместе с живой озвучкой
struct GutenbergCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]

    @State private var query = ""
    @State private var entries: [GutenbergCatalog.Entry] = []
    @State private var isLoading = false
    @State private var downloading: Set<Int> = []
    @State private var errorMessage: String?
    @State private var kind: CatalogKind = .books
    /// Почему список пуст: техработы у Gutenberg или нет интернета
    @State private var loadError: String?
    @State private var audiobooks: [LibriVox.Audiobook] = LibriVox.featured
    @State private var downloadingAudio: Set<Int> = []
    /// Аудиокнига, для которой спрашиваем: скачать целиком или слушать онлайн
    @State private var pendingAudio: LibriVox.Audiobook?

    var body: some View {
        NavigationStack {
            List {
                if kind == .audiobooks {
                    audiobookList
                } else {
                if isLoading && entries.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                ForEach(entries) { entry in
                    row(entry)
                        .listRowBackground(Color.cardBackground)
                }
                if !isLoading && entries.isEmpty {
                    Text(loadError ?? (query.isEmpty ? "Каталог недоступен — проверьте интернет." : "Ничего не нашлось. Попробуйте название или автора на английском."))
                        .foregroundStyle(Color.brandMuted)
                        .listRowBackground(Color.clear)
                }
                }
            }
            .brandListBackground()
            .safeAreaInset(edge: .top) {
                Picker("Каталог", selection: $kind) {
                    ForEach(CatalogKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.brandBackground)
            }
            .onChange(of: kind) { _, _ in Task { await load() } }
            .confirmationDialog(pendingAudio.map { "«\($0.title)» · \(LibriVox.durationText($0.seconds))" } ?? "",
                                isPresented: Binding(get: { pendingAudio != nil }, set: { if !$0 { pendingAudio = nil } }),
                                titleVisibility: .visible, presenting: pendingAudio) { audiobook in
                Button("Скачать текст и аудио (≈ \(ByteCountFormatter.string(fromByteCount: audiobook.estimatedBytes, countStyle: .file)))") {
                    Task { await addAudiobook(audiobook, downloadAudio: true) }
                }
                Button("Только текст, слушать онлайн") {
                    Task { await addAudiobook(audiobook, downloadAudio: false) }
                }
                Button("Отмена", role: .cancel) {}
            } message: { _ in
                Text("Книга появится в библиотеке и в разделе «Аудио». Аудио можно скачать и позже, на странице книги.")
            }
            .navigationTitle(kind == .audiobooks ? (query.isEmpty ? "Аудиокниги" : "Поиск") : (query.isEmpty ? "Популярные книги" : "Поиск"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: kind == .audiobooks ? "Начало названия или фамилия (англ.)" : "Название или автор (англ.)")
            .onSubmit(of: .search) { Task { await load() } }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { Task { await load() } }
            }
            .task { await load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(kind == .audiobooks
                     ? "LibriVox — классику читают вслух люди-волонтёры. Записи — общественное достояние."
                     : "Project Gutenberg — бесплатные книги, ставшие общественным достоянием.")
                    .font(.footnote)
                    .foregroundStyle(Color.brandMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
            .alert("Не получилось", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func row(_ entry: GutenbergCatalog.Entry) -> some View {
        let isInLibrary = books.contains { $0.gutenbergID == entry.id }
        return HStack(spacing: 12) {
            RemoteCover(url: entry.coverURL)
                .frame(width: 46, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .lineLimit(2)
                Text(entry.author)
                    .font(.subheadline)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
            }
            Spacer()
            if isInLibrary {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .accessibilityLabel("В библиотеке")
            } else if downloading.contains(entry.id) {
                ProgressView()
            } else {
                Button { Task { await download(entry) } } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.brandTint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Скачать")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if kind == .audiobooks {
            let text = query.trimmingCharacters(in: .whitespaces)
            audiobooks = text.isEmpty ? LibriVox.featured : ((try? await LibriVox.search(text)) ?? [])
        } else {
            do {
                entries = try await GutenbergCatalog.search(query)
                loadError = nil
            } catch {
                entries = []
                loadError = GutenbergCatalog.failureText(error, action: "Открыть каталог")
            }
        }
    }

    // MARK: - Аудиокниги

    @ViewBuilder
    private var audiobookList: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView("LibriVox отвечает не сразу…")
                Spacer()
            }
            .listRowBackground(Color.clear)
        } else if audiobooks.isEmpty {
            Text("Ничего не нашлось. Попробуйте начало названия без «The» или фамилию автора на английском.")
                .foregroundStyle(Color.brandMuted)
                .listRowBackground(Color.clear)
        } else {
            ForEach(audiobooks) { audiobook in
                audiobookRow(audiobook)
                    .listRowBackground(Color.cardBackground)
            }
        }
    }

    private func audiobookRow(_ audiobook: LibriVox.Audiobook) -> some View {
        let book = books.first { $0.gutenbergID == audiobook.gutenbergID }
        let hasAudio = book.map { LiveAudioStore.audiobook(book: $0.id) != nil } ?? false
        return HStack(spacing: 12) {
            RemoteCover(url: audiobook.coverURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(audiobook.title)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .lineLimit(2)
                Text(audiobook.author)
                    .font(.subheadline)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
                Text(([LibriVox.durationText(audiobook.seconds), audiobook.readerText]).filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
            }
            Spacer()
            if hasAudio {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .accessibilityLabel("В библиотеке")
            } else if downloadingAudio.contains(audiobook.id) {
                ProgressView()
            } else {
                Button { pendingAudio = audiobook } label: {
                    Image(systemName: "headphones.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.brandTint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Добавить аудиокнигу")
            }
        }
    }

    /// Текст книги — из Gutenberg (если его ещё нет в библиотеке), рядом — запись LibriVox
    private func addAudiobook(_ item: LibriVox.Audiobook, downloadAudio: Bool) async {
        guard let gutenbergID = item.gutenbergID else { return }
        downloadingAudio.insert(item.id)
        defer { downloadingAudio.remove(item.id) }
        do {
            // В готовом списке главы не хранятся — берём полную запись
            let audiobook: LibriVox.Audiobook
            if item.sections.isEmpty {
                guard let full = try await LibriVox.details(id: item.id) else { throw URLError(.fileDoesNotExist) }
                audiobook = full
            } else {
                audiobook = item
            }
            let book: Book
            if let existing = books.first(where: { $0.gutenbergID == gutenbergID }) {
                book = existing
            } else {
                let entry = GutenbergCatalog.Entry(id: gutenbergID, title: item.title, author: item.author)
                if let parsed = try? await GutenbergCatalog.downloadBook(entry) {
                    book = Book(parsed, gutenbergID: gutenbergID)
                } else {
                    // Gutenberg не ответил — слушать можно и без текста, он подтянется позже
                    book = Book(GutenbergCatalog.placeholder(title: item.title, author: item.author), gutenbergID: gutenbergID)
                    book.isTextPending = true
                    book.coverData = await RemoteImage.data(item.coverURL)
                }
                modelContext.insert(book)
                try? modelContext.save()
            }
            try LiveAudioStore.save(audiobook, book: book.id)
            if downloadAudio { LiveAudioDownloader.shared.start(book: book.id) }
        } catch {
            errorMessage = "Не удалось добавить «\(item.title)»: LibriVox не ответил. Проверьте интернет и попробуйте ещё раз."
        }
    }

    private func download(_ entry: GutenbergCatalog.Entry) async {
        downloading.insert(entry.id)
        defer { downloading.remove(entry.id) }
        do {
            let parsed = try await GutenbergCatalog.downloadBook(entry)
            modelContext.insert(Book(parsed, gutenbergID: entry.id))
            try? modelContext.save()
        } catch {
            errorMessage = "Не удалось скачать «\(entry.title)». " + GutenbergCatalog.failureText(error, action: "Скачать книгу")
        }
    }
}

/// Обложка из каталога. Не AsyncImage: в iOS 18 он вызывает своё замыкание из фонового потока отрисовки,
/// а в Swift 6 замыкание считается «главнопоточным» — приложение падало (_dispatch_assert_queue_fail).
/// Здесь сеть — в фоне, картинка ставится на главном потоке; скачанные хранятся в памяти на время работы
private struct RemoteCover: View {
    let url: URL?

    @State private var image: UIImage?

    private static let cache = NSCache<NSURL, UIImage>()

    var body: some View {
        ZStack {
            Color.brandTint.opacity(0.25)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { return }
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let loaded = UIImage(data: data) else { return }
        Self.cache.setObject(loaded, forKey: url as NSURL)
        image = loaded
    }
}

/// Картинка целиком (для обложки книги без текста — берём обложку записи LibriVox)
enum RemoteImage {
    static func data(_ url: URL?) async -> Data? {
        guard let url, let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200, UIImage(data: data) != nil else { return nil }
        return data
    }
}
