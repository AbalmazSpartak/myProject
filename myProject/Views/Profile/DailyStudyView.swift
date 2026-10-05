import SwiftUI
import Charts

extension FSRSRating {
    /// Цвета оценок — одни и те же в карточках, справке и профиле
    var color: Color {
        switch self {
        case .again: return .red
        case .hard: return .orange
        case .good: return .blue
        case .easy: return .green
        }
    }
}

// MARK: - «Выучено сегодня»

/// Сколько новых слов начато сегодня из дневной нормы; нажатие — выбор нормы
struct DailyGoalCard: View {
    @AppStorage(DailyNewWords.limitKey) private var limit = DailyNewWords.defaultLimit
    let introduced: Int

    @State private var isChoosingLimit = false

    var body: some View {
        Button { isChoosingLimit = true } label: {
            HStack(spacing: 20) {
                GoalRing(done: introduced, total: limit)
                    .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Выучено сегодня")
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundColor(.brandDark)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(introduced)")
                            .scaledFont(size: 40, weight: .bold, design: .rounded)
                            .foregroundColor(.brandDark)
                        Text("/\(limit > 0 ? "\(limit)" : "∞")")
                            .scaledFont(size: 28, weight: .bold, design: .rounded)
                            .foregroundColor(.gray)
                        Image(systemName: "pencil")
                            .scaledFont(size: 22, weight: .semibold)
                            .foregroundColor(.brandTint)
                            .padding(.leading, 12)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color.cardBackground)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Выучено сегодня \(introduced) из \(limit > 0 ? "\(limit)" : "без ограничений"). Изменить норму")
        .sheet(isPresented: $isChoosingLimit) {
            DailyGoalSheet(limit: $limit)
                .appThemedColorScheme()
        }
    }
}

/// Кольцо из чёрточек: по одной на слово нормы, начатые сегодня закрашены
private struct GoalRing: View {
    let done: Int
    /// 0 — без ограничения: сплошное кольцо, закрашенное, если сегодня что-то начато
    let total: Int

    var body: some View {
        // Больше 60 чёрточек сливаются — тогда кольцо делится пропорционально
        let segments = total > 0 ? min(total, 60) : 1
        let filled = total > 0 ? Int((Double(min(done, total)) / Double(total) * Double(segments)).rounded(.down)) : (done > 0 ? 1 : 0)
        let gap = segments > 1 ? 0.35 / Double(segments) : 0
        ZStack {
            ForEach(0..<segments, id: \.self) { index in
                Circle()
                    .trim(from: Double(index) / Double(segments) + gap / 2,
                          to: Double(index + 1) / Double(segments) - gap / 2)
                    .stroke(index < filled ? Color.green : Color.brandFill,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(4)
    }
}

/// «Сколько новых слов вы хотите учить в день?»
private struct DailyGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var limit: Int

    @State private var selection: Int
    @State private var isEnteringCustom = false
    @State private var customText = ""

    init(limit: Binding<Int>) {
        _limit = limit
        _selection = State(initialValue: limit.wrappedValue)
    }

    private var isCustom: Bool { selection > 0 && !DailyNewWords.limitOptions.contains(selection) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Сколько новых слов вы хотите учить в день?")
                .scaledFont(size: 24, weight: .bold)
                .foregroundColor(.brandDark)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(DailyNewWords.limitOptions, id: \.self) { option in
                    tile(isSelected: selection == option) { selection = option } label: {
                        Text("\(option)").scaledFont(size: 20, weight: .semibold, design: .rounded)
                    }
                }
                tile(isSelected: isCustom) {
                    customText = isCustom ? "\(selection)" : ""
                    isEnteringCustom = true
                } label: {
                    if isCustom {
                        Text("\(selection)").scaledFont(size: 20, weight: .semibold, design: .rounded)
                    } else {
                        Image(systemName: "pencil").scaledFont(size: 22, weight: .semibold)
                    }
                }
                tile(isSelected: selection == 0) { selection = 0 } label: {
                    Image(systemName: "infinity").scaledFont(size: 20, weight: .bold)
                }
            }

            Text(selection > 0
                 ? "За месяц вы выучите \(selection * 30) \(DailyGoalSheet.wordsNoun(selection * 30))"
                 : "Новые слова без ограничений")
                .scaledFont(size: 17, weight: .medium)
                .foregroundColor(.brandDark)

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                Button("Отмена") { dismiss() }
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundColor(.brandTint)
                    .padding(.horizontal, 24)
                    .fixedSize()
                Button {
                    limit = selection
                    dismiss()
                } label: {
                    Text("Сохранить")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundColor(.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.brandDark))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: PadLayout.columnWidth)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Своё число", isPresented: $isEnteringCustom) {
            TextField("Слов в день", text: $customText)
                .keyboardType(.numberPad)
            Button("Отмена", role: .cancel) {}
            Button("Готово") {
                if let value = Int(customText.trimmingCharacters(in: .whitespaces)), value > 0 {
                    selection = min(value, 500)
                }
            }
        } message: {
            Text("Сколько новых слов в день — от 1 до 500")
        }
    }

    private func tile<Label: View>(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .foregroundColor(isSelected ? .brandTint : .brandDark)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandInputBg))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isSelected ? Color.brandTint : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    /// 1 слово, 2 слова, 5 слов
    static func wordsNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "новых слов" }
        switch last {
        case 1: return "новое слово"
        case 2...4: return "новых слова"
        default: return "новых слов"
        }
    }
}

// MARK: - График оценок

/// Как вспоминались слова последние 7 дней: столбики из оценок и таблица «Всего / 7 дней»
struct DailyStudyCard: View {
    let days: [DailyStudy.Day]
    let totals: [FSRSRating: Int]

    private struct Segment: Identifiable {
        let date: Date
        let title: String
        let count: Int
        /// Верхний кусок столбика — только у него скруглён верх
        var isTop = false
        var id: String { "\(date.timeIntervalSince1970)-\(title)" }
    }

    /// Снизу вверх: Снова, Трудно, Хорошо, Легко
    private var segments: [Segment] {
        days.flatMap { day in
            var result = FSRSRating.allCases.map { Segment(date: day.date, title: $0.title, count: day.count($0)) }
            result = result.filter { $0.count > 0 }
            if !result.isEmpty { result[result.count - 1].isTop = true }
            return result
        }
    }

    private var maxDayTotal: Int {
        days.map { day in FSRSRating.allCases.reduce(0) { $0 + day.count($1) } }.max() ?? 0
    }

    private var dateRange: ClosedRange<Date> {
        let first = days.first?.date ?? Date()
        let last = days.last?.date ?? Date()
        return first...(Calendar.current.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Последние 7 дней")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)

            chart
                .frame(height: 220)

            legend
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private var chart: some View {
        Chart(segments) { segment in
            BarMark(
                x: .value("День", segment.date, unit: .day),
                y: .value("Слов", segment.count),
                width: .ratio(0.6)
            )
            .foregroundStyle(by: .value("Оценка", segment.title))
            // Один сплошной столбик, поделённый цветами: куски вплотную, скруглён только верх
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.isTop ? 6 : 0,
                                              topTrailingRadius: segment.isTop ? 6 : 0,
                                              style: .continuous))
            .annotation(position: .overlay) {
                // В низком сегменте цифра не помещается и налезает на соседний
                if Double(segment.count) >= Double(maxDayTotal) * 0.12 {
                    Text("\(segment.count)")
                        .scaledFont(size: 12, weight: .semibold, design: .rounded)
                        .foregroundColor(.white)
                        .fixedSize()
                }
            }
        }
        .chartForegroundStyleScale(
            domain: FSRSRating.allCases.map(\.title),
            range: FSRSRating.allCases.map(\.color)
        )
        .chartLegend(.hidden)
        .chartXScale(domain: dateRange)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                            .scaledFont(size: 11)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                AxisValueLabel()
            }
        }
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

    private var legend: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
            GridRow {
                Text("Всего")
                Text("7 дней")
                Color.clear.frame(width: 1, height: 1)
            }
            .scaledFont(size: 15, weight: .semibold)
            .foregroundColor(.gray)

            ForEach(FSRSRating.allCases.reversed(), id: \.self) { rating in
                GridRow {
                    Text("\(totals[rating] ?? 0)")
                        .gridColumnAlignment(.trailing)
                    Text("\(days.reduce(0) { $0 + $1.count(rating) })")
                        .gridColumnAlignment(.trailing)
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(rating.color)
                            .frame(width: 24, height: 24)
                        Text(rating.title)
                    }
                }
                .scaledFont(size: 18, weight: .semibold, design: .rounded)
                .foregroundColor(.brandDark)
            }
        }
    }
}
