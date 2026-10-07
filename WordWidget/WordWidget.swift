import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

/// Виджет «Повторение»: слово, которому пора на повторение по FSRS, → «Показать перевод» → «Знаю» / «Не знаю».
/// Ответ сразу пишется в общую базу и в график профиля, следующее слово появляется без открытия приложения
struct WordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ReviewWidgetState.kind, provider: ReviewProvider()) { entry in
            ReviewWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Повторение")
        .description("Слова, которым пора на повторение: перевод и ответ в одно касание.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Данные

struct ReviewEntry: TimelineEntry {
    struct Card {
        let key: String
        let english: String
        /// Часть речи по-русски: гл., сущ.
        let partOfSpeech: String
        let transcription: String
        let russian: String
        let example: AttributedString
    }

    let date: Date
    let card: Card?
    let isRevealed: Bool
    /// Сколько слов ждёт повторения, вместе с показанным
    let dueCount: Int
    /// Когда подойдёт следующее слово, если сейчас повторять нечего
    let nextDue: Date?
}

/// Что виджет помнит между нажатиями: у какого слова уже открыт перевод
enum ReviewWidgetState {
    static let kind = "WordReviewWidget"
    private static let revealedKey = "widget_revealed_word"

    static var revealedWord: String? {
        get { AppGroup.defaults.string(forKey: revealedKey) }
        set { AppGroup.defaults.set(newValue, forKey: revealedKey) }
    }
}

struct ReviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReviewEntry {
        ReviewEntry(
            date: Date(),
            card: .init(key: "", english: "remember", partOfSpeech: "гл.", transcription: "/rɪˈmembər/", russian: "помнить, вспоминать",
                        example: Word.attributedExample("I <b>remember</b> her name.")),
            isRevealed: false, dueCount: 12, nextDue: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReviewEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Self.currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReviewEntry>) -> Void) {
        let entry = Self.currentEntry()
        // Повторять нечего — обновиться, когда подойдёт следующее слово; иначе — раз в полчаса подтянуть изменения из приложения
        let refresh = entry.card == nil ? (entry.nextDue ?? Date().addingTimeInterval(3600)) : Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(max(refresh, Date().addingTimeInterval(60)))))
    }

    static func currentEntry(now: Date = Date()) -> ReviewEntry {
        guard let container = try? ReviewStore.container() else {
            return ReviewEntry(date: now, card: nil, isRevealed: false, dueCount: 0, nextDue: nil)
        }
        let context = ModelContext(container)
        let scope = AppGroup.defaults.string(forKey: StudyScope.storageKey).flatMap(StudyScope.init(rawValue:)) ?? StudyScope()

        // Новые слова (reps == 0) виджет не даёт — только те, что уже учатся
        var descriptor = FetchDescriptor<Word>(
            predicate: #Predicate { $0.reps > 0 && $0.dueDate <= now },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        descriptor.fetchLimit = 300
        let due = ((try? context.fetch(descriptor)) ?? []).filter { scope.includes($0) }

        guard let word = due.first else {
            var next = FetchDescriptor<Word>(
                predicate: #Predicate { $0.reps > 0 && $0.dueDate > now },
                sortBy: [SortDescriptor(\.dueDate)]
            )
            next.fetchLimit = 1
            let nextDue = (try? context.fetch(next))?.first?.dueDate
            return ReviewEntry(date: now, card: nil, isRevealed: false, dueCount: 0, nextDue: nextDue)
        }
        let key = AppGroup.key(of: word)
        let card = ReviewEntry.Card(
            key: key,
            english: word.english,
            partOfSpeech: word.russianPartOfSpeech,
            transcription: word.displayTranscription,
            russian: word.russian,
            example: word.attributedExample
        )
        return ReviewEntry(date: now, card: card, isRevealed: ReviewWidgetState.revealedWord == key, dueCount: due.count, nextDue: nil)
    }
}

/// Виджет открывает ту же базу, что и приложение, — в общей папке
enum ReviewStore {
    static func container() throws -> ModelContainer {
        guard let url = AppGroup.sharedStoreURL else { throw CocoaError(.fileNoSuchFile) }
        return try ModelContainer(for: AppGroup.schema, configurations: ModelConfiguration(url: url))
    }
}

// MARK: - Кнопки

struct RevealTranslationIntent: AppIntent {
    static let title: LocalizedStringResource = "Показать перевод"
    static let isDiscoverable = false

    @Parameter(title: "Слово") var key: String

    init() {}
    init(key: String) { self.key = key }

    @MainActor func perform() async throws -> some IntentResult {
        ReviewWidgetState.revealedWord = key
        return .result()
    }
}

struct AnswerWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Ответить"
    static let isDiscoverable = false

    @Parameter(title: "Слово") var key: String
    @Parameter(title: "Знаю") var isKnown: Bool

    init() {}
    init(key: String, isKnown: Bool) {
        self.key = key
        self.isKnown = isKnown
    }

    @MainActor func perform() async throws -> some IntentResult {
        let context = ModelContext(try ReviewStore.container())
        guard let word = AppGroup.word(forKey: key, in: context) else { return .result() }
        // Как в «Карточках для запоминания»: «Знаю» — «Хорошо», «Не знаю» — «Снова»
        let rating: FSRSRating = isKnown ? .good : .again
        FSRSCalculator().calculateNextReview(word: word, rating: rating)
        word.isMistake = !isKnown
        try context.save()
        DailyStudy.record(word, rating: rating)
        AppGroup.markChangedByWidget(word)
        ReviewWidgetState.revealedWord = nil
        return .result()
    }
}

// MARK: - Вид

enum WidgetPalette {
    private static func themed(_ light: UInt32, _ dark: UInt32) -> Color {
        func rgb(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        }
        let light = rgb(light), dark = rgb(dark)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    // Те же цвета «журнала», что в приложении
    static let background = themed(0xF3EEE3, 0x1A1714)
    static let text = themed(0x1F1B16, 0xEDE6D8)
    static let fill = themed(0xE8E1D3, 0x35302A)
    static let accent = themed(0xC5D0B8, 0x3E4A37)
}

struct ReviewWidgetView: View {
    let entry: ReviewEntry

    var body: some View {
        if let card = entry.card {
            if entry.isRevealed {
                revealed(card)
            } else {
                question(card)
            }
        } else {
            allDone
        }
    }

    private var header: some View {
        HStack {
            Label("Повторение", systemImage: "arrow.trianglehead.2.clockwise")
                .font(.caption.weight(.semibold))
            Spacer()
            Text("\(entry.dueCount)")
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }

    private func question(_ card: ReviewEntry.Card) -> some View {
        VStack(spacing: 6) {
            header
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Text(card.english)
                    .font(.system(size: 30, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !card.partOfSpeech.isEmpty {
                    Text(card.partOfSpeech)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(WidgetPalette.fill))
                }
                Button(intent: SpeakWordIntent(text: card.english)) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(WidgetPalette.fill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Произнести")
            }
            if !card.transcription.isEmpty {
                Text(card.transcription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(intent: RevealTranslationIntent(key: card.key)) {
                Text("Показать перевод")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(WidgetPalette.text))
                    .foregroundStyle(WidgetPalette.background)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(WidgetPalette.text)
    }

    private func revealed(_ card: ReviewEntry.Card) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.english)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text(card.partOfSpeech)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(entry.dueCount)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(card.russian)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(card.example)
                .font(.caption)
                .lineLimit(2)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(WidgetPalette.accent))
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                answerButton("❌ Не знаю", key: card.key, isKnown: false)
                answerButton("✅ Знаю", key: card.key, isKnown: true)
            }
        }
        .foregroundStyle(WidgetPalette.text)
    }

    private func answerButton(_ title: String, key: String, isKnown: Bool) -> some View {
        Button(intent: AnswerWordIntent(key: key, isKnown: isKnown)) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(WidgetPalette.fill))
        }
        .buttonStyle(.plain)
    }

    private var allDone: some View {
        VStack(spacing: 6) {
            header
            Spacer(minLength: 0)
            Text("Всё повторено 🎉")
                .font(.system(size: 22, design: .serif))
            if let next = entry.nextDue {
                Text(Calendar.current.isDateInToday(next)
                     ? "Следующее слово — в \(next.formatted(date: .omitted, time: .shortened))"
                     : "Следующее слово — \(next.formatted(.dateTime.day().month(.wide)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Слова для повторения появятся после занятий в приложении")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetPalette.text)
    }
}
