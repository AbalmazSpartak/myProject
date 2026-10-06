import SwiftUI

/// Урок 4: рассказ о себе — профессии, предлоги in, as, at и артикли a, an, the
struct PolyglotLesson4View: View {
    var body: some View {
        PolyglotLessonPage(number: 4, title: "Рассказ о себе и артикли",
                           videoURL: URL(string: "https://youtu.be/8MJFDVmO6q8"),
                           makeRound: { PolyglotLesson4.round() }) {
            PolyglotParagraph("Рассказать о себе — одна из первых задач в любом языке. Хватит схем из прошлых уроков: кто вы, кем и где работаете. Не напрягайтесь: подумайте, что ответили бы по-русски, и соберите это из знакомых частей.")

            PolyglotHeading("Знакомство")
            PolyglotExamples(examples: [
                ("What do you do?", "Чем вы занимаетесь?"),
                ("Where do you work?", "Где вы работаете?"),
                ("What is your profession?", "Какая у вас профессия?"),
            ])

            PolyglotHeading("Профессии")
            PolyglotParagraph("Названия профессий обычно получаются из слова о деле и суффикса **-er, -or, -ist** или **-ian**:")
            PolyglotGridTable(rows: [
                ["", "Слово → профессия", "Перевод"],
                ["-er", "dance → dancer", "танцор"],
                ["", "build → builder", "строитель"],
                ["", "write → writer", "писатель"],
                ["-or", "act → actor", "актёр"],
                ["", "invent → inventor", "изобретатель"],
                ["", "edit → editor", "редактор"],
                ["-ist", "journal → journalist", "журналист"],
                ["", "tattoo → tattooist", "татуировщик"],
                ["", "physics → physicist", "физик"],
                ["-ian", "music → musician", "музыкант"],
                ["", "electric → electrician", "электрик"],
                ["", "logistics → logistician", "логист"],
            ], firstColumnWidth: 72)
            PolyglotParagraph("Бывают и исключения: **nurse** — медсестра, **flight attendant** — бортпроводник, **judge** — и «судья», и «судить».")

            PolyglotLesson4Reference()

            PolyglotHeading("Примеры")
            PolyglotExamples(examples: [
                ("She works in Moscow.", "Она работает в Москве."),
                ("He works in a big company.", "Он работает в большой компании."),
                ("I work in a school as a teacher.", "Я работаю в школе учителем."),
                ("He works as an engineer.", "Он работает инженером."),
                ("I am at the airport.", "Я в аэропорту — собираюсь улететь."),
                ("They are at school.", "Они в школе — там учатся."),
                ("He is at work.", "Он на работе."),
                ("He is an actor.", "Он актёр."),
                ("You need a doctor.", "Тебе нужен врач — какой-нибудь."),
                ("You need the doctor.", "Тебе нужен этот врач — тот самый."),
                ("Where is the writer?", "Где этот писатель?"),
                ("I want apples.", "Я хочу яблоки — какие угодно."),
                ("I want the apples.", "Я хочу эти яблоки — вот эти, в вазе."),
            ])

            PolyglotHeading("Слова для запоминания")
            PolyglotGridTable(rows: [
                ["Слово", "Перевод"],
                ["novel", "роман"],
                ["cinema", "кино"],
                ["order", "заказ, порядок"],
                ["jewel", "драгоценный камень"],
                ["fiction", "художественная литература"],
                ["character", "персонаж"],
                ["film director", "кинорежиссёр"],
                ["public relations (PR)", "связи с общественностью"],
                ["to play a role", "играть роль"],
                ["You know what I mean", "Ты знаешь, что я имею в виду"],
            ])
        } scheme: {
            VStack(spacing: 20) {
                PolyglotLesson4Reference()
                PolyglotLesson3Reference()
            }
        }
    }
}

/// Предлоги и артикли урока 4 — и в уроке, и в подсказке «Схема»
struct PolyglotLesson4Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Предлоги: in, as, at")
            PolyglotGridTable(rows: [
                ["", "Когда", "Пример"],
                ["in", "где: город, улица, компания", "She works in Moscow."],
                ["as", "кем, в качестве кого", "He works as an engineer."],
                ["at", "где и зачем: на работе, в школе, в аэропорту", "They are at school."],
            ], firstColumnWidth: 56)
            PolyglotParagraph("**At** — не просто «в здании», а «там по делу»: at work — работает, at school — учится, at the airport — улетает.")

            PolyglotHeading("Артикли: a, an, the")
            PolyglotParagraph("Артикли — сокращённые слова. **A / an** — это **one**, «один, какой-то». **The** — это **this / that**, «этот, тот самый».")
            PolyglotGridTable(rows: [
                ["", "Когда"],
                ["a", "один, какой-то — перед согласным звуком: a doctor, a factory"],
                ["an", "то же, перед гласным звуком: an actor, an engineer, an hour"],
                ["the", "конкретный, тот самый или единственный — и с множественным: the apples"],
                ["—", "множественное «вообще»: I want apples"],
            ], firstColumnWidth: 56)
            PolyglotParagraph("A и an — только с единственным числом. An выбирают по **звуку**, а не по букве: an **h**our (h не читается), но a **u**niversity (звучит «ю»).")
        }
    }
}
