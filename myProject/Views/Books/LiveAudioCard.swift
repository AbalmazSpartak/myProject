import SwiftUI

/// «Живой голос» на странице книги: запись LibriVox той же книги Gutenberg — слушать онлайн, скачать, удалить.
/// Нет записи — карточки нет
struct LiveAudioCard: View {
    let book: Book

    @State private var downloader = LiveAudioDownloader.shared
    @State private var player = LiveAudioPlayer.shared
    @State private var saved: LibriVox.Audiobook?
    @State private var found: [LibriVox.Audiobook] = []
    @State private var choice = 0
    @State private var isSearching = false
    @State private var isListening = false
    @State private var isConfirmingDelete = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if let saved {
                card { savedContent(saved) }
            } else if isSearching {
                card {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Ищу живую озвучку в LibriVox…")
                            .scaledFont(size: 13)
                            .foregroundStyle(Color.brandMuted)
                    }
                }
            } else if !found.isEmpty {
                card { offerContent }
            }
        }
        .navigationDestination(isPresented: $isListening) {
            LiveAudioPlayerView(book: book)
        }
        .task { await load() }
        .onChange(of: downloader.job?.done) { _, _ in saved = LiveAudioStore.audiobook(book: book.id) }
        .lxDialog("Удалить живую озвучку этой книги?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                if downloader.isDownloading(book.id) { downloader.cancel() }
                if player.isCurrent(book.id) { player.stop() }
                LiveAudioStore.delete(book: book.id)
                saved = nil
                Task { await load() }
            }
        } message: {
            Text("Скачанные главы удалятся. Книга останется, озвучку можно будет скачать снова.")
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LXSectionLabel(text: "Живой голос")
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }

    // MARK: - Запись уже выбрана

    @ViewBuilder
    private func savedContent(_ audiobook: LibriVox.Audiobook) -> some View {
        let downloaded = LiveAudioStore.downloadedCount(book: book.id, audiobook: audiobook)
        let total = audiobook.sections.count
        Text(info(audiobook))
            .scaledFont(size: 14)
            .foregroundStyle(Color.brandDark)
        LXButton(title: player.isCurrent(book.id) && player.isPlaying ? "Сейчас играет" : "Слушать живой голос",
                 systemImage: "headphones") { isListening = true }
        if let job = downloader.job, job.book == book.id {
            ProgressView(value: job.fraction).tint(.brandTint)
            Text("Скачиваю: \(job.done) из \(job.total) глав. Слушать можно уже сейчас. Не закрывайте приложение, пока идёт загрузка.")
                .scaledFont(size: 13)
                .foregroundStyle(Color.brandMuted)
            LXButton(title: "Остановить загрузку", systemImage: "stop.circle", style: .soft) { downloader.cancel() }
        } else {
            Text(downloaded == total
                 ? "Скачано целиком · \(ByteCountFormatter.string(fromByteCount: LiveAudioStore.size(book: book.id), countStyle: .file)). Играет без интернета."
                 : "Скачано \(downloaded) из \(total) глав. Остальные играют онлайн.")
                .scaledFont(size: 13)
                .foregroundStyle(Color.brandMuted)
            if let failure = downloader.failure, failure.book == book.id {
                Text(failure.text)
                    .scaledFont(size: 13)
                    .foregroundStyle(Color.statusLearning)
            }
            if downloaded < total {
                LXButton(title: downloaded == 0 ? "Скачать (≈ \(megabytes(audiobook)))" : "Скачать остальное",
                         systemImage: "arrow.down.circle", style: .soft,
                         isEnabled: downloader.job == nil) { downloader.start(book: book.id) }
            }
        }
        LXButton(title: "Удалить живую озвучку", systemImage: "trash", style: .text) { isConfirmingDelete = true }
    }

    // MARK: - Нашли запись, ещё не выбрана

    @ViewBuilder
    private var offerContent: some View {
        let audiobook = found[min(choice, found.count - 1)]
        Text("Эту книгу читает вслух человек — запись LibriVox.")
            .scaledFont(size: 14)
            .foregroundStyle(Color.brandDark)
        Text(info(audiobook))
            .scaledFont(size: 13)
            .foregroundStyle(Color.brandMuted)
        if found.count > 1 {
            LXMenu {
                ForEach(Array(found.enumerated()), id: \.element.id) { index, item in
                    Button("\(item.readerText.capitalizedFirst) · \(LibriVox.durationText(item.seconds))") { choice = index }
                }
            } label: {
                Label("Другой чтец (\(found.count) записи)", systemImage: "person.2")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(Color.brandTint)
            }
        }
        LXButton(title: "Слушать онлайн", systemImage: "play.circle") { use(audiobook, download: false) }
        LXButton(title: "Скачать (≈ \(megabytes(audiobook)))", systemImage: "arrow.down.circle", style: .soft,
                 isEnabled: downloader.job == nil) { use(audiobook, download: true) }
        if let errorText {
            Text(errorText)
                .scaledFont(size: 13)
                .foregroundStyle(Color.statusLearning)
        }
    }

    // MARK: - Действия

    private func use(_ audiobook: LibriVox.Audiobook, download: Bool) {
        do {
            try LiveAudioStore.save(audiobook, book: book.id)
        } catch {
            errorText = "Не получилось сохранить запись на устройстве."
            return
        }
        saved = audiobook
        if download { downloader.start(book: book.id) } else { isListening = true }
    }

    private func load() async {
        saved = LiveAudioStore.audiobook(book: book.id)
        guard saved == nil, book.gutenbergID != nil else { return }
        if let cached = LiveAudioLookup.cached(gutenbergID: book.gutenbergID) {
            found = cached
            return
        }
        isSearching = true
        defer { isSearching = false }
        found = await LiveAudioLookup.recordings(for: book) ?? []
    }

    private func info(_ audiobook: LibriVox.Audiobook) -> String {
        [audiobook.readerText.capitalizedFirst, LibriVox.durationText(audiobook.seconds), "\(audiobook.sections.count) глав"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func megabytes(_ audiobook: LibriVox.Audiobook) -> String {
        ByteCountFormatter.string(fromByteCount: audiobook.estimatedBytes, countStyle: .file)
    }
}
