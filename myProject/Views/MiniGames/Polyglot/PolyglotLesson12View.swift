import SwiftUI

/// Урок 12: числа, порядковые, даты и годы
struct PolyglotLesson12View: View {
    var body: some View {
        PolyglotLessonPage(number: 12, title: "Числа, даты и годы",
                           videoURL: nil,
                           makeRound: { PolyglotLesson12.round() }) {
            PolyglotParagraph("Цены, время, даты, годы рождения — числа нужны в каждом разговоре. В английском их всего около тридцати слов, остальные собираются из них.")

            PolyglotLesson12Reference()

            PolyglotHeading("Сколько: от 13 до 999")
            PolyglotParagraph("13–19 — с **-teen**, десятки — с **-ty**. Десятки и единицы — через дефис: **forty-two**. Сотни: **three hundred**, без -s. Перед десятками британцы ставят **and**.")
            PolyglotExamples(examples: [
                ("fifteen · fifty", "15 · 50 — не перепутайте ударение: fifTEEN, FIFty"),
                ("forty-four", "44 — forty без u, хотя four с u"),
                ("two hundred and twelve", "212"),
                ("a thousand people", "тысяча человек"),
            ])

            PolyglotHeading("Который по счёту")
            PolyglotParagraph("К числу прибавляют **-th**: sixth, tenth. Первые три особые: **first, second, third**. Ещё меняются fifth, eighth, ninth, twelfth и десятки: twenty → **twentieth**. Перед порядковым обычно **the** — но не после my, your, our.")
            PolyglotExamples(examples: [
                ("It's the second door on the left.", "Вторая дверь слева."),
                ("This is my first trip abroad.", "Это моя первая поездка за границу."),
                ("He finished fifth.", "Он финишировал пятым."),
            ])

            PolyglotHeading("Даты")
            PolyglotParagraph("Дата — порядковым числом: **on the fifth of May** или, по-американски, **on May fifth**. Месяцы и дни недели — всегда с заглавной буквы.")
            PolyglotExamples(examples: [
                ("The concert is on the tenth of June.", "Концерт десятого июня."),
                ("I'll call you on Friday.", "Я позвоню тебе в пятницу."),
            ])

            PolyglotHeading("Годы")
            PolyglotParagraph("Год читают парами цифр: 1984 — **nineteen eighty-four**, 2026 — **twenty twenty-six**. Ноль внутри — **oh**: 1907 — nineteen oh seven. Годы 2000–2009 — **two thousand and** …: 2008 — two thousand and eight.")
        } scheme: {
            PolyglotLesson12Reference()
        }
    }
}

struct PolyglotLesson12Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Числа")
            PolyglotGridTable(rows: [
                ["", "Сколько", "Который"],
                ["1", "one", "first"],
                ["2", "two", "second"],
                ["3", "three", "third"],
                ["5", "five", "fifth"],
                ["12", "twelve", "twelfth"],
                ["15", "fifteen", "fifteenth"],
                ["20", "twenty", "twentieth"],
                ["21", "twenty-one", "twenty-first"],
                ["100", "a hundred", "hundredth"],
            ], firstColumnWidth: 54, fontSize: 14)
            PolyglotParagraph("Дата: on **the** fifth **of** May. Год: nineteen ninety-nine, two thousand **and** five.")
        }
    }
}
