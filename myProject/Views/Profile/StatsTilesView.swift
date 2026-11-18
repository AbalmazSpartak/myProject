import SwiftUI

/// Статистика «Обучения» — вариант «Плитки» с холста: крупные числа в карточках, уровни плитками,
/// ответы за 7 дней — строками по дням. Без дедлайнов и «осталось N»; пропущенный день — тонкая черта
struct StatsTilesView: View {
    @AppStorage(DailyNewWords.limitKey) private var limit = DailyNewWords.defaultLimit
    let introduced: Int
    let streak: Int
    let best: Int
    let vocabulary: VocabularyStatus
    let levels: [LevelProgress]
    let days: [DailyStudy.Day]
    let totals: [FSRSRating: Int]

    @State private var isChoosingLimit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                todayTile
                streakTile
            }
            heading("Словарь", note: "\(vocabularyTotal) \(DailyStudyCard.wordsNoun(vocabularyTotal))")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                vocabTile("Выучены", vocabulary.learned, .brandScale4)
                vocabTile("Изучаются", vocabulary.learning, .brandScale2)
                vocabTile("Учим снова", vocabulary.relearning, .brandScale1)
                vocabTile("Можно повторить", vocabulary.due, .brandScale3)
            }
            heading("Уровни", note: "доля выученных слов")
            HStack(spacing: 6) {
                ForEach(levels) { levelTile($0) }
            }
            heading("Ответы за 7 дней", note: "\(allTotal.formatted()) всего")
            answers
        }
        .sheet(isPresented: $isChoosingLimit) {
            DailyGoalSheet(limit: $limit)
                .appThemedColorScheme()
        }
    }

    private var vocabularyTotal: Int { vocabulary.learned + vocabulary.learning + vocabulary.relearning }
    private var allTotal: Int { totals.values.reduce(0, +) }

    // MARK: Верхние плитки

    private var todayTile: some View {
        Button { isChoosingLimit = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Выучено сегодня")
                    .scaledFont(size: 12)
                    .foregroundColor(.brandMuted)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(introduced)")
                        .scaledFont(size: 44, weight: .medium, design: .serif)
                        .foregroundColor(.brandTint)
                    Text(limit > 0 ? "из \(limit)" : "без нормы")
                        .scaledFont(size: 13)
                        .foregroundColor(.brandDark)
                }
                ProgressTrack(value: limit > 0 ? Double(introduced) / Double(limit) : (introduced > 0 ? 1 : 0))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выучено сегодня \(introduced) из \(limit > 0 ? "\(limit)" : "без нормы"). Изменить норму")
    }

    private var streakTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Серия")
                .scaledFont(size: 12)
                .foregroundColor(.brandMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(streak)")
                    .scaledFont(size: 44, weight: .medium, design: .serif)
                    .foregroundColor(.brandDark)
                Text(Self.daysNoun(streak))
                    .scaledFont(size: 13)
                    .foregroundColor(.brandDark)
            }
            Text("Лучшая серия — \(max(best, streak))")
                .scaledFont(size: 12)
                .foregroundColor(.brandMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Словарь и уровни

    private func vocabTile(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).scaledFont(size: 12).foregroundColor(.brandMuted)
            }
            Text(count.formatted())
                .scaledFont(size: 30, weight: .medium, design: .serif)
                .foregroundColor(.brandDark)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }

    private func levelTile(_ item: LevelProgress) -> some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.brandAccent)
                    .frame(height: geo.size.height * CGFloat(item.percent) / 100)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            VStack(alignment: .leading) {
                Text(item.level.rawValue).scaledFont(size: 12).foregroundColor(.brandMuted)
                Spacer(minLength: 0)
                Text("\(item.percent)%")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 68)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Уровень \(item.level.rawValue): выучено \(item.percent)%")
    }

    // MARK: Ответы по дням — строками

    private var answers: some View {
        let weekTotal = days.reduce(0) { $0 + $1.total }
        let peak = max(days.map(\.total).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(weekTotal)")
                    .scaledFont(size: 26, weight: .medium, design: .serif)
                    .foregroundColor(.brandDark)
                Text("ответов за неделю").scaledFont(size: 12).foregroundColor(.brandMuted)
            }
            VStack(spacing: 8) {
                ForEach(days) { day in
                    HStack(spacing: 10) {
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .scaledFont(size: 12, weight: Calendar.current.isDateInToday(day.date) ? .semibold : .regular)
                            .foregroundColor(Calendar.current.isDateInToday(day.date) ? .brandDark : .brandMuted)
                            .frame(width: 28, alignment: .leading)
                        dayBar(day, peak: peak)
                        Text(day.total > 0 ? "\(day.total)" : "—")
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundColor(day.total > 0 ? .brandDark : .brandMuted)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            HStack(spacing: 12) {
                ForEach(FSRSRating.allCases.map { $0 }, id: \.self) { rating in
                    HStack(spacing: 4) {
                        Circle().fill(rating.color).frame(width: 8, height: 8)
                        Text("\(rating.title) \(totals[rating] ?? 0)")
                            .scaledFont(size: 11)
                            .foregroundColor(.brandMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func dayBar(_ day: DailyStudy.Day, peak: Int) -> some View {
        GeometryReader { geo in
            if day.total == 0 {
                Capsule().fill(Color.brandFill).frame(height: 3)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                HStack(spacing: 1) {
                    ForEach(FSRSRating.allCases.map { $0 }, id: \.self) { rating in
                        let count = day.count(rating)
                        if count > 0 {
                            Rectangle().fill(rating.color)
                                .frame(width: max(2, geo.size.width * CGFloat(count) / CGFloat(peak)))
                        }
                    }
                }
                .clipShape(Capsule())
                .frame(maxHeight: .infinity, alignment: .center)
                .frame(height: 8)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 10)
    }

    // MARK: Мелочи

    private func heading(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).scaledFont(size: 18, weight: .medium, design: .serif).foregroundColor(.brandDark)
            Spacer()
            Text(note).scaledFont(size: 12).foregroundColor(.brandMuted)
        }
        .padding(.top, 8)
    }

    private static func daysNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "дней подряд" }
        switch last {
        case 1: return "день подряд"
        case 2...4: return "дня подряд"
        default: return "дней подряд"
        }
    }
}

private extension DailyStudy.Day {
    var total: Int { FSRSRating.allCases.reduce(0) { $0 + count($1) } }
}

private struct ProgressTrack: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.cardBackground.opacity(0.75))
                Capsule().fill(Color.brandTint).frame(width: geo.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 6)
    }
}

private extension View {
    func card() -> some View {
        background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }
}
