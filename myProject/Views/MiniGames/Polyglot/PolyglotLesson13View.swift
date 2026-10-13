import SwiftUI

/// Урок 13: модальные глаголы can / could, should, must и let
struct PolyglotLesson13View: View {
    var body: some View {
        PolyglotLessonPage(number: 13, title: "Могу, стоит, должен, давай",
                           videoURL: nil,
                           makeRound: { PolyglotLesson13.round() }) {
            PolyglotParagraph("Модальные глаголы говорят не о самом действии, а об отношении к нему: могу, стоит, обязан, нельзя. Они ставятся перед обычным глаголом — и у них свои простые правила.")

            PolyglotLesson13Reference()

            PolyglotHeading("Три правила для всех")
            PolyglotParagraph("1. После модального глагол **без to**: I can swim, а не can to swim.\n2. **Без -s** в третьем лице: she can, he must — и глагол после них тоже без -s: she can **dance**.\n3. Вопрос и отрицание — без do: **Can** you…? I **can't**…")

            PolyglotHeading("Can и could — могу, умею")
            PolyglotExamples(examples: [
                ("I can ride a bike.", "Я умею кататься на велосипеде."),
                ("She can't come today.", "Она не может прийти сегодня."),
                ("When I was five, I could read.", "В пять лет я уже умел читать."),
                ("Could you pass the salt?", "Не передадите соль? — could звучит вежливее, чем can"),
            ])

            PolyglotHeading("Should — стоит, следует")
            PolyglotExamples(examples: [
                ("You should see a doctor.", "Тебе стоит сходить к врачу."),
                ("We shouldn't be late.", "Нам не стоит опаздывать."),
                ("Should I bring something?", "Мне что-нибудь принести?"),
            ])

            PolyglotHeading("Must — должен; mustn't — нельзя")
            PolyglotExamples(examples: [
                ("I must finish this today.", "Я должен закончить это сегодня."),
                ("You mustn't smoke here.", "Здесь нельзя курить."),
            ])
            PolyglotParagraph("Осторожно: **mustn't** — это запрет, «нельзя», а не «не обязан».")

            PolyglotHeading("Let — давай, пусть")
            PolyglotExamples(examples: [
                ("Let's take a break.", "Давай сделаем перерыв."),
                ("Let's not argue.", "Давай не будем спорить."),
                ("Let him decide.", "Пусть он решает."),
                ("Let me help you.", "Давай я тебе помогу."),
            ])
        } scheme: {
            PolyglotLesson13Reference()
        }
    }
}

struct PolyglotLesson13Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Модальные глаголы")
            PolyglotGridTable(rows: [
                ["", "Да", "Нет", "Вопрос"],
                ["могу", "I can swim", "I can't swim", "Can you swim?"],
                ["мог", "I could swim", "I couldn't swim", "Could you swim?"],
                ["стоит", "You should rest", "You shouldn't rest", "Should I rest?"],
                ["должен", "I must go", "You mustn't go — нельзя", "Must I go?"],
            ], firstColumnWidth: 70, fontSize: 13)
            PolyglotParagraph("Давай — **let's** + глагол; давай не будем — **let's not**; пусть он — **let him**.")
        }
    }
}
