import SwiftUI

/// Урок 16: страдательный залог — be + третья форма
struct PolyglotLesson16View: View {
    var body: some View {
        PolyglotLessonPage(number: 16, title: "Сделано: был построен, будет отправлено",
                           videoURL: nil,
                           makeRound: { PolyglotLesson16.round() }) {
            PolyglotParagraph("Иногда неважно, кто сделал, — важно, что сделано: «дом построен в 1900 году», «письмо отправлено», «здесь говорят по-английски». Это страдательный залог: в центре — предмет, а не тот, кто действует.")

            PolyglotLesson16Reference()

            PolyglotHeading("Как строится")
            PolyglotParagraph("**to be** в нужном времени + **третья форма** глагола. У правильных она такая же, как прошедшая: cleaned, opened. У неправильных — своя: written, stolen, broken — её стоит выучить вместе со второй.")
            PolyglotExamples(examples: [
                ("English is spoken all over the world.", "На английском говорят по всему миру."),
                ("The museum was opened in 1990.", "Музей открыли в 1990 году."),
                ("Your order will be delivered tomorrow.", "Ваш заказ доставят завтра."),
                ("My bike was stolen last week.", "У меня на прошлой неделе украли велосипед."),
            ])
            PolyglotParagraph("По-русски часто говорят без «был»: «музей открыли», «заказ доставят», — а по-английски такие фразы удобно строить страдательным залогом.")

            PolyglotHeading("Вопрос и отрицание")
            PolyglotParagraph("Как с to be в уроке 3: вопрос — be вперёд, отрицание — not после него. Do и did не нужны.")
            PolyglotExamples(examples: [
                ("Was the window broken?", "Окно было разбито?"),
                ("The tickets weren't sold.", "Билеты не продали."),
                ("When will the results be announced?", "Когда объявят результаты?"),
            ])

            PolyglotHeading("Кем — by, чем — with")
            PolyglotExamples(examples: [
                ("This picture was painted by my sister.", "Эту картину нарисовала моя сестра."),
                ("The cake was decorated with strawberries.", "Торт украсили клубникой."),
            ])
            PolyglotParagraph("Страдательный залог бывает и в длительных и перфектных временах (is being built, has been sent) — это уже следующая ступень.")
        } scheme: {
            PolyglotLesson16Reference()
        }
    }
}

struct PolyglotLesson16Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Be + третья форма")
            PolyglotGridTable(rows: [
                ["", "Да", "Нет", "Вопрос"],
                ["Сейчас", "It is cleaned", "It isn't cleaned", "Is it cleaned?"],
                ["Было", "It was built", "It wasn't built", "Was it built?"],
                ["Будет", "It will be sent", "It won't be sent", "Will it be sent?"],
            ], firstColumnWidth: 64, fontSize: 13)
            PolyglotGridTable(rows: [
                ["Глагол", "Было", "Сделано"],
                ["write", "wrote", "written"],
                ["break", "broke", "broken"],
                ["steal", "stole", "stolen"],
                ["build", "built", "built"],
                ["send", "sent", "sent"],
            ], firstColumnWidth: 80, fontSize: 13)
            PolyglotParagraph("Кем — **by** my friend; чем — **with** a knife.")
        }
    }
}
