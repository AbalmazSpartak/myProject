import SwiftUI

/// Упражнение «Составь фразу»: русская фраза → английская из карточек. Раунд — 15 фраз, без штрафов и таймеров.
/// Задания и схему-подсказку даёт урок. Баллы — за верные с первого раза (и бонус за серию), в конце раунда
/// результат записывается в освоение урока (PolyglotProgress)
struct PolyglotExerciseView<Scheme: View>: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PolyglotProgress.storageKey) private var progress = PolyglotProgress()

    let lesson: Int
    let makeRound: () -> [PolyglotTask]
    @ViewBuilder let scheme: () -> Scheme

    @State private var tasks: [PolyglotTask]
    @State private var index = 0
    /// Выбранные карточки — номера в task.tiles (одинаковые слова различаются по месту)
    @State private var picked: [Int] = []
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var isShowingScheme = false
    @State private var points = 0
    /// Верных подряд — за каждые 5 бонус
    @State private var streak = 0
    /// Освоение урока до этого раунда — для «Практика → Уверенно»
    @State private var levelBefore: PolyglotProgress.Level?
    @State private var bestBefore = 0

    init(lesson: Int, makeRound: @escaping () -> [PolyglotTask], @ViewBuilder scheme: @escaping () -> Scheme) {
        self.lesson = lesson
        self.makeRound = makeRound
        self.scheme = scheme
        _tasks = State(initialValue: makeRound())
    }

    private var task: PolyglotTask? { tasks.indices.contains(index) ? tasks[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let task {
                exercise(task)
            } else {
                finished
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .sheet(isPresented: $isShowingScheme) {
            NavigationStack {
                ScrollView {
                    scheme().padding(20)
                }
                .background(Color.brandBackground.ignoresSafeArea())
                .navigationTitle("Схема")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { isShowingScheme = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .appThemedColorScheme()
        }
    }

    private var header: some View {
        HStack {
            Button("Закрыть") { dismiss() }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            Spacer()
            if task != nil {
                VStack(spacing: 2) {
                    Text("\(index + 1) из \(tasks.count)")
                        .scaledFont(size: 15, weight: .semibold, design: .rounded)
                        .foregroundColor(.gray)
                    Text("\(points) \(PolyglotProgress.pointsNoun(points))")
                        .scaledFont(size: 13, weight: .bold, design: .rounded)
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: points)
                }
            }
            Spacer()
            Button { isShowingScheme = true } label: {
                Label("Схема", systemImage: "tablecells")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Задание

    private func exercise(_ task: PolyglotTask) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(task.russian)
                    .scaledFont(size: 32, weight: .regular, design: .serif)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                answerArea(task)

                if let result {
                    feedback(task, isCorrect: result)
                } else {
                    FlowLayout(spacing: 10) {
                        ForEach(Array(task.tiles.enumerated()), id: \.offset) { tileIndex, word in
                            let isUsed = picked.contains(tileIndex)
                            Button {
                                picked.append(tileIndex)
                            } label: {
                                tile(word)
                            }
                            .buttonStyle(.plain)
                            .opacity(isUsed ? 0 : 1)
                            .disabled(isUsed)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                actionButton(task)
            }
            .padding(20)
            .animation(.snappy(duration: 0.2), value: picked)
            .animation(.snappy(duration: 0.2), value: result)
        }
    }

    /// Собранная фраза: нажатие на слово возвращает его обратно
    private func answerArea(_ task: PolyglotTask) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(picked.enumerated()), id: \.offset) { position, tileIndex in
                Button {
                    guard result == nil else { return }
                    picked.remove(at: position)
                } label: {
                    tile(task.tiles[tileIndex], isPicked: true)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 2, dash: picked.isEmpty ? [6] : []))
        )
        .overlay {
            if picked.isEmpty {
                Text("Нажимайте на слова по порядку")
                    .scaledFont(size: 14)
                    .foregroundColor(.gray)
            }
        }
    }

    private var borderColor: Color {
        switch result {
        case true?: return .green
        case false?: return .red
        case nil: return Color.brandDark.opacity(0.2)
        }
    }

    private func tile(_ word: String, isPicked: Bool = false) -> some View {
        Text(word)
            .scaledFont(size: 19, weight: .medium)
            .foregroundColor(.brandDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPicked ? Color.brandAccent : Color.cardBackground)
            )
            .shadow(color: Color.black.opacity(isPicked ? 0 : 0.06), radius: 3, x: 0, y: 2)
    }

    private func feedback(_ task: PolyglotTask, isCorrect: Bool) -> some View {
        VStack(spacing: 8) {
            Label(isCorrect ? "Верно!" : "Почти. Правильно так:",
                  systemImage: isCorrect ? "checkmark.circle.fill" : "lightbulb.fill")
                .scaledFont(size: 18, weight: .semibold)
                .foregroundColor(isCorrect ? .green : .orange)
            Text(task.answerText)
                .scaledFont(size: 22, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
            if !isCorrect {
                Button("Посмотреть схему") { isShowingScheme = true }
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandTint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardBackground))
    }

    private func actionButton(_ task: PolyglotTask) -> some View {
        Button {
            if result == nil {
                let words = picked.map { task.tiles[$0] }
                let isCorrect = task.isCorrect(words)
                if isCorrect {
                    correctCount += 1
                    streak += 1
                    points += PolyglotProgress.points(forCorrectAnswerWithStreak: streak)
                } else {
                    streak = 0
                }
                result = isCorrect
                UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .warning)
                TextToSpeechManager.shared.speakAutomatically(task.answerText)
            } else {
                result = nil
                picked = []
                if index == tasks.count - 1 { finishRound() }
                index += 1
            }
        } label: {
            Text(result == nil ? "Проверить" : "Дальше")
                .scaledFont(size: 18, weight: .bold)
                .foregroundColor(.brandBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.brandDark.opacity(result == nil && picked.isEmpty ? 0.35 : 1)))
        }
        .disabled(result == nil && picked.isEmpty)
    }

    // MARK: - Итог

    private func finishRound() {
        let before = progress.lesson(lesson)
        levelBefore = before.level
        bestBefore = before.bestPoints
        progress.record(lesson: lesson, correct: correctCount, total: tasks.count, points: points)
    }

    private var finished: some View {
        let lessonProgress = progress.lesson(lesson)
        let percent = tasks.isEmpty ? 0 : correctCount * 100 / tasks.count
        return ScrollView {
            VStack(spacing: 18) {
                Text(percent >= 90 ? "🏆" : percent >= 70 ? "🎉" : "💪")
                    .font(.system(size: 64))
                    .padding(.top, 30)
                Text("Раунд пройден")
                    .scaledFont(size: 28, weight: .regular, design: .serif)
                    .foregroundColor(.brandDark)

                Text("+\(points) \(PolyglotProgress.pointsNoun(points))")
                    .scaledFont(size: 34, weight: .bold, design: .rounded)
                    .foregroundColor(.orange)
                if points > bestBefore, bestBefore > 0 {
                    Label("Лучший раунд в уроке!", systemImage: "star.fill")
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.orange)
                }

                Text("Верно с первого раза: \(correctCount) из \(tasks.count) · \(percent)%")
                    .scaledFont(size: 17)
                    .foregroundColor(.gray)

                if let level = lessonProgress.level, let mastery = lessonProgress.mastery {
                    masteryCard(level: level, mastery: mastery, best: lessonProgress.bestPoints)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 14) {
                Button {
                    tasks = makeRound()
                    index = 0
                    correctCount = 0
                    points = 0
                    streak = 0
                } label: {
                    Text("Ещё раунд")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundColor(.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.brandDark))
                }
                Button("К уроку") { dismiss() }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandTint)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
            .background(Color.brandBackground)
        }
        .padding(.horizontal, 20)
    }

    /// Освоение темы по последним раундам: уровень, звёзды, полоска; повышение — «Практика → Уверенно»
    private func masteryCard(level: PolyglotProgress.Level, mastery: Double, best: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Освоение темы")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.gray)
                Spacer()
                Text(level.stars)
                    .scaledFont(size: 18)
                    .foregroundColor(.orange)
            }
            if let levelBefore, levelBefore != level {
                Text("\(levelBefore.title) → \(level.title)")
                    .scaledFont(size: 22, weight: .semibold, design: .serif)
                    .foregroundColor(level > levelBefore ? .green : .brandDark)
            } else {
                Text(level.title)
                    .scaledFont(size: 22, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
            }
            ProgressView(value: mastery)
                .tint(.orange)
            Text("\(Int((mastery * 100).rounded()))% верных за последние раунды · лучший раунд \(best) \(PolyglotProgress.pointsNoun(best))")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.cardBackground))
    }
}


/// Карточки в строку с переносом, по центру или по левому краю
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var centered = true

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX + (centered ? (bounds.width - row.width) / 2 : 0)
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
