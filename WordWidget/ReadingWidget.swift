import WidgetKit
import SwiftUI
import SwiftData
import ImageIO

/// Виджет «Продолжить чтение»: обложка, название и сколько прочитано; нажатие открывает книгу на том же месте
struct ReadingWidget: Widget {
    static let kind = "ReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ReadingProvider()) { entry in
            ReadingWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Продолжить чтение")
        .description("Последняя открытая книга: нажмите, чтобы продолжить с того же места.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReadingEntry: TimelineEntry {
    struct Book {
        let id: UUID
        let title: String
        let author: String
        let progress: Double
        let cover: UIImage?
    }

    let date: Date
    /// nil — книг ещё не открывали
    let book: Book?
}

struct ReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: Date(), book: .init(id: UUID(), title: "Alice’s Adventures in Wonderland", author: "Lewis Carroll",
                                               progress: 0.42, cover: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        // Приложение обновляет виджет, уходя в фон; раз в час — на случай, если этого не случилось
        completion(Timeline(entries: [Self.currentEntry()], policy: .after(Date().addingTimeInterval(3600))))
    }

    static func currentEntry(now: Date = Date()) -> ReadingEntry {
        guard let container = try? ReviewStore.container() else { return ReadingEntry(date: now, book: nil) }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.lastOpenedAt != nil },
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let book = (try? context.fetch(descriptor))?.first else { return ReadingEntry(date: now, book: nil) }
        let progress = book.paragraphCount > 0 ? min(1, Double(book.position) / Double(book.paragraphCount)) : 0
        return ReadingEntry(date: now, book: .init(id: book.id, title: book.title, author: book.author, progress: progress,
                                                   cover: book.coverData.flatMap { Self.thumbnail($0) }))
    }

    /// Обложки бывают в несколько мегабайт, а у виджета мало памяти — берём маленькую копию
    private static func thumbnail(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

struct ReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReadingEntry

    var body: some View {
        Group {
            if let book = entry.book {
                content(book)
                    .widgetURL(URL(string: "lexistream://read/\(book.id.uuidString)"))
            } else {
                empty
            }
        }
        .foregroundStyle(WidgetPalette.text)
    }

    @ViewBuilder
    private func content(_ book: ReadingEntry.Book) -> some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                cover(book, height: 70)
                Text(book.title)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineLimit(2)
                Spacer(minLength: 0)
                progressBar(book)
                Text("Продолжить · \(percent(book))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 14) {
                cover(book, height: 118)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Продолжить чтение")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(book.title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .lineLimit(2)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    progressBar(book)
                    Text("Прочитано \(percent(book))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func percent(_ book: ReadingEntry.Book) -> String { "\(Int((book.progress * 100).rounded()))%" }

    private func cover(_ book: ReadingEntry.Book, height: CGFloat) -> some View {
        Group {
            if let cover = book.cover {
                Image(uiImage: cover).resizable().scaledToFill()
            } else {
                ZStack {
                    WidgetPalette.accent
                    Image(systemName: "book.closed").font(.title2).foregroundStyle(WidgetPalette.text.opacity(0.6))
                }
            }
        }
        .frame(width: height * 2 / 3, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }

    private func progressBar(_ book: ReadingEntry.Book) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.fill)
                Capsule().fill(WidgetPalette.text.opacity(0.75)).frame(width: proxy.size.width * book.progress)
            }
        }
        .frame(height: 4)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "book.closed").font(.title)
            Text("Откройте книгу в LexiStream, и здесь появится «Продолжить»")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
