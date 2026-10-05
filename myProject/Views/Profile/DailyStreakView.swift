import SwiftUI

/// «Серия дней»: дни подряд с выполненной нормой, рекорд и кружки последних 7 дней
struct DailyStreakCard: View {
    let current: Int
    let best: Int
    let week: [(date: Date, isDone: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: "flame.fill")
                    .scaledFont(size: 40)
                    .foregroundStyle(current > 0 ? Color.orange : Color.gray.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Серия дней")
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(.brandDark)
                    Text("\(current) \(Self.daysNoun(current))")
                        .scaledFont(size: 32, weight: .bold, design: .rounded)
                        .foregroundColor(.brandDark)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Рекорд")
                        .scaledFont(size: 11, weight: .medium)
                        .foregroundColor(.gray)
                    Text("\(max(best, current)) \(Self.daysNoun(max(best, current)))")
                        .scaledFont(size: 16, weight: .bold, design: .rounded)
                        .foregroundColor(.orange)
                }
            }

            HStack(spacing: 0) {
                ForEach(week, id: \.date) { day in
                    dayCircle(day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func dayCircle(_ day: (date: Date, isDone: Bool)) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(day.isDone ? Color.orange : Color.brandFill)
                if day.isDone {
                    Image(systemName: "checkmark")
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 32, height: 32)
            .overlay(Circle().strokeBorder(isToday && !day.isDone ? Color.orange : .clear, lineWidth: 2))

            Text(day.date.formatted(.dateTime.weekday(.short)))
                .scaledFont(size: 12, weight: isToday ? .bold : .regular)
                .foregroundColor(isToday ? .brandDark : .gray)
        }
    }

    /// 1 день, 2 дня, 5 дней
    private static func daysNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "дней" }
        switch last {
        case 1: return "день"
        case 2...4: return "дня"
        default: return "дней"
        }
    }
}
