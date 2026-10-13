import SwiftUI

/// Урок 9: косвенные вопросы, «сам / себя» и «к счастью / к сожалению»
struct PolyglotLesson9View: View {
    var body: some View {
        PolyglotLessonPage(number: 9, title: "Вопрос внутри фразы и «сам»",
                           videoURL: nil,
                           makeRound: { PolyglotLesson9.round() }) {
            PolyglotParagraph("Вопрос не всегда задают прямо. Часто он прячется внутри фразы: «Ты знаешь, где он живёт?», «Я не знаю, когда она придёт». Это вежливее и звучит естественнее.")

            PolyglotLesson9Reference()

            PolyglotHeading("Вопрос внутри фразы")
            PolyglotParagraph("После **know, tell me, wonder** вопрос теряет форму вопроса: порядок слов — как в обычном утверждении, **do / does / did** не нужны.")
            PolyglotExamples(examples: [
                ("Where does he live?", "Где он живёт? — прямой вопрос"),
                ("Do you know where he lives?", "Ты знаешь, где он живёт?"),
                ("When did they come?", "Когда они пришли?"),
                ("I don't know when they came.", "Я не знаю, когда они пришли."),
                ("Tell me what she wants.", "Скажи мне, чего она хочет."),
                ("I wonder why you laughed.", "Интересно, почему ты смеялся."),
            ])
            PolyglotParagraph("Вопрос без вопросительного слова — через **if**. Русское «ли» — это if.")
            PolyglotExamples(examples: [
                ("Do you know if she works today?", "Ты знаешь, работает ли она сегодня?"),
                ("I wonder if they will call.", "Интересно, позвонят ли они."),
            ])

            PolyglotHeading("Сам, себя")
            PolyglotParagraph("Когда действие возвращается к тому, кто его делает, — «себя», «себе» — к местоимению прибавляется **-self** (одному) или **-selves** (нескольким).")
            PolyglotExamples(examples: [
                ("She bought herself a new phone.", "Она купила себе новый телефон."),
                ("We should believe in ourselves.", "Нам стоит верить в себя."),
                ("I made this cake myself.", "Я испёк этот торт сам."),
                ("He lives by himself.", "Он живёт один."),
                ("Help yourself!", "Угощайся!"),
            ])
            PolyglotParagraph("**by myself** — «один, без помощи»: I travel by myself — я путешествую один.")

            PolyglotHeading("К счастью, к сожалению")
            PolyglotExamples(examples: [
                ("Fortunately, the train was late too.", "К счастью, поезд тоже опоздал."),
                ("Unfortunately, I can't stay.", "К сожалению, я не могу остаться."),
            ])
        } scheme: {
            PolyglotLesson9Reference()
        }
    }
}

struct PolyglotLesson9Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Вопрос внутри фразы")
            PolyglotGridTable(rows: [
                ["Прямо", "Внутри фразы"],
                ["Where does he live?", "I know where he lives."],
                ["What did she say?", "Tell me what she said."],
                ["When will they come?", "I wonder when they will come."],
                ["Does he work?", "Do you know if he works?"],
            ], firstColumnWidth: 150, fontSize: 14)

            PolyglotHeading("Сам, себя")
            PolyglotGridTable(rows: [
                ["Кто", "Себя, сам"],
                ["I", "myself"],
                ["you (ты)", "yourself"],
                ["he / she", "himself / herself"],
                ["we", "ourselves"],
                ["you (вы)", "yourselves"],
                ["they", "themselves"],
            ], firstColumnWidth: 110, fontSize: 14)
        }
    }
}
