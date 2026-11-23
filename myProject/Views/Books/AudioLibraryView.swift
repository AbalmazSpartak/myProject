import SwiftUI

/// Порядок книг в «Аудио»
enum AudioLibrarySort: String, CaseIterable, Identifiable {
    case recent, title, author, downloaded
    var id: Self { self }
    var title: String {
        switch self {
        case .recent: "Недавние"
        case .title: "По названию"
        case .author: "По автору"
        case .downloaded: "Скачанные сначала"
        }
    }
}

/// «Аудио» в библиотеке: «Продолжить слушать» и список книг с записанной озвучкой
struct AudioLibraryView: View {
    let books: [Book]
    /// Открыть книгу и сразу включить озвучку
    let listen: (Book) -> Void

    /// Сколько глав записано, сколько их всего и сколько места занимает озвучка
    private struct Info {
        let recorded: Int
        let total: Int
        let bytes: Int64
    }

    @State private var infos: [UUID: Info] = [:]
    @State private var isLoaded = false
    /// Книги с живой озвучкой LibriVox и сколько в ней глав
    @State private var live: [UUID: (downloaded: Int, total: Int)] = [:]
    @State private var liveBook: Book?
    @State private var player = LiveAudioPlayer.shared
    @AppStorage("audio_library_sort") private var sort: AudioLibrarySort = .recent
    @State private var searchText = ""

    /// Без регистра, ё как е, ’ как ' — как поиск в «Моих книгах»
    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "’", with: "'")
    }

    private var isSearching: Bool { !Self.normalized(searchText).isEmpty }

    /// Книги, у которых название или автор содержат запрос
    private func filtered(_ list: [Book]) -> [Book] {
        let query = Self.normalized(searchText)
        guard !query.isEmpty else { return list }
        return list.filter { Self.normalized($0.title).contains(query) || Self.normalized($0.author).contains(query) }
    }

    /// Доля скачанного: живой голос — главы на устройстве, записанная озвучка — записанные главы
    private func downloadedShare(_ book: Book) -> Double {
        if let info = live[book.id] { return info.total > 0 ? Double(info.downloaded) / Double(info.total) : 0 }
        if let info = infos[book.id] { return info.total > 0 ? Double(info.recorded) / Double(info.total) : 0 }
        return 0
    }

    private func sorted(_ list: [Book]) -> [Book] {
        let recent = list.sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
        switch sort {
        case .recent:
            return recent
        case .title:
            return list.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .author:
            return list.sorted {
                let order = $0.author.localizedCaseInsensitiveCompare($1.author)
                return order == .orderedSame ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending : order == .orderedAscending
            }
        case .downloaded:
            // Порядок среди одинаково скачанных — как в «Недавних»
            return recent.enumerated().sorted { a, b in
                let da = downloadedShare(a.element), db = downloadedShare(b.element)
                return da != db ? da > db : a.offset < b.offset
            }.map(\.element)
        }
    }

    /// Поле поиска и порядок — как в «Моих книгах»: плашка с лупой и крестиком, рядом квадратная кнопка ↕
    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.brandMuted)
                TextField("Поиск аудиокниг", text: $searchText)
                    .scaledFont(size: 16)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.brandMuted)
                    }
                    .accessibilityLabel("Очистить поиск")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .cardPlate(radius: 12)
            LXMenu {
                LXMenuPicker(title: "Порядок", selection: $sort, options: AudioLibrarySort.allCases) { Text($0.title) }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .scaledFont(size: 16)
                    .foregroundColor(.brandDark)
                    .frame(width: 44, height: 44)
                    .cardPlate(radius: 12)
            }
            .accessibilityLabel("Порядок аудиокниг: \(sort.title)")
        }
    }

    private var liveBooks: [Book] {
        books.filter { live[$0.id] != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    /// Книги с озвучкой: последняя открытая сверху
    private var audioBooks: [Book] {
        books.filter { infos[$0.id] != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if !isLoaded {
                Color.clear
            } else if audioBooks.isEmpty && liveBooks.isEmpty {
                TabPlaceholder(icon: "headphones", title: "Пока нет озвучки",
                               text: "Откройте книгу и нажмите «Записать озвучку» на её странице или возьмите аудиокнигу с живым голосом в каталоге — книга появится здесь.")
            } else {
                content
            }
        }
        // Заново при каждом показе раздела: озвучка могла дозаписаться
        .task(id: books.map(\.id)) { await load() }
        .navigationDestination(item: $liveBook) { book in
            LiveAudioPlayerView(book: book)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                searchField
                if isSearching, filtered(liveBooks).isEmpty, filtered(audioBooks).isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 24)
                }
                // Пока ищут — без «Продолжить слушать», только найденное
                if !isSearching, let first = audioBooks.first { continueCard(first).padding(.top, 6) }
                if !filtered(liveBooks).isEmpty {
                    sectionTitle("ЖИВОЙ ГОЛОС")
                    ForEach(sorted(filtered(liveBooks))) { book in
                        liveRow(book)
                    }
                }
                if !filtered(audioBooks).isEmpty {
                    sectionTitle("ОЗВУЧЕНО")
                    ForEach(sorted(filtered(audioBooks))) { book in
                        row(book)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Части экрана

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 12, weight: .medium)
            .tracking(0.5)
            .foregroundColor(Color.brandMuted)
            .padding(.top, 12)
    }

    /// Живая озвучка LibriVox: открывается свой плеер, без читалки
    private func liveRow(_ book: Book) -> some View {
        Button { liveBook = book } label: {
            HStack(spacing: 12) {
                cover(book, width: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .scaledFont(size: 13)
                            .foregroundColor(Color.brandMuted)
                            .lineLimit(1)
                    }
                    if let info = live[book.id] {
                        Text(player.isCurrent(book.id) && player.isPlaying ? "Сейчас играет"
                             : (info.downloaded == info.total ? "Скачано: \(info.total) глав" : "Скачано \(info.downloaded) из \(info.total) глав · остальное онлайн"))
                            .scaledFont(size: 12)
                            .foregroundColor(Color.brandMuted)
                    }
                }
                Spacer(minLength: 0)
                playButton(size: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .cardPlate(radius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Слушать живой голос: \(book.title)")
    }

    private func continueCard(_ book: Book) -> some View {
        Button { listen(book) } label: {
            HStack(spacing: 14) {
                cover(book, width: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПРОДОЛЖИТЬ СЛУШАТЬ")
                        .scaledFont(size: 12, weight: .medium)
                        .tracking(0.5)
                        .foregroundColor(Color.brandMuted)
                    Text(book.title)
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text("Прочитано \(Int((book.progress * 100).rounded()))%")
                        .scaledFont(size: 13)
                        .foregroundColor(Color.brandMuted)
                    if AppDesign.isSketch {
                        SketchProgress(value: book.progress)
                    } else {
                        ProgressView(value: book.progress)
                            .tint(.brandTint)
                    }
                }
                playButton(size: 48)
            }
            .padding(14)
            .cardPlate(radius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Продолжить слушать: \(book.title)")
    }

    private func row(_ book: Book) -> some View {
        Button { listen(book) } label: {
            HStack(spacing: 12) {
                cover(book, width: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .scaledFont(size: 13)
                            .foregroundColor(Color.brandMuted)
                            .lineLimit(1)
                    }
                    if let info = infos[book.id] {
                        Text(infoText(info))
                            .scaledFont(size: 12)
                            .foregroundColor(Color.brandMuted)
                    }
                }
                Spacer(minLength: 0)
                playButton(size: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .cardPlate(radius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Слушать: \(book.title)")
    }

    private func cover(_ book: Book, width: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: width * 1.5)
            .overlay { BookCover(data: book.coverData, title: book.title, author: book.author) }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(AppDesign.isSketch ? 0 : 0.2), radius: 4, x: 0, y: 2)
            .sketchFrame(AppDesign.isSketch, radius: 8, shadow: NewStyle.yellow, offset: 3)
            .padding(.trailing, AppDesign.isSketch ? 3 : 0)
    }

    private func playButton(size: CGFloat) -> some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.38))
            .foregroundColor(AppDesign.isSketch ? NewStyle.onYellow : .brandOnTint)
            .frame(width: size, height: size)
            .background(AppDesign.isSketch ? NewStyle.yellow : Color.brandButton, in: Circle())
            .overlay { if AppDesign.isSketch { Circle().stroke(NewStyle.outline, style: NewStyle.stroke) } }
            .background { if AppDesign.isSketch { Circle().fill(NewStyle.yellowShadow).offset(x: 2, y: 2) } }
    }

    private func infoText(_ info: Info) -> String {
        let megabytes = ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file)
        let chapters = info.total > 0 ? "\(info.recorded) из \(info.total) глав" : "\(info.recorded) глав"
        return "Записано \(chapters) · \(megabytes)"
    }

    // MARK: - Данные

    private func load() async {
        let ids = books.map(\.id)
        // Папки озвучки смотрим в фоне; текст книги читаем только у тех, у кого озвучка есть
        let found = await Task.detached(priority: .userInitiated) {
            ids.compactMap { id in AudiobookStore.summary(book: id).map { (id, $0.chapters, $0.bytes) } }
        }.value
        var result: [UUID: Info] = [:]
        for (id, recorded, bytes) in found {
            guard let book = books.first(where: { $0.id == id }) else { continue }
            let data = book.chaptersData
            let total = await Task.detached(priority: .userInitiated) {
                (try? JSONDecoder().decode([BookChapter].self, from: data))?.count ?? 0
            }.value
            result[id] = Info(recorded: recorded, total: total, bytes: bytes)
        }
        infos = result
        var liveInfo: [UUID: (downloaded: Int, total: Int)] = [:]
        for book in books {
            if let audiobook = LiveAudioStore.audiobook(book: book.id) {
                liveInfo[book.id] = (LiveAudioStore.downloadedCount(book: book.id, audiobook: audiobook), audiobook.sections.count)
            }
        }
        live = liveInfo
        isLoaded = true
    }
}
