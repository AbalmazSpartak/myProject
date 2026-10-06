import SwiftUI

/// Упражнение «Составь фразу»: русская фраза → английская из карточек. Раунд — 15 фраз, без штрафов и таймеров
struct PolyglotExerciseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tasks = PolyglotLesson1.round()
    @State private var index = 0
    /// Выбранные карточки — номера в task.tiles (одинаковые слова различаются по месту)
    @State private var picked: [Int] = []
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var isShowingScheme = false

    private var task: PolyglotLesson1.Task? { tasks.indices.contains(index) ? tasks[index] : nil }

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
                    PolyglotSchemeView().padding(20)
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
                Text("\(index + 1) из \(tasks.count)")
                    .scaledFont(size: 15, weight: .semibold, design: .rounded)
                    .foregroundColor(.gray)
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

    private func exercise(_ task: PolyglotLesson1.Task) -> some View {
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
    private func answerArea(_ task: PolyglotLesson1.Task) -> some View {
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

    private func feedback(_ task: PolyglotLesson1.Task, isCorrect: Bool) -> some View {
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

    private func actionButton(_ task: PolyglotLesson1.Task) -> some View {
        Button {
            if result == nil {
                let words = picked.map { task.tiles[$0] }
                let isCorrect = PolyglotLesson1.isCorrect(words, for: task)
                if isCorrect { correctCount += 1 }
                result = isCorrect
                UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .warning)
                TextToSpeechManager.shared.speakAutomatically(task.answerText)
            } else {
                result = nil
                picked = []
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

    private var finished: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎉")
                .font(.system(size: 64))
            Text("Раунд пройден")
                .scaledFont(size: 28, weight: .regular, design: .serif)
                .foregroundColor(.brandDark)
            Text("Верно с первого раза: \(correctCount) из \(tasks.count)")
                .scaledFont(size: 17)
                .foregroundColor(.gray)
            Spacer()
            Button {
                tasks = PolyglotLesson1.round()
                index = 0
                correctCount = 0
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
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }
}

/// Карточки в строку с переносом, по центру
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) / 2
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
