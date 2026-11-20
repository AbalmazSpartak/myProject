import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

/// Виджет «Слово дня из книги»: слово, которое вы взяли в словарь из книги, перевод и предложение из текста.
/// Слово меняется раз в сутки; книг со словами ещё нет — слово дня из общей базы
struct BookWordWidget: Widget {
    static let kind = "BookWordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: BookWordProvider()) { entry in
            BookWordWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Слово дня из книги")
        .description("Слово из ваших книг: перевод и предложение из текста. Новое слово каждый день.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BookWordEntry: TimelineEntry {
    struct Item {
        let english: String
        let transcription: String
        let partOfSpeech: String
        let russian: String
        let example: AttributedString
        /// Название словаря книги; nil — слово из общей базы
        let source: String?
    }

    let date: Date
    let item: Item?
}

struct BookWordProvider: TimelineProvider {
    func placeholder(in context: Context) -> BookWordEntry {
        BookWordEntry(date: Date(), item: .init(
            english: "peep", transcription: "/piːp/", partOfSpeech: "гл.", russian: "заглядывать, подглядывать",
            example: Word.attributedExample("She had <b>peeped</b> into the book her sister was reading."),
            source: "Alice’s Adventures in Wonderland"))
    }

    func getSnapshot(in context: Context, completion: @escaping (BookWordEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BookWordEntry>) -> Void) {
        // Слово сутки то же; в полночь выбирается следующее
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [Self.entry(for: Date())], policy: .after(midnight)))
    }

    static func entry(for date: Date) -> BookWordEntry {
        guard let container = try? ReviewStore.container() else { return BookWordEntry(date: date, item: nil) }
        let context = ModelContext(container)
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0

        // Слова из книг: те, что лежат в своих словарях и с примером из текста
        var descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { !$0.lists.isEmpty && $0.example != "" },
            sortBy: [SortDescriptor(\.english)]
        )
        descriptor.fetchLimit = 2000
        let fromBooks = (try? context.fetch(descriptor)) ?? []
        if !fromBooks.isEmpty {
            let word = fromBooks[day % fromBooks.count]
            return BookWordEntry(date: date, item: item(word, source: word.lists.first?.name))
        }

        // Книжных слов нет — слово дня из базы с примером
        var base = FetchDescriptor<Word>(
            predicate: #Predicate { !$0.isCustom && $0.example != "" },
            sortBy: [SortDescriptor(\.english)]
        )
        base.fetchLimit = 3000
        let words = (try? context.fetch(base)) ?? []
        guard !words.isEmpty else { return BookWordEntry(date: date, item: nil) }
        return BookWordEntry(date: date, item: item(words[day % words.count], source: nil))
    }

    private static func item(_ word: Word, source: String?) -> BookWordEntry.Item {
        .init(english: word.english, transcription: word.displayTranscription, partOfSpeech: word.russianPartOfSpeech,
              russian: word.russian, example: word.attributedExample, source: source)
    }
}

struct BookWordWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BookWordEntry

    var body: some View {
        Group {
            if let item = entry.item {
                family == .systemSmall ? AnyView(small(item)) : AnyView(medium(item))
            } else {
                Text("Слов с примерами пока нет")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(WidgetPalette.text)
    }

    private func small(_ item: BookWordEntry.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.source == nil ? "Слово дня" : "Слово из книги")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.english)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if !item.transcription.isEmpty {
                Text(item.transcription).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(item.russian)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ item: BookWordEntry.Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.source == nil ? "Слово дня" : "Слово из книги")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.english)
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if !item.transcription.isEmpty {
                            Text(item.transcription).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                Button(intent: SpeakWordIntent(text: item.english)) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(WidgetPalette.fill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Произнести")
            }
            Text(item.russian)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
            Text(item.example)
                .font(.system(size: 14, design: .serif))
                .lineLimit(3)
            Spacer(minLength: 0)
            if let source = item.source {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
