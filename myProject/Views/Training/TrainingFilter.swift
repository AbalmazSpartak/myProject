import SwiftUI

/// Какие слова попадают в тренировку: карточки, викторина, карточки ввода
enum TrainingFilter: Equatable {
    case due           // Только слова, готовые к повторению по FSRS
    case all           // Все слова подряд
    case category(Category)
    case mistakes      // Ошибки
    case level(CEFRLevel)

    func title(counts: WordCounts) -> String {
        switch self {
        case .due: return "⏰ На повторение (\(counts.due))"
        case .all: return "Все слова"
        case .category(let category): return category.name
        case .mistakes: return "⚠️ Ошибки (\(counts.mistakes))"
        case .level(let level): return "Уровень \(level.rawValue)"
        }
    }

    /// Слова сессии: на повторение — сначала слова по сроку, затем новые (не больше дневного остатка),
    /// остальные режимы — вперемешку
    func sessionWords(from words: [Word], newWordsAllowance: Int? = nil, now: Date = Date()) -> [Word] {
        switch self {
        case .due:
            let reviews = words.filter { $0.state != .new && $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
            let fresh = Self.byLevel(words.filter { $0.state == .new })
            return reviews + (newWordsAllowance.map { Array(fresh.prefix($0)) } ?? fresh)
        case .all:
            return words.shuffled()
        case .category(let category):
            let categoryID = category.id
            return words.filter { $0.category?.id == categoryID }.shuffled()
        case .mistakes:
            return words.filter(\.isMistake).shuffled()
        case .level(let level):
            return words.filter { $0.cefrLevel == level.rawValue }.shuffled()
        }
    }

    /// Новые слова от простых к сложным (A1 → C2), внутри уровня вперемешку
    private static func byLevel(_ words: [Word]) -> [Word] {
        let groups = Dictionary(grouping: words, by: \.cefrLevel)
        let known = CEFRLevel.allCases.map(\.rawValue)
        let levels = known + groups.keys.filter { !known.contains($0) }.sorted()
        return levels.flatMap { (groups[$0] ?? []).shuffled() }
    }
}

/// Меню выбора слов для тренировки; цвета у каждого экрана свои
struct TrainingFilterMenu: View {
    let current: TrainingFilter
    let counts: WordCounts
    let categories: [Category]
    /// Пункт «На повторение» — только в карточках для запоминания
    var includesDue = false
    let icon: String
    let tint: Color
    /// Цвет фона кнопки, если отличается от цвета текста
    var backgroundTint: Color? = nil
    var backgroundOpacity = 0.12
    let onSelect: (TrainingFilter) -> Void

    var body: some View {
        Menu {
            if includesDue {
                Button("⏰ На повторение (FSRS)") { onSelect(.due) }
            }
            Button("Все слова") { onSelect(.all) }

            Button("⚠️ Работа над ошибками (\(counts.mistakes))") { onSelect(.mistakes) }
                .disabled(counts.mistakes == 0)

            Divider()

            ForEach(categories) { category in
                Button("\(category.name) (\(counts.count(for: category)))") { onSelect(.category(category)) }
            }

            Divider()

            ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                Button("Уровень \(level.rawValue) (\(counts.count(level: level)))") { onSelect(.level(level)) }
                    .disabled(counts.count(level: level) == 0)
            }
        } label: {
            let isMistakes = current == .mistakes
            HStack(spacing: 6) {
                Image(systemName: isMistakes ? "exclamationmark.triangle.fill" : icon)
                Text(current.title(counts: counts))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .scaledFont(size: 11, weight: .bold)
            }
            .scaledFont(size: 14, weight: .bold, design: .rounded)
            .foregroundColor(isMistakes ? .orange : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background((isMistakes ? Color.orange : backgroundTint ?? tint).opacity(backgroundOpacity))
            .cornerRadius(10)
        }
    }
}
