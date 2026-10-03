import SwiftUI

/// «Слов за день»: сколько слов вспомнено сегодня и столбики за последние 7 дней
struct DailyStudyCard: View {
    let days: [DailyStudy.Day]

    private var today: Int { days.last?.count ?? 0 }
    private var maxCount: Int { max(days.map(\.count).max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Слов за день")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Сегодня:")
                    .scaledFont(size: 16)
                    .foregroundColor(.gray)
                Text("\(today) \(Self.wordsNoun(today))")
                    .scaledFont(size: 26, weight: .bold, design: .rounded)
                    .foregroundColor(.brandDark)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    bar(day)
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func bar(_ day: DailyStudy.Day) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return VStack(spacing: 4) {
            Spacer(minLength: 0)
            Text("\(day.count)")
                .scaledFont(size: 12, weight: .semibold, design: .rounded)
                .foregroundColor(day.count > 0 ? .brandDark : .gray)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isToday ? Color.green : Color.green.opacity(0.45))
                // Пустой день — тонкая черта, чтобы было видно место столбика
                .frame(height: max(4, 70 * CGFloat(day.count) / CGFloat(maxCount)))
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .scaledFont(size: 12, weight: isToday ? .bold : .regular)
                .foregroundColor(isToday ? .brandDark : .gray)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide))): \(day.count) \(Self.wordsNoun(day.count))")
    }

    /// 1 слово, 2 слова, 5 слов
    static func wordsNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "слов" }
        switch last {
        case 1: return "слово"
        case 2...4: return "слова"
        default: return "слов"
        }
    }
}
