import SwiftUI

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

    /// Книги с озвучкой: последняя открытая сверху
    private var audioBooks: [Book] {
        books.filter { infos[$0.id] != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if !isLoaded {
                Color.clear
            } else if audioBooks.isEmpty {
                TabPlaceholder(icon: "headphones", title: "Пока нет озвучки",
                               text: "Откройте книгу и нажмите «Записать озвучку» на её странице — книга появится здесь.")
            } else {
                content
            }
        }
        // Заново при каждом показе раздела: озвучка могла дозаписаться
        .task(id: books.map(\.id)) { await load() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let first = audioBooks.first { continueCard(first) }
                Text("ОЗВУЧЕНО")
                    .scaledFont(size: 12, weight: .medium)
                    .tracking(0.5)
                    .foregroundColor(.gray)
                    .padding(.top, 12)
                ForEach(audioBooks) { book in
                    row(book)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Части экрана

    private func continueCard(_ book: Book) -> some View {
        Button { listen(book) } label: {
            HStack(spacing: 14) {
                cover(book, width: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ПРОДОЛЖИТЬ СЛУШАТЬ")
                        .scaledFont(size: 12, weight: .medium)
                        .tracking(0.5)
                        .foregroundColor(.gray)
                    Text(book.title)
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text("Прочитано \(Int((book.progress * 100).rounded()))%")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                    ProgressView(value: book.progress)
                        .tint(.brandTint)
                }
                playButton(size: 48)
            }
            .padding(14)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    if let info = infos[book.id] {
                        Text(infoText(info))
                            .scaledFont(size: 12)
                            .foregroundColor(.gray)
                    }
                }
                Spacer(minLength: 0)
                playButton(size: 40)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Слушать: \(book.title)")
    }

    private func cover(_ book: Book, width: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: width * 1.5)
            .overlay { BookCover(data: book.coverData, title: book.title) }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    private func playButton(size: CGFloat) -> some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.38))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(Color.brandTint, in: Circle())
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
        isLoaded = true
    }
}
