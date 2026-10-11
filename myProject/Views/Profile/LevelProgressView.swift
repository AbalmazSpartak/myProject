import SwiftUI
import SwiftData

/// Сколько слов уровня изучено. Изученное — слово, перешедшее из заучивания в обычные повторения FSRS;
/// забытое (снова на заучивании) не считается, пока его не вспомнят
struct LevelProgress: Identifiable {
    let level: CEFRLevel
    var total = 0
    var learned = 0

    var id: CEFRLevel { level }

    var percent: Int {
        total > 0 ? learned * 100 / total : 0
    }

    /// Запросами к базе, без чтения всех слов (10 000+ — ~2 с на iPhone 12): сколько слов в уровне — запомненным счётчиком,
    /// изученные — среди уже оценённых (у новых слов состояния «на повторении» не бывает), их сотни, а не тысячи
    static func counted(in context: ModelContext) -> [LevelProgress] {
        countedWithStatus(in: context).levels
    }

    /// Прогресс по уровням и состояние слов в FSRS — одним чтением уже начатых слов (reps > 0)
    static func countedWithStatus(in context: ModelContext) -> (levels: [LevelProgress], status: VocabularyStatus) {
        var progress = Dictionary(uniqueKeysWithValues: CEFRLevel.allCases.map { level in
            let raw = level.rawValue
            return (level, LevelProgress(level: level, total: StudyWords.cachedCount("профиль|\(raw)", #Predicate<Word> { $0.cefrLevel == raw }, in: context)))
        })
        var status = VocabularyStatus()
        let now = Date()
        for word in StudyWords.fetch(#Predicate<Word> { $0.reps > 0 }, in: context) {
            switch word.state {
            case .review: status.learned += 1
            case .learning: status.learning += 1
            case .relearning: status.relearning += 1
            case .new: break
            }
            if word.dueDate <= now { status.due += 1 }
            guard word.state == .review, let level = CEFRLevel(rawValue: word.cefrLevel) else { continue }
            progress[level]?.learned += 1
        }
        return (CEFRLevel.allCases.compactMap { progress[$0] }, status)
    }

    /// Один проход по словам — для всех уровней сразу
    static func all(from words: [Word]) -> [LevelProgress] {
        var progress = Dictionary(uniqueKeysWithValues: CEFRLevel.allCases.map { ($0, LevelProgress(level: $0)) })
        for word in words {
            guard let level = CEFRLevel(rawValue: word.cefrLevel) else { continue }
            progress[level]?.total += 1
            if word.state == .review { progress[level]?.learned += 1 }
        }
        return CEFRLevel.allCases.compactMap { progress[$0] }
    }
}

/// «Прогресс по уровням»: A1…C2 — процент изученных слов уровня
struct LevelProgressCard: View {
    let progress: [LevelProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Прогресс по уровням")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)

            ForEach(progress) { item in
                row(item)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func row(_ item: LevelProgress) -> some View {
        HStack(spacing: 12) {
            Text(item.level.rawValue)
                .scaledFont(size: 16, weight: .bold, design: .rounded)
                .foregroundColor(.brandDark)
                .frame(width: 32, alignment: .leading)

            ProgressView(value: Double(item.percent), total: 100)
                .tint(.green)

            Text("\(item.percent)%")
                .scaledFont(size: 16, weight: .bold, design: .rounded)
                .foregroundColor(item.percent > 0 ? .brandDark : .gray)
                .frame(minWidth: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Уровень \(item.level.rawValue): изучено \(item.percent)%")
    }
}

/// Состояние начатых слов в FSRS: выучены, изучаются, забыты (учатся снова), пора повторить
struct VocabularyStatus: Equatable {
    var learned = 0
    var learning = 0
    var relearning = 0
    var due = 0
}

/// «Статус словаря»: сколько слов в каждом состоянии FSRS
struct VocabularyStatusCard: View {
    let status: VocabularyStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Статус словаря")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
            row("Выучены", hint: "повторение через дни", count: status.learned, color: .green)
            row("Изучаются", hint: "первые повторения", count: status.learning, color: .blue)
            row("Забыты — учим снова", hint: nil, count: status.relearning, color: .orange)
            row("Пора повторить", hint: "сегодня", count: status.due, color: .red)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func row(_ title: String, hint: String?, count: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .scaledFont(size: 16)
                .foregroundColor(.brandDark)
            if let hint {
                Text(hint)
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(count)")
                .scaledFont(size: 16, weight: .bold, design: .rounded)
                .foregroundColor(count > 0 ? .brandDark : .gray)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(count)")
    }
}
