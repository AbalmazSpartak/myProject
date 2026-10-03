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
