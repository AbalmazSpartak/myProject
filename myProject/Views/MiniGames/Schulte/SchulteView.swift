import SwiftUI

/// Рекорды таблиц Шульте: лучшее время по каждому размеру
enum SchulteRecords {
    static let sizes = [3, 4, 5, 6]
    static let classicSize = 5

    private static func key(_ size: Int) -> String { "schulte_best_\(size)" }

    static func best(_ size: Int) -> Double? {
        let value = UserDefaults.standard.double(forKey: key(size))
        return value > 0 ? value : nil
    }

    /// Сохраняет время, если это рекорд; true — новый рекорд
    static func record(_ time: Double, size: Int) -> Bool {
        guard best(size).map({ time < $0 }) ?? true else { return false }
        UserDefaults.standard.set(time, forKey: key(size))
        return true
    }

    static func format(_ seconds: Double) -> String {
        "\(seconds.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "ru_RU")))) с"
    }
}

/// Таблицы Шульте: числа в случайном порядке, найти все по порядку как можно быстрее.
/// Взгляд держится на точке в центре, числа ищутся боковым зрением
struct SchulteView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("schulte_size") private var size = SchulteRecords.classicSize
    /// Ровная сетка: клетки строго квадратные, промежутки по вертикали и горизонтали одинаковые
    @AppStorage("schulte_even_grid") private var evenGrid = false
    /// Точка в центре: цвет или «none» — без точки
    @AppStorage("schulte_dot") private var dot = "green"

    private static let dotColors: [(key: String, color: Color, name: String)] = [
        ("green", .green, "Зелёная"), ("red", .red, "Красная"), ("blue", .blue, "Синяя"),
        ("orange", .orange, "Оранжевая"), ("purple", .purple, "Фиолетовая"), ("black", .black, "Чёрная"),
    ]

    private var dotColor: Color? {
        Self.dotColors.first { $0.key == dot }?.color
    }

    private enum Phase { case setup, playing, finished }

    @State private var phase = Phase.setup
    @State private var numbers: [Int] = []
    @State private var next = 1
    @State private var mistakes = 0
    @State private var start = Date()
    @State private var result: Double = 0
    @State private var isRecord = false
    /// Вспышка на нажатой клетке: номер клетки и верно ли
    @State private var flash: (index: Int, correct: Bool)?

    private var total: Int { size * size }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .setup: setup
            case .playing: board
            case .finished: finished
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            // Из таблицы и итога — назад к выбору размера, оттуда — на «Обзор»
            Button {
                if phase == .setup { dismiss() } else { phase = .setup }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text(phase == .setup ? "Обзор" : "Назад")
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            }
            Spacer()
            HelpButton(topic: .schulte)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .overlay {
            Text("Таблицы Шульте")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Выбор размера

    private var setup: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Найдите числа от 1 до \(total) по порядку. Смотрите в точку в центре — числа ищите боковым зрением, не водя глазами.")
                    .scaledFont(size: 16)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.center)

                Picker("Размер", selection: $size) {
                    ForEach(SchulteRecords.sizes, id: \.self) { size in
                        Text("\(size)×\(size)").tag(size)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Вид таблицы", selection: $evenGrid) {
                    Text("Обычный").tag(false)
                    Text("Ровная сетка").tag(true)
                }
                .pickerStyle(.segmented)

                dotPicker

                VStack(spacing: 4) {
                    Text(size == SchulteRecords.classicSize ? "Классическая таблица: 1–25" : "Числа от 1 до \(total)")
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                    if let best = SchulteRecords.best(size) {
                        Text("Рекорд: \(SchulteRecords.format(best))")
                            .scaledFont(size: 17, weight: .semibold)
                            .foregroundColor(.brandDark)
                    }
                }

                Button(action: begin) {
                    Text("Начать")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundStyle(Color.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandDark)
            }
            .padding(24)
        }
    }

    private func begin() {
        Haptics.tap()
        numbers = Array(1...total).shuffled()
        next = 1
        mistakes = 0
        flash = nil
        start = Date()
        phase = .playing
    }

    // MARK: - Игра

    private var board: some View {
        VStack(spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Найдите")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                    Text("\(next)")
                        .scaledFont(size: 34, weight: .bold, design: .rounded)
                        .foregroundColor(.brandDark)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    TimelineView(.periodic(from: start, by: 0.1)) { context in
                        Text(SchulteRecords.format(context.date.timeIntervalSince(start)))
                            .scaledFont(size: 22, weight: .semibold, design: .rounded)
                            .monospacedDigit()
                            .foregroundColor(.brandDark)
                    }
                    Text(mistakes == 0 ? "без ошибок" : "ошибок: \(mistakes)")
                        .scaledFont(size: 13)
                        .foregroundColor(mistakes == 0 ? .gray : .red)
                }
            }
            .padding(.horizontal, 20)

            Group {
                if evenGrid { evenBoard } else { grid }
            }
            .padding(.horizontal, 16)

            Button("Заново") { begin() }
                .scaledFont(size: 16, weight: .semibold)
                .foregroundColor(.brandDark)
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: size)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(numbers.indices, id: \.self) { index in
                cell(index)
            }
        }
        .frame(maxWidth: 520)
        // Точка в центре — сюда смотреть
        .overlay { centerDot }
    }

    /// Точка, в которую смотреть; без неё — ничего
    @ViewBuilder
    private var centerDot: some View {
        if let dotColor {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .allowsHitTesting(false)
        }
    }

    /// Выбор цвета точки в центре или «без точки»
    private var dotPicker: some View {
        HStack(spacing: 10) {
            Text("Точка в центре")
                .scaledFont(size: 15)
                .foregroundColor(.brandDark)
            Spacer(minLength: 4)
            ForEach(Self.dotColors, id: \.key) { item in
                Button {
                    dot = item.key
                } label: {
                    Circle()
                        .fill(item.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.brandDark, lineWidth: dot == item.key ? 2.5 : 0).padding(-4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.name)
                .accessibilityAddTraits(dot == item.key ? .isSelected : [])
            }
            Button {
                dot = "none"
            } label: {
                Image(systemName: "nosign")
                    .scaledFont(size: 22)
                    .foregroundColor(.gray)
                    .overlay(Circle().stroke(Color.brandDark, lineWidth: dot == "none" ? 2.5 : 0).padding(-3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Без точки")
            .accessibilityAddTraits(dot == "none" ? .isSelected : [])
        }
    }

    /// Ровная сетка: сторона клетки — из ширины, промежуток одинаковый в обе стороны
    private var evenBoard: some View {
        let gap: CGFloat = 6
        return GeometryReader { proxy in
            let width = min(proxy.size.width, 520)
            let side = (width - gap * CGFloat(size - 1)) / CGFloat(size)
            VStack(spacing: gap) {
                ForEach(0..<size, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<size, id: \.self) { column in
                            cell(row * size + column)
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
            .overlay { centerDot }
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 520)
    }

    private func cell(_ index: Int) -> some View {
        let number = numbers[index]
        let tint: Color? = flash?.index == index ? (flash!.correct ? .green : .red) : nil
        return Button {
            tap(index)
        } label: {
            Text("\(number)")
                .scaledFont(size: size >= 6 ? 22 : size == 5 ? 26 : 32, weight: .semibold, design: .rounded)
                .foregroundColor(.brandDark)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(RoundedRectangle(cornerRadius: 10).fill(tint?.opacity(0.35) ?? Color.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandDark.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number)")
    }

    private func tap(_ index: Int) {
        let correct = numbers[index] == next
        withAnimation(.easeOut(duration: 0.12)) { flash = (index, correct) }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            if flash?.index == index { withAnimation(.easeOut(duration: 0.2)) { flash = nil } }
        }
        guard correct else {
            mistakes += 1
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        Haptics.tap()
        if next == total {
            result = Date().timeIntervalSince(start)
            isRecord = SchulteRecords.record(result, size: size)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            phase = .finished
        } else {
            withAnimation { next += 1 }
        }
    }

    // MARK: - Итог

    private var finished: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)
            if isRecord {
                Text("Новый рекорд!")
                    .scaledFont(size: 20, weight: .bold)
                    .foregroundColor(.orange)
            }
            Text(SchulteRecords.format(result))
                .scaledFont(size: 52, weight: .bold, design: .rounded)
                .foregroundColor(.brandDark)
            Text("\(size)×\(size) · \(mistakes == 0 ? "без ошибок" : "ошибок: \(mistakes)")")
                .scaledFont(size: 16)
                .foregroundColor(.gray)
            if let best = SchulteRecords.best(size), !isRecord {
                Text("Рекорд: \(SchulteRecords.format(best))")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
            }
            VStack(spacing: 10) {
                Button(action: begin) {
                    Text("Ещё раз")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundStyle(Color.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandDark)
                Button("Другой размер") { phase = .setup }
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(.brandDark)
            }
            .padding(.top, 10)
            Spacer()
        }
        .padding(24)
    }
}
