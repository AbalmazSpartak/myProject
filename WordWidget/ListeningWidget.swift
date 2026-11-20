import WidgetKit
import SwiftUI
import SwiftData
import ImageIO

/// Виджет «Сейчас слушаете»: книга, которую читали вслух последней, глава и сколько прочитано.
/// Нажатие открывает книгу и сразу продолжает озвучку с того же места
struct ListeningWidget: Widget {
    static let kind = "ListeningWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ListeningProvider()) { entry in
            ListeningWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Сейчас слушаете")
        .description("Книга, которую вы слушали последней: нажмите, чтобы продолжить озвучку.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ListeningEntry: TimelineEntry {
    struct Item {
        let id: UUID
        let title: String
        let chapter: String
        let progress: Double
        let cover: UIImage?
    }

    let date: Date
    /// nil — вслух ещё ничего не читали
    let item: Item?
}

struct ListeningProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListeningEntry {
        ListeningEntry(date: Date(), item: .init(id: UUID(), title: "Alice’s Adventures in Wonderland",
                                                 chapter: "Down the Rabbit-Hole", progress: 0.3, cover: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (ListeningEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ListeningEntry>) -> Void) {
        completion(Timeline(entries: [Self.currentEntry()], policy: .after(Date().addingTimeInterval(3600))))
    }

    static func currentEntry(now: Date = Date()) -> ListeningEntry {
        guard let saved = AppGroup.defaults.string(forKey: AppGroup.listeningBookKey), let id = UUID(uuidString: saved),
              let container = try? ReviewStore.container() else { return ListeningEntry(date: now, item: nil) }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let book = (try? context.fetch(descriptor))?.first else { return ListeningEntry(date: now, item: nil) }
        let progress = book.paragraphCount > 0 ? min(1, Double(book.position) / Double(book.paragraphCount)) : 0
        return ListeningEntry(date: now, item: .init(
            id: book.id, title: book.title, chapter: AppGroup.defaults.string(forKey: AppGroup.listeningChapterKey) ?? "",
            progress: progress, cover: book.coverData.flatMap { thumbnail($0) }))
    }

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

struct ListeningWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ListeningEntry

    var body: some View {
        Group {
            if let item = entry.item {
                content(item)
                    .widgetURL(URL(string: "lexistream://listen/\(item.id.uuidString)"))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "headphones").font(.title)
                    Text("Включите озвучку книги в LexiStream, и здесь появится «Продолжить слушать»")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(WidgetPalette.text)
    }

    @ViewBuilder
    private func content(_ item: ListeningEntry.Item) -> some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    cover(item, height: 62)
                    Spacer(minLength: 0)
                    playBadge
                }
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .lineLimit(2)
                Spacer(minLength: 0)
                progressBar(item)
            }
        } else {
            HStack(spacing: 14) {
                cover(item, height: 118)
                VStack(alignment: .leading, spacing: 4) {
                    Label("Сейчас слушаете", systemImage: "headphones")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .lineLimit(2)
                    if !item.chapter.isEmpty {
                        Text(item.chapter)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 10) {
                        progressBar(item)
                        playBadge
                    }
                }
            }
        }
    }

    private var playBadge: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WidgetPalette.background)
            .frame(width: 30, height: 30)
            .background(Circle().fill(WidgetPalette.text.opacity(0.85)))
    }

    private func cover(_ item: ListeningEntry.Item, height: CGFloat) -> some View {
        Group {
            if let cover = item.cover {
                Image(uiImage: cover).resizable().scaledToFill()
            } else {
                ZStack {
                    WidgetPalette.accent
                    Image(systemName: "headphones").font(.title3).foregroundStyle(WidgetPalette.text.opacity(0.6))
                }
            }
        }
        .frame(width: height * 2 / 3, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
    }

    private func progressBar(_ item: ListeningEntry.Item) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.fill)
                Capsule().fill(WidgetPalette.text.opacity(0.75)).frame(width: proxy.size.width * item.progress)
            }
        }
        .frame(height: 4)
    }
}
