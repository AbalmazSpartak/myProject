import SwiftUI

/// Урок 11: длительные времена — процесс сейчас, в момент в прошлом и в будущем
struct PolyglotLesson11View: View {
    var body: some View {
        PolyglotLessonPage(number: 11, title: "Процесс: am, was, will be + -ing",
                           videoURL: nil,
                           makeRound: { PolyglotLesson11.round() }) {
            PolyglotParagraph("Простые времена из урока 1 говорят о факте или привычке: «я читаю книги» — вообще, по жизни. А если нужно сказать «я читаю прямо сейчас», «вчера в пять я спал», «завтра в это время мы будем лететь» — это процесс. Для него — длительные времена.")

            PolyglotLesson11Reference()

            PolyglotHeading("Как строится")
            PolyglotParagraph("**to be** в нужном времени + глагол с окончанием **-ing**. Вопрос — to be вперёд, отрицание — not после него. Do, does, did здесь не нужны.")
            PolyglotExamples(examples: [
                ("Look! The baby is sleeping.", "Смотри! Малыш спит."),
                ("Are you listening to me?", "Ты меня слушаешь?"),
                ("I was cooking when the lights went out.", "Я готовил, когда выключили свет."),
                ("They weren't working at noon.", "В полдень они не работали."),
                ("This time next week we will be swimming in the sea.", "Через неделю в это время мы будем плавать в море."),
            ])

            PolyglotHeading("Как прибавить -ing")
            PolyglotGridTable(rows: [
                ["Правило", "Пример"],
                ["обычно — просто -ing", "read → reading, play → playing"],
                ["немая -e пропадает", "write → writing, dance → dancing"],
                ["короткое слово: гласная + согласная — согласная удваивается", "swim → swimming, run → running"],
            ], firstColumnWidth: 150, fontSize: 14)

            PolyglotHeading("Факт или процесс")
            PolyglotExamples(examples: [
                ("She usually walks to work.", "Она обычно ходит на работу пешком. — привычка"),
                ("She is walking to work now.", "Сейчас она идёт на работу. — процесс"),
                ("I read every evening.", "Я читаю каждый вечер."),
                ("I am reading a great book.", "Я сейчас читаю отличную книгу."),
            ])
            PolyglotParagraph("Подсказки: **usually, every day, often** — простое время; **now, at the moment, at five o'clock, when I called** — длительное. Глаголы know, want, love, like в длительном почти не бывают: I **know**, а не I am knowing.")
        } scheme: {
            PolyglotLesson11Reference()
        }
    }
}

struct PolyglotLesson11Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Схема")
            PolyglotGridTable(rows: [
                ["", "Вопрос", "Да", "Нет"],
                ["Будет", "Will you be working?", "I will be working", "I will not be working"],
                ["Сейчас", "Are you working?", "I am / he is / we are working", "I am not working"],
                ["Было", "Were you working?", "I was / we were working", "I was not working"],
            ], firstColumnWidth: 64, fontSize: 13)
        }
    }
}
