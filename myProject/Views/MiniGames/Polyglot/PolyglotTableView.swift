import SwiftUI

/// Таблица глаголов — как в учебнике: Вопрос / Утверждение / Отрицание × строки (WILL, DO, DOES, DID — урок 1;
/// WILL, AM, IS, ARE, WAS, WERE — урок 3). В ячейке слева местоимения, справа — что к ним добавляется;
/// справа вертикально — время
struct PolyglotTableView: View {
    /// Слово справа от местоимений: обычное или выделенное (WILL, NOT, ?, окончание -S)
    struct Piece: Hashable {
        let text: String
        var isKey = false
    }

    /// Строка справа: несколько кусков в одну линию — «LOVE» + «?», «LOVE» + «S»
    typealias Line = [Piece]

    struct Row: Hashable {
        let label: String
        let pronouns: [String]
        let question: [Line]
        let affirmative: [Line]
        let negative: [Line]
    }

    /// Время сбоку и сколько строк таблицы оно охватывает
    struct Group {
        let label: String
        let rows: [Row]
    }

    var title = "Таблица глаголов"
    var groups: [Group] = Self.lesson1
    var accessibilityText = "Таблица глаголов: will, do, does, did — вопрос, утверждение и отрицание в будущем, настоящем и прошедшем"

    init(title: String = "Таблица глаголов", groups: [Group] = Self.lesson1,
         accessibilityText: String = "Таблица глаголов: will, do, does, did — вопрос, утверждение и отрицание в будущем, настоящем и прошедшем") {
        self.title = title
        self.groups = groups
        self.accessibilityText = accessibilityText
    }

    private static let all = ["I", "YOU", "WE", "THEY", "HE", "SHE"]
    private static let love = Piece(text: "LOVE")

    static var lesson1: [Group] {
        [Group(label: "Будущее", rows: [rows1[0]]),
         Group(label: "Настоящее", rows: [rows1[1], rows1[2]]),
         Group(label: "Прошедшее", rows: [rows1[3]])]
    }

    private static let rows1: [Row] = [
        Row(label: "WILL", pronouns: all,
            question: [[love, Piece(text: " ?", isKey: true)]],
            affirmative: [[Piece(text: "WILL", isKey: true)], [love]],
            negative: [[Piece(text: "WILL", isKey: true)], [Piece(text: "NOT", isKey: true)], [love]]),
        Row(label: "DO", pronouns: ["I", "YOU", "WE", "THEY"],
            question: [[love, Piece(text: " ?", isKey: true)]],
            affirmative: [[love]],
            negative: [[Piece(text: "DON'T", isKey: true)], [love]]),
        Row(label: "DOES", pronouns: ["HE", "SHE"],
            question: [[love, Piece(text: " ?", isKey: true)]],
            affirmative: [[love, Piece(text: "S", isKey: true)]],
            negative: [[Piece(text: "DOESN'T", isKey: true)], [love]]),
        Row(label: "DID", pronouns: all,
            question: [[love, Piece(text: " ?", isKey: true)]],
            affirmative: [[love, Piece(text: "D", isKey: true)]],
            negative: [[Piece(text: "DID", isKey: true)], [Piece(text: "NOT", isKey: true)], [love]]),
    ]

    // Размеры постоянные: высоты строк таблицы и подписи времени справа должны совпадать
    private let fontSize: CGFloat = 12
    private let lineHeight: CGFloat = 16
    private let labelWidth: CGFloat = 50
    private let sideWidth: CGFloat = 20
    private let line: CGFloat = 1

    private func height(_ row: Row) -> CGFloat {
        // По самому высокому столбику ячеек: местоимения или добавка («AM / NOT» при одном «I»)
        let lines = max(row.pronouns.count, row.question.count, row.affirmative.count, row.negative.count)
        return CGFloat(lines) * lineHeight + 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)

            VStack(spacing: 0) {
                header
                rule()
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, group in
                            if groupIndex > 0 { rule() }
                            ForEach(Array(group.rows.enumerated()), id: \.offset) { rowIndex, row in
                                // Строки одного времени (DO и DOES) — через тонкую серую линию
                                if rowIndex > 0 { Rectangle().fill(Color.gray.opacity(0.5)).frame(height: 1) }
                                tableRow(row)
                            }
                        }
                    }
                    rule(vertical: true)
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, group in
                            if groupIndex > 0 { rule() }
                            side(group.label, height: group.rows.map(height).reduce(0, +) + CGFloat(group.rows.count - 1))
                        }
                    }
                    .frame(width: sideWidth)
                }
            }
            .background(Color.cardBackground)
            .overlay(Rectangle().stroke(Color.brandDark, lineWidth: 1.5))
            .foregroundColor(.brandDark)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// Шапка по той же сетке, что и строки: над подписями WILL… — пусто, «Вопрос» над своим столбцом
    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth + line)
            Text("Вопрос").frame(maxWidth: .infinity)
            rule(vertical: true)
            Text("Утверждение").frame(maxWidth: .infinity)
            rule(vertical: true)
            Text("Отрицание").frame(maxWidth: .infinity)
            rule(vertical: true)
            Color.clear.frame(width: sideWidth)
        }
        .font(.system(size: fontSize + 1))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(height: 28)
    }

    private func tableRow(_ row: Row) -> some View {
        HStack(spacing: 0) {
            Text(row.label)
                .font(.system(size: fontSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: labelWidth)
            rule(vertical: true)
            cell(row.pronouns, row.question)
            rule(vertical: true)
            cell(row.pronouns, row.affirmative)
            rule(vertical: true)
            cell(row.pronouns, row.negative)
        }
        .frame(height: height(row))
    }

    /// Местоимения столбиком слева, добавка — справа ступенькой, по центру по высоте
    private func cell(_ pronouns: [String], _ lines: [Line]) -> some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(pronouns, id: \.self) { pronoun in
                    Text(pronoun).frame(height: lineHeight)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, pieces in
                    pieces.reduce(Text("")) { text, piece in
                        text + Text(piece.text).fontWeight(piece.isKey ? .heavy : .regular)
                    }
                    .frame(height: lineHeight)
                }
            }
        }
        .font(.system(size: fontSize))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
    }

    /// Время сбоку: буквы повёрнуты, читается сверху вниз
    private func side(_ text: String, height: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize - 1, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .rotationEffect(.degrees(90))
            .frame(width: sideWidth, height: height)
    }

    private func rule(vertical: Bool = false) -> some View {
        Rectangle()
            .fill(Color.brandDark)
            .frame(width: vertical ? line : nil, height: vertical ? nil : line)
    }
}
