import SwiftUI

/// Урок 10: «я думаю, что…», когда / если — без will, и неправильное множественное
struct PolyglotLesson10View: View {
    var body: some View {
        PolyglotLessonPage(number: 10, title: "Думаю, что… Когда придёт…",
                           videoURL: nil,
                           makeRound: { PolyglotLesson10.round() }) {
            PolyglotParagraph("Фразы становятся длиннее: одна мысль внутри другой. «Я думаю, что он прав», «Когда ты вернёшься, мы поужинаем». Для этого нужно всего несколько связок.")

            PolyglotLesson10Reference()

            PolyglotHeading("Я думаю, что…")
            PolyglotParagraph("**that** — «что» в середине фразы. После него — обычное утверждение в любом времени. В разговоре that часто пропускают, но с ним понятнее.")
            PolyglotExamples(examples: [
                ("I think that you are right.", "Я думаю, что ты прав."),
                ("I don't think that it will rain.", "Не думаю, что пойдёт дождь."),
                ("I hope that you slept well.", "Надеюсь, ты хорошо выспался."),
                ("We know that she works here.", "Мы знаем, что она здесь работает."),
            ])
            PolyglotParagraph("По-русски «я думаю, что он не придёт», а по-английски отрицание переносят вперёд: **I don't think** that he will come.")

            PolyglotHeading("Когда, если, после того как")
            PolyglotParagraph("Главное правило урока: после **when, if, after, before** будущее говорят формой настоящего — **без will**. Will остаётся только во второй половине.")
            PolyglotExamples(examples: [
                ("When the film ends, we will go home.", "Когда фильм закончится, мы пойдём домой."),
                ("If you call me, I will come.", "Если ты мне позвонишь, я приду."),
                ("After she finishes, she will rest.", "После того как она закончит, она отдохнёт."),
                ("Before you leave, I will make tea.", "Перед тем как ты уйдёшь, я заварю чай."),
            ])

            PolyglotHeading("Не по правилам: children, people")
            PolyglotParagraph("Обычно множественное число — с **-s**: books, cars. Но несколько частых слов меняются целиком — их стоит просто запомнить.")
            PolyglotGridTable(rows: [
                ["Один", "Много"],
                ["child — ребёнок", "children — дети"],
                ["person — человек", "people — люди"],
                ["man — мужчина", "men — мужчины"],
                ["woman — женщина", "women — женщины"],
                ["foot — ступня", "feet — ступни"],
                ["tooth — зуб", "teeth — зубы"],
                ["mouse — мышь", "mice — мыши"],
            ], firstColumnWidth: 150, fontSize: 14)
        } scheme: {
            PolyglotLesson10Reference()
        }
    }
}

struct PolyglotLesson10Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Связки")
            PolyglotGridTable(rows: [
                ["", "Пример"],
                ["that — что", "I think that he is busy."],
                ["when — когда", "When he comes, I will call."],
                ["if — если", "If it rains, we will stay."],
                ["after — после того как", "After you eat, we will go."],
                ["before — перед тем как", "Before she leaves, I will help."],
            ], firstColumnWidth: 120, fontSize: 14)
            PolyglotParagraph("После when, if, after, before — **без will**: when he **comes**, а не when he will come.")
        }
    }
}
