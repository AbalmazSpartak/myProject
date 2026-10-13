import SwiftUI

/// Урок 14: вопрос к подлежащему и к дополнению, условие в начале и в конце фразы
struct PolyglotLesson14View: View {
    var body: some View {
        PolyglotLessonPage(number: 14, title: "Кто сделал? Кому сделал?",
                           videoURL: nil,
                           makeRound: { PolyglotLesson14.round() }) {
            PolyglotParagraph("«Кто помог тебе?» и «Кому ты помог?» — по-русски разницу дают окончания: кто — кому. По-английски в обоих вопросах who, а разницу даёт do: есть он или нет.")

            PolyglotLesson14Reference()

            PolyglotHeading("Кто сделал — без do")
            PolyglotParagraph("Если **who** или **what** — это тот, кто действует, вопрос строится как утверждение: who + глагол. Do, does, did не нужны, глагол — как после he: **-s** в настоящем, вторая форма в прошедшем.")
            PolyglotExamples(examples: [
                ("Who lives here?", "Кто здесь живёт?"),
                ("Who broke the cup?", "Кто разбил чашку?"),
                ("What happened?", "Что случилось?"),
                ("Who will drive?", "Кто поведёт машину?"),
            ])

            PolyglotHeading("Кого, кому, что сделал — с do")
            PolyglotParagraph("Если действует кто-то другой, а спрашиваем о том, на кого или на что направлено действие, — обычный вопрос с **do / does / did**. После did глагол — в первой форме.")
            PolyglotExamples(examples: [
                ("Who did you invite?", "Кого ты пригласил?"),
                ("Who does she work for?", "На кого она работает?"),
                ("What did they buy?", "Что они купили?"),
            ])
            PolyglotParagraph("Сравните: **Who called you?** — кто тебе звонил? **Who did you call?** — кому ты звонил?")

            PolyglotHeading("Если — в начале или в конце")
            PolyglotParagraph("Условие из урока 10 можно поставить и в конец фразы — правило то же: после **if** и **when** — без will. Если условие первое, после него ставят запятую.")
            PolyglotExamples(examples: [
                ("If it rains, we will stay at home.", "Если пойдёт дождь, мы останемся дома."),
                ("We will stay at home if it rains.", "Мы останемся дома, если пойдёт дождь."),
                ("I'll text you when I arrive.", "Я напишу тебе, когда приеду."),
            ])
        } scheme: {
            PolyglotLesson14Reference()
        }
    }
}

struct PolyglotLesson14Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Who: кто или кого")
            PolyglotGridTable(rows: [
                ["", "Кто сделал", "Кого / кому сделал"],
                ["Сейчас", "Who helps you?", "Who do you help?"],
                ["Было", "Who helped you?", "Who did you help?"],
                ["Будет", "Who will help you?", "Who will you help?"],
            ], firstColumnWidth: 70, fontSize: 13)
            PolyglotParagraph("If / when + настоящее, без will: **if it rains**, we will stay.")
        }
    }
}
