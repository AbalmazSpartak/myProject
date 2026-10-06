import SwiftUI

/// Урок 3: глагол to be — формы по временам, вопрос и отрицание, таблица и упражнение
struct PolyglotLesson3View: View {
    var body: some View {
        PolyglotLessonPage(number: 3, title: "Глагол to be",
                           videoURL: URL(string: "https://youtu.be/kxzGEr5gGW4"),
                           makeRound: { PolyglotLesson3.round() }) {
            PolyglotParagraph("To be — «быть, находиться, являться». По-русски в настоящем времени его пропускают: «Он здесь», «Она учитель». В английском он нужен всегда: He **is** here, She **is** a teacher. Когда-то и в русском было так же — «Аз есмь царь».")
            PolyglotParagraph("Схема: **кто** + **to be** + **кто / где / какой**. I am **a teacher** · We are **in Moscow** · She is **happy**.")

            PolyglotLesson3Reference()

            PolyglotHeading("Вопрос")
            PolyglotParagraph("Do, does и did здесь не нужны: to be сам встаёт в начало. **Is** she here? — «Она здесь?». В будущем — **Will** he **be** ready? — «Он будет готов?».")
            PolyglotHeading("Отрицание")
            PolyglotParagraph("Not — сразу после to be: She is **not** a teacher. В будущем — **will not be**: You **will not be** a doctor.")

            PolyglotHeading("Примеры")
            PolyglotExamples(examples: [
                ("I am here.", "Я здесь."),
                ("She is a teacher.", "Она учитель."),
                ("They are students.", "Они студенты."),
                ("We were in Moscow.", "Мы были в Москве."),
                ("She was a teacher.", "Она была учителем."),
                ("He will be there.", "Он будет там."),
                ("Is she your sister?", "Она твоя сестра?"),
                ("Am I right?", "Я прав?"),
                ("Was he happy?", "Он был счастлив?"),
                ("Will he be ready?", "Он будет готов?"),
                ("I am not a doctor.", "Я не доктор."),
                ("He was not in Moscow.", "Он не был в Москве."),
                ("They are not from England.", "Они не из Англии."),
                ("You will not be a doctor.", "Ты не будешь доктором."),
            ])

            PolyglotParagraph("Неправильные глаголы (go — went — gone и другие) — в «Сообществе» → «Грамматика».")
        } scheme: {
            PolyglotLesson3Reference()
        }
    }
}

/// Формы to be и таблица урока — и в уроке, и в подсказке «Схема»
struct PolyglotLesson3Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Формы to be")
            PolyglotGridTable(rows: [
                ["Кто", "Настоящее", "Прошедшее", "Будущее"],
                ["I", "am", "was", "will be"],
                ["he, she, it", "is", "was", "will be"],
                ["you, we, they", "are", "were", "will be"],
            ])
            PolyglotTableView(title: "Таблица to be", groups: Self.table,
                              accessibilityText: "Таблица to be: will be, am, is, are, was, were — вопрос, утверждение и отрицание")
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 20, weight: .semibold, design: .serif)
            .foregroundColor(.brandDark)
            .padding(.top, 6)
    }

    private typealias Piece = PolyglotTableView.Piece
    private typealias Row = PolyglotTableView.Row

    private static let question: [PolyglotTableView.Line] = [[Piece(text: "?", isKey: true)]]

    private static func row(_ label: String, _ pronouns: [String]) -> Row {
        Row(label: label, pronouns: pronouns, question: question,
            affirmative: [[Piece(text: label, isKey: true)]],
            negative: [[Piece(text: label, isKey: true)], [Piece(text: "NOT", isKey: true)]])
    }

    static let table: [PolyglotTableView.Group] = [
        .init(label: "Будущее", rows: [
            Row(label: "WILL", pronouns: ["I", "HE", "SHE", "YOU", "WE", "THEY"],
                question: [[Piece(text: "BE"), Piece(text: " ?", isKey: true)]],
                affirmative: [[Piece(text: "WILL", isKey: true)], [Piece(text: "BE")]],
                negative: [[Piece(text: "WILL", isKey: true)], [Piece(text: "NOT", isKey: true)], [Piece(text: "BE")]]),
        ]),
        .init(label: "Настоящее", rows: [row("AM", ["I"]), row("IS", ["HE", "SHE"]), row("ARE", ["YOU", "WE", "THEY"])]),
        .init(label: "Прошедшее", rows: [row("WAS", ["I", "HE", "SHE"]), row("WERE", ["YOU", "WE", "THEY"])]),
    ]
}
