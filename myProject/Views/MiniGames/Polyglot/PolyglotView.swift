import SwiftUI

/// «Полиглот»: уроки грамматики по схемам — схема и упражнение «Составь фразу» из карточек
struct PolyglotView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Уроки по схемам: посмотрите правило, потом соберите фразы из карточек.")
                        .scaledFont(size: 15)
                        .foregroundColor(.gray)

                    NavigationLink {
                        PolyglotLessonView()
                            .toolbar(.hidden, for: .navigationBar)
                    } label: {
                        lessonCard(number: 1, title: "Will / Do / Does / Did",
                                   subtitle: "Вопрос, утверждение и отрицание в будущем, настоящем и прошедшем")
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Обзор")
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            }
            Spacer()
            Text("Полиглот")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
            Spacer()
            Color.clear.frame(width: 70, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func lessonCard(number: Int, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .scaledFont(size: 26, weight: .bold, design: .serif)
                .foregroundColor(.brandDark)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.brandAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text("Урок \(number)")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(.gray)
                Text(title)
                    .scaledFont(size: 19, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text(subtitle)
                    .scaledFont(size: 14)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

/// Урок 1: схема и кнопка упражнения
struct PolyglotLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExercising = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Полиглот")
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Урок 1")
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundColor(.gray)
                        Text("Will / Do / Does / Did")
                            .scaledFont(size: 30, weight: .regular, design: .serif)
                            .foregroundColor(.brandDark)
                        Text("Одна схема — три времени и три формы. Вопрос начинается со вспомогательного слова, в отрицании к нему добавляется not. С he и she в настоящем — does, а в утверждении к глаголу добавляется -s. В прошедшем утверждении — -ed (или особая форма), а в вопросе и отрицании глагол остаётся как есть: всё прошедшее уже в did.")
                            .scaledFont(size: 16)
                            .foregroundColor(.brandDark)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PolyglotSchemeView()

                    Button { isExercising = true } label: {
                        Label("Составлять фразы", systemImage: "square.grid.3x2.fill")
                            .scaledFont(size: 18, weight: .bold)
                            .foregroundColor(.brandBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.brandDark))
                    }
                    .padding(.bottom, 20)
                }
                .padding(20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .fullScreenCover(isPresented: $isExercising) {
            PolyglotExerciseView()
                .appThemedColorScheme()
        }
    }
}

// MARK: - Схема

/// Схема урока: для каждого времени — вопрос, утверждение и отрицание; главное выделено
struct PolyglotSchemeView: View {
    private struct Row {
        let form: String
        let lines: [String]
    }

    private struct Section {
        let tense: String
        let rows: [Row]
    }

    private static let all = "I, you, we, they, he, she"
    private static let plural = "I, you, we, they"

    private let sections: [Section] = [
        Section(tense: "Будущее", rows: [
            Row(form: "Вопрос", lines: ["**Will** \(all) love**?**"]),
            Row(form: "Утверждение", lines: ["\(all) **will** love"]),
            Row(form: "Отрицание", lines: ["\(all) **will not** love"]),
        ]),
        Section(tense: "Настоящее", rows: [
            Row(form: "Вопрос", lines: ["**Do** \(plural) love**?**", "**Does** he, she love**?**"]),
            Row(form: "Утверждение", lines: ["\(plural) love", "he, she love**s**"]),
            Row(form: "Отрицание", lines: ["\(plural) **don't** love", "he, she **doesn't** love"]),
        ]),
        Section(tense: "Прошедшее", rows: [
            Row(form: "Вопрос", lines: ["**Did** \(all) love**?**"]),
            Row(form: "Утверждение", lines: ["\(all) love**d**"]),
            Row(form: "Отрицание", lines: ["\(all) **did not** love"]),
        ]),
    ]

    var body: some View {
        VStack(spacing: 14) {
            PolyglotTableView()
            Text("По временам")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            ForEach(sections, id: \.tense) { section in
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.tense)
                        .scaledFont(size: 18, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.brandAccent)
                    ForEach(section.rows, id: \.form) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.form)
                                .scaledFont(size: 12, weight: .semibold)
                                .foregroundColor(.gray)
                            ForEach(row.lines, id: \.self) { line in
                                Text(Self.marked(line))
                                    .scaledFont(size: 17, design: .serif)
                                    .foregroundColor(.brandDark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        if row.form != section.rows.last?.form {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(Color.cardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            }
        }
    }

    /// **жирное** — красным и жирным, как ключевые слова на схеме
    private static func marked(_ text: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in text.components(separatedBy: "**").enumerated() where !part.isEmpty {
            var piece = AttributedString(part)
            if !index.isMultiple(of: 2) {
                piece.inlinePresentationIntent = .stronglyEmphasized
                piece.foregroundColor = TopicText.highlight
            }
            result += piece
        }
        return result
    }
}
