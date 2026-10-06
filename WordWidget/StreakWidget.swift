import WidgetKit
import SwiftUI

/// «Серия дней» на экране «Домой»: дни подряд с выполненной нормой, кружки последних 7 дней и рекорд.
/// Без напоминаний и предупреждений — как в профиле
struct StreakWidget: Widget {
    static let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(WidgetPalette.background, for: .widget)
        }
        .configurationDisplayName("Серия дней")
        .description("Сколько дней подряд выполнена норма новых слов.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakEntry: TimelineEntry {
    let date: Date
    let current: Int
    let best: Int
    let week: [(date: Date, isDone: Bool)]

    static func now(_ date: Date = Date()) -> StreakEntry {
        StreakEntry(date: date, current: DailyStreak.current(now: date), best: DailyStreak.best, week: DailyStreak.week(now: date))
    }
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        let calendar = Calendar.current
        let week = (0..<7).reversed().map { offset in
            (date: calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date(), isDone: offset > 0)
        }
        return StreakEntry(date: Date(), current: 6, best: 12, week: week)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : .now())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // Серия меняется в приложении (оно обновляет виджеты, уходя в фон) и в полночь — сдвигаются кружки
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [.now()], policy: .after(midnight)))
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(entry.current > 0 ? Color.orange : Color.gray.opacity(0.5))
                Text("\(entry.current)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Text(Self.daysInRow(entry.current))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                ForEach(entry.week, id: \.date) { day in
                    let isToday = Calendar.current.isDateInToday(day.date)
                    Circle()
                        .fill(day.isDone ? Color.orange : WidgetPalette.fill)
                        .overlay(Circle().strokeBorder(isToday && !day.isDone ? Color.orange : .clear, lineWidth: 1.5))
                        .frame(width: 14, height: 14)
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 0)

            Text("Рекорд: \(max(entry.best, entry.current))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(WidgetPalette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Серия: \(entry.current) \(Self.daysInRow(entry.current)). Рекорд \(max(entry.best, entry.current))")
    }

    /// «1 день подряд», «3 дня подряд», «5 дней подряд»
    static func daysInRow(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        let noun: String
        if (11...14).contains(lastTwo) { noun = "дней" } else {
            switch last {
            case 1: noun = "день"
            case 2...4: noun = "дня"
            default: noun = "дней"
            }
        }
        return "\(noun) подряд"
    }
}
