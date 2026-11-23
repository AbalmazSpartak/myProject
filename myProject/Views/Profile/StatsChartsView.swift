import SwiftUI
import Charts

/// Переключатель «Аккаунт | Статистика» под заголовком «Профиля» (оба режима)
enum ProfileSection: String, CaseIterable, Identifiable {
    case account = "Аккаунт"
    case stats = "Статистика"
    var id: String { rawValue }
}

struct ProfileSectionTabs: View {
    @Binding var selection: ProfileSection

    var body: some View {
        if AppDesign.isSketch {
            SketchTabs(items: ProfileSection.allCases, title: \.rawValue, selection: $selection)
                .padding(.horizontal, 20)
        } else {
            classic
        }
    }

    private var classic: some View {
        HStack(spacing: 24) {
            ForEach(ProfileSection.allCases) { section in
                Button {
                    guard selection != section else { return }
                    Haptics.tap()
                    selection = section
                } label: {
                    Text(section.rawValue)
                        .scaledFont(size: 14, weight: selection == section ? .semibold : .regular)
                        .foregroundColor(selection == section ? .brandDark : .brandMuted)
                        .frame(height: 40)
                        .overlay(alignment: .bottom) {
                            if selection == section { Rectangle().fill(Color.brandTint).frame(height: 2) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.brandBorder).frame(height: 1) }
    }
}

/// Карточка статистики: белая, с тонкой линией
struct StatCard<Content: View>: View {
    var title: String?
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).scaledFont(size: 18, weight: .medium, design: .serif).foregroundColor(.brandDark)
                    Spacer(minLength: 8)
                    if let note { Text(note).scaledFont(size: 12).foregroundColor(.brandMuted) }
                }
            }
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lxPlate(radius: 16)
    }
}

/// Статистика «Обучения» — вариант «Графики» с холста: кольцо «сегодня», серия по дням, кольцевая диаграмма словаря,
/// столбцы уровней и ответов по дням. Без дедлайнов и «осталось N»; пропущенный день — тонкая черта
struct StatsChartsView: View {
    @AppStorage(DailyNewWords.limitKey) private var limit = DailyNewWords.defaultLimit
    let introduced: Int
    let streak: Int
    let best: Int
    let week: [(date: Date, isDone: Bool)]
    let vocabulary: VocabularyStatus
    let levels: [LevelProgress]
    let days: [DailyStudy.Day]
    let totals: [FSRSRating: Int]

    @State private var isChoosingLimit = false

    var body: some View {
        VStack(spacing: 10) {
            todayAndStreak
            vocabularyCard
            levelsCard
            answersCard
        }
        .sheet(isPresented: $isChoosingLimit) {
            DailyGoalSheet(limit: $limit)
                .appThemedColorScheme()
        }
    }

    // MARK: Сегодня и серия

    private var todayAndStreak: some View {
        StatCard {
            HStack(spacing: 12) {
                Button { isChoosingLimit = true } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().stroke(Color.brandFill, lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: limit > 0 ? min(1, Double(introduced) / Double(limit)) : (introduced > 0 ? 1 : 0))
                                .stroke(Color.brandTint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(introduced)").scaledFont(size: 20, weight: .medium, design: .serif).foregroundColor(.brandDark)
                        }
                        .frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Выучено сегодня").scaledFont(size: 12).foregroundColor(.brandMuted)
                            Text(limit > 0 ? "\(introduced) из \(limit) новых слов" : "\(introduced), без нормы")
                                .scaledFont(size: 13).foregroundColor(.brandDark)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Выучено сегодня \(introduced) из \(limit > 0 ? "\(limit)" : "без нормы"). Изменить норму")
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color.brandBorder).frame(width: 1, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("Серия").scaledFont(size: 12).foregroundColor(.brandMuted)
                        Text("\(streak)").scaledFont(size: 22, weight: .medium, design: .serif).foregroundColor(.brandDark)
                        Text(Self.daysNoun(streak)).scaledFont(size: 13).foregroundColor(.brandDark)
                    }
                    HStack(spacing: 4) {
                        ForEach(week, id: \.date) { day in
                            Text(day.date.formatted(.dateTime.weekday(.narrow)).uppercased())
                                .scaledFont(size: 10, weight: .semibold)
                                .foregroundColor(day.isDone ? .brandOnTint : .brandMuted)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(day.isDone ? Color.brandTint : Color.brandFill))
                        }
                    }
                    Text("Лучшая серия — \(max(best, streak))").scaledFont(size: 12).foregroundColor(.brandMuted)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    // MARK: Словарь

    private var vocabularyCard: some View {
        let total = vocabulary.learned + vocabulary.learning + vocabulary.relearning
        let rows: [(String, Int, Color)] = [
            ("Выучены", vocabulary.learned, .brandScale4),
            ("Изучаются", vocabulary.learning, .brandScale2),
            ("Учим снова", vocabulary.relearning, .brandScale1),
        ]
        return StatCard(title: "Словарь", note: "интервальные повторения") {
            HStack(spacing: 14) {
                Chart {
                    ForEach(rows, id: \.0) { row in
                        SectorMark(angle: .value("Слов", max(row.1, 0)), innerRadius: .ratio(0.64), angularInset: 1)
                            .foregroundStyle(row.2)
                    }
                    if total == 0 {
                        SectorMark(angle: .value("Слов", 1), innerRadius: .ratio(0.64)).foregroundStyle(Color.brandFill)
                    }
                }
                .chartLegend(.hidden)
                .frame(width: 104, height: 104)
                .overlay {
                    VStack(spacing: 0) {
                        Text(total.formatted()).scaledFont(size: 22, weight: .medium, design: .serif).foregroundColor(.brandDark)
                        Text("слов").scaledFont(size: 10).foregroundColor(.brandMuted)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Словарь: \(total) слов")

                VStack(spacing: 9) {
                    ForEach(rows, id: \.0) { row in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(row.2).frame(width: 9, height: 9)
                            Text(row.0).scaledFont(size: 13).foregroundColor(.brandDark)
                            Spacer(minLength: 4)
                            Text(row.1.formatted()).scaledFont(size: 13, weight: .semibold).foregroundColor(.brandDark)
                            Text(total > 0 ? "\(row.1 * 100 / total)%" : "—")
                                .scaledFont(size: 12).foregroundColor(.brandMuted)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    if vocabulary.due > 0 {
                        Text("Можно повторить: \(vocabulary.due)")
                            .scaledFont(size: 12).foregroundColor(.brandMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: Уровни

    private var levelsCard: some View {
        StatCard(title: "Уровни", note: "доля выученных слов, %") {
            Chart(levels) { item in
                BarMark(x: .value("Уровень", item.level.rawValue), y: .value("Доля", item.percent), width: .fixed(30))
                    .foregroundStyle(Color.brandScale4)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5))
                    .annotation(position: .top, spacing: 2) {
                        Text("\(item.percent)").scaledFont(size: 11, weight: .semibold).foregroundColor(.brandDark)
                    }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { _ in
                    AxisGridLine().foregroundStyle(Color.brandBorder)
                    AxisValueLabel().foregroundStyle(Color.brandMuted)
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.brandMuted) }
            }
            .frame(height: 130)
        }
    }

    // MARK: Ответы по дням

    private var answersCard: some View {
        let weekTotal = days.reduce(0) { $0 + $1.counts.values.reduce(0, +) }
        let allTotal = totals.values.reduce(0, +)
        let ratings = FSRSRating.allCases.map { $0 }
        return StatCard(title: "Ответы по дням", note: "\(weekTotal) за 7 дней · \(allTotal.formatted()) всего") {
            Chart {
                ForEach(days) { day in
                    ForEach(ratings, id: \.self) { rating in
                        if day.count(rating) > 0 {
                            BarMark(x: .value("День", day.date, unit: .day), y: .value("Ответов", day.count(rating)), width: .fixed(30))
                                .foregroundStyle(rating.color)
                        }
                    }
                    // Пропущенный день — тонкая черта, без упрёка
                    if day.counts.values.reduce(0, +) == 0 {
                        BarMark(x: .value("День", day.date, unit: .day), y: .value("Ответов", 1), width: .fixed(30))
                            .foregroundStyle(Color.brandFill)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(Color.brandBorder)
                    AxisValueLabel().foregroundStyle(Color.brandMuted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .scaledFont(size: 11, weight: Calendar.current.isDateInToday(date) ? .semibold : .regular)
                                .foregroundColor(Calendar.current.isDateInToday(date) ? .brandDark : .brandMuted)
                        }
                    }
                }
            }
            .frame(height: 130)

            HStack(spacing: 10) {
                ForEach(ratings, id: \.self) { rating in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(rating.color).frame(width: 8, height: 8)
                        Text("\(rating.title) \(totals[rating] ?? 0)")
                            .scaledFont(size: 11).foregroundColor(.brandMuted)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
        }
    }

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
