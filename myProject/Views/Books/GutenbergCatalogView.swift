import SwiftUI
import SwiftData

/// Что показывает каталог: книги Gutenberg или аудиокниги LibriVox с живым голосом
enum CatalogKind: String, CaseIterable, Identifiable {
    case books, audiobooks
    var id: Self { self }
    var title: String { self == .books ? "Книги" : "Аудиокниги" }
}

/// Порядок аудиокниг. У LibriVox нет популярности и оценок — сортируем по тому, что есть
enum AudioSort: String, CaseIterable, Identifiable {
    case recommended, shorter, longer, title, newest
    var id: Self { self }
    var title: String {
        switch self {
        case .recommended: "Рекомендуемые"
        case .shorter: "Короче"
        case .longer: "Длиннее"
        case .title: "По названию"
        case .newest: "Новые записи"
        }
    }
    var icon: String {
        switch self {
        case .recommended: "star"
        case .shorter: "clock"
        case .longer: "clock.fill"
        case .title: "textformat"
        case .newest: "sparkles"
        }
    }
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
    /// Книга по этому номеру Gutenberg уже добавляется (текст качается) — второй раз не начинаем
    @State private var addingGutenberg: Set<Int> = []
    /// Скачанная книга похожа на ту, что уже в библиотеке — ждёт решения
    @State private var pendingImport: PendingBookImport?
    @State private var errorMessage: String?
    @State private var kind: CatalogKind = .books
    /// Почему список пуст: техработы у Gutenberg или нет интернета
    @State private var loadError: String?
    @State private var audiobooks: [LibriVox.Audiobook] = LibriVox.featured
    @State private var downloadingAudio: Set<Int> = []
    /// Аудиокнига, для которой спрашиваем: скачать целиком или слушать онлайн
    @State private var pendingAudio: LibriVox.Audiobook?
    /// Другой чтец для книги, у которой уже выбрана запись
    @State private var pendingReader: LibriVox.Audiobook?
    /// Меняется после выбора записи — строки перечитывают, какая запись у книги
    @State private var audioVersion = 0
    @AppStorage("audio_catalog_sort") private var audioSort: AudioSort = .recommended

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
                // Сортировка — рядом с переключателем: панель сверху во время поиска прячется
                VStack(spacing: 8) {
                    if AppDesign.isSketch {
                        SketchTabs(items: CatalogKind.allCases, title: \.title, selection: $kind)
                            .padding(.horizontal, 4)
                    } else {
                        Picker("Каталог", selection: $kind) {
                            ForEach(CatalogKind.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    if kind == .audiobooks {
                        HStack {
                            Text(audiobooks.isEmpty ? "" : "Записей: \(audiobooks.count)")
                                .font(.footnote)
                                .foregroundStyle(Color.brandMuted)
                            Spacer()
                            Menu {
                                Picker("Сортировка", selection: $audioSort) {
                                    ForEach(AudioSort.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                                }
                            } label: {
                                Label(audioSort.title, systemImage: "arrow.up.arrow.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.brandTint)
                            }
                            .accessibilityLabel("Сортировка: \(audioSort.title)")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.brandBackground)
            }
            .onChange(of: kind) { _, _ in Task { await load() } }
            .lxDialog(pendingAudio.map { "«\($0.title)» · \(LibriVox.durationText($0.seconds))" } ?? "",
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
            .lxDialog("Выбрать этого чтеца?", isPresented: Binding(get: { pendingReader != nil }, set: { if !$0 { pendingReader = nil } }),
                                titleVisibility: .visible, presenting: pendingReader) { audiobook in
                let downloaded = downloadedOfCurrent(for: audiobook)
                Button(downloaded > 0 ? "Выбрать и удалить скачанное (\(downloaded) глав)" : "Выбрать",
                       role: downloaded > 0 ? .destructive : nil) {
                    Task { await chooseReader(audiobook) }
                }
                Button("Отмена", role: .cancel) {}
            } message: { audiobook in
                Text(downloadedOfCurrent(for: audiobook) > 0
                     ? "У книги уже есть другой чтец со скачанными главами — они удалятся. Новый чтец играет онлайн, скачать его можно на странице книги."
                     : "Новый чтец заменит прежнего. Он играет онлайн, скачать его можно на странице книги.")
            }
            .navigationTitle(kind == .audiobooks ? (query.isEmpty ? "Аудиокниги" : "Поиск") : (query.isEmpty ? "Популярные книги" : "Поиск"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: kind == .audiobooks ? "Начало названия или фамилия (англ.)" : "Название или автор (англ.)")
            .onSubmit(of: .search) { Task { await load() } }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { Task { await load() } }
            }
            .bookImportPrompts(pending: $pendingImport, books: books, onAdded: { _ in }, onOpenExisting: { _ in })
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
            .lxAlert("Не получилось", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
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
            .sketchFrame(AppDesign.isSketch, radius: 4, shadow: NewStyle.yellow, offset: 3)
            .padding(.trailing, AppDesign.isSketch ? 3 : 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .lxBookTitleFont()
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
            ForEach(sortedAudiobooks) { audiobook in
                audiobookRow(audiobook)
                    .listRowBackground(Color.cardBackground)
            }
        }
    }

    /// Сколько человек читает: в готовом списке чтецы не записаны — там везде один
    private static func readerCount(_ audiobook: LibriVox.Audiobook) -> Int { max(audiobook.readers.count, 1) }

    private var sortedAudiobooks: [LibriVox.Audiobook] {
        _ = audioVersion
        // Какая запись выбрана у книг из библиотеки: номер Gutenberg → номер записи LibriVox
        var mine: [Int: Int] = [:]
        for book in books {
            if let id = book.gutenbergID, let saved = LiveAudioStore.audiobook(book: book.id) { mine[id] = saved.id }
        }
        func isMine(_ audiobook: LibriVox.Audiobook) -> Bool { audiobook.gutenbergID.map { mine[$0] == audiobook.id } ?? false }
        let list = audiobooks
        switch audioSort {
        case .recommended:
            // Записи одной книги — вместе; книги, где запись уже у вас, — первыми; внутри книги: ваша, потом один чтец
            var groupOrder: [Int: Int] = [:]
            for (index, audiobook) in list.enumerated() {
                let key = audiobook.gutenbergID ?? -audiobook.id
                if groupOrder[key] == nil { groupOrder[key] = index }
            }
            let mineGroups = Set(list.filter(isMine).compactMap(\.gutenbergID))
            return list.sorted { a, b in
                let ka = a.gutenbergID ?? -a.id, kb = b.gutenbergID ?? -b.id
                let ga = (mineGroups.contains(ka) ? 0 : 1, groupOrder[ka] ?? 0)
                let gb = (mineGroups.contains(kb) ? 0 : 1, groupOrder[kb] ?? 0)
                if ga != gb { return ga < gb }
                return (isMine(a) ? 0 : 1, Self.readerCount(a), a.id) < (isMine(b) ? 0 : 1, Self.readerCount(b), b.id)
            }
        case .shorter:
            return list.sorted { ($0.seconds, $0.id) < ($1.seconds, $1.id) }
        case .longer:
            return list.sorted { ($0.seconds, $1.id) > ($1.seconds, $0.id) }
        case .title:
            return list.sorted {
                let order = $0.title.localizedCaseInsensitiveCompare($1.title)
                return order == .orderedSame ? Self.readerCount($0) < Self.readerCount($1) : order == .orderedAscending
            }
        case .newest:
            return list.sorted { $0.id > $1.id }
        }
    }

    private func audiobookRow(_ audiobook: LibriVox.Audiobook) -> some View {
        _ = audioVersion
        let book = books.first { $0.gutenbergID == audiobook.gutenbergID }
        let saved = book.flatMap { LiveAudioStore.audiobook(book: $0.id) }
        let isChosen = saved?.id == audiobook.id
        return HStack(spacing: 12) {
            RemoteCover(url: audiobook.coverURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .sketchFrame(AppDesign.isSketch, radius: 6, shadow: NewStyle.yellow, offset: 3)
                .padding(.trailing, AppDesign.isSketch ? 3 : 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(audiobook.title)
                    .lxBookTitleFont()
                    .lineLimit(2)
                Text(audiobook.author)
                    .font(.subheadline)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
                Text(([LibriVox.durationText(audiobook.seconds), audiobook.readerText]).filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
                if let book, let saved, isChosen {
                    let downloaded = LiveAudioStore.downloadedCount(book: book.id, audiobook: saved)
                    Text(downloaded == saved.sections.count ? "У вас · скачана целиком"
                         : downloaded > 0 ? "У вас · скачано \(downloaded) из \(saved.sections.count) глав" : "У вас · слушаете онлайн")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            if isChosen {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .accessibilityLabel("Эта запись у вас")
            } else if downloadingAudio.contains(audiobook.id) {
                ProgressView()
            } else {
                Button { if saved != nil { pendingReader = audiobook } else { pendingAudio = audiobook } } label: {
                    Image(systemName: "headphones.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.brandTint)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(saved != nil ? "Выбрать этого чтеца" : "Добавить аудиокнигу")
            }
        }
    }

    /// Сколько глав скачано у записи, которую заменит этот чтец
    private func downloadedOfCurrent(for audiobook: LibriVox.Audiobook) -> Int {
        guard let book = books.first(where: { $0.gutenbergID == audiobook.gutenbergID }),
              let saved = LiveAudioStore.audiobook(book: book.id) else { return 0 }
        return LiveAudioStore.downloadedCount(book: book.id, audiobook: saved)
    }

    /// Другой чтец для книги из библиотеки: прежняя запись (и её скачанные главы) уходит, новая играет онлайн
    private func chooseReader(_ item: LibriVox.Audiobook) async {
        guard let book = books.first(where: { $0.gutenbergID == item.gutenbergID }) else { return }
        downloadingAudio.insert(item.id)
        defer { downloadingAudio.remove(item.id) }
        do {
            let audiobook = item.sections.isEmpty ? try await LibriVox.details(id: item.id) : item
            guard let audiobook else { throw URLError(.fileDoesNotExist) }
            try LiveAudioPlayer.shared.replaceRecording(book: book.id, with: audiobook)
            audioVersion += 1
        } catch {
            errorMessage = "Не удалось выбрать чтеца: LibriVox не ответил. Проверьте интернет и попробуйте ещё раз."
        }
    }

    /// Текст книги — из Gutenberg (если его ещё нет в библиотеке), рядом — запись LibriVox
    private func addAudiobook(_ item: LibriVox.Audiobook, downloadAudio: Bool) async {
        guard let gutenbergID = item.gutenbergID, !addingGutenberg.contains(gutenbergID) else { return }
        addingGutenberg.insert(gutenbergID)
        defer { addingGutenberg.remove(gutenbergID) }
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
                    book = await Book.make(parsed, gutenbergID: gutenbergID)
                } else {
                    // Gutenberg не ответил — слушать можно и без текста, он подтянется позже
                    book = Book(GutenbergCatalog.placeholder(title: item.title, author: item.author), gutenbergID: gutenbergID)
                    book.isTextPending = true
                    book.coverData = await RemoteImage.data(item.coverURL)
                }
                modelContext.insert(book)
                modelContext.saveReporting()
            }
            try LiveAudioStore.save(audiobook, book: book.id)
            audioVersion += 1
            if downloadAudio { LiveAudioDownloader.shared.start(book: book.id) }
        } catch {
            errorMessage = "Не удалось добавить «\(item.title)»: LibriVox не ответил. Проверьте интернет и попробуйте ещё раз."
        }
    }

    private func download(_ entry: GutenbergCatalog.Entry) async {
        guard !addingGutenberg.contains(entry.id), !books.contains(where: { $0.gutenbergID == entry.id }) else { return }
        addingGutenberg.insert(entry.id)
        defer { addingGutenberg.remove(entry.id) }
        downloading.insert(entry.id)
        defer { downloading.remove(entry.id) }
        do {
            let parsed = try await GutenbergCatalog.downloadBook(entry)
            // Тот же текст под другим номером или другое издание — спросим; новая книга добавляется сразу
            _ = await BookImportCheck.add(parsed, gutenbergID: entry.id, books: books, context: modelContext, pending: $pendingImport)
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
