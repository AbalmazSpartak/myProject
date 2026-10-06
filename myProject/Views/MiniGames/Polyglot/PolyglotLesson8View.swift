import SwiftUI

/// Урок 8: предлоги места и направления, with / without / for / about и фразовые глаголы с go и look
struct PolyglotLesson8View: View {
    var body: some View {
        PolyglotLessonPage(number: 8, title: "Предлоги и фразовые глаголы",
                           videoURL: URL(string: "https://www.youtube.com/watch?v=3qzE9_7a_EM"),
                           makeRound: { PolyglotLesson8.round() }) {
            PolyglotParagraph("Половина курса позади! Осталось закрыть пробел — предлоги. Их немного, но без них не понять речь. А ещё предлог после глагола меняет его смысл: так получаются фразовые глаголы.")

            PolyglotLesson8Reference()

            PolyglotHeading("Где и куда")
            PolyglotExamples(examples: [
                ("I will go to school.", "Я пойду в школу."),
                ("Welcome to Russia!", "Добро пожаловать в Россию!"),
                ("Throw your ball to me.", "Брось мне свой мяч."),
                ("I am from Moscow.", "Я из Москвы."),
                ("Prices start from 5 dollars.", "Цены — от 5 долларов."),
                ("I flew over the city.", "Я пролетел над городом."),
                ("He climbed over the wall.", "Он перелез через стену."),
                ("I sat on a bench.", "Я сел на скамейку."),
                ("He knocked on the door.", "Он постучал в дверь."),
                ("I hid under the table.", "Я спрятался под столом."),
                ("He works under me.", "Он работает под моим началом."),
                ("This is between us.", "Это между нами."),
                ("Choose between these two.", "Выберите из этих двух."),
                ("She is in the kitchen.", "Она на кухне."),
                ("Made in Russia.", "Сделано в России."),
                ("I was at the meeting.", "Я был на встрече."),
                ("We will meet at six o'clock.", "Мы встретимся в шесть часов."),
            ])

            PolyglotHeading("С кем, без кого, для кого, о ком")
            PolyglotExamples(examples: [
                ("I work with them.", "Я работаю с ними."),
                ("Dance with me.", "Потанцуй со мной."),
                ("They draw with chalk.", "Они рисуют мелом."),
                ("They went without me.", "Они пошли без меня."),
                ("No smoke without fire.", "Нет дыма без огня."),
                ("This gift is for you.", "Этот подарок для тебя."),
                ("She studied English for two years.", "Она учила английский два года."),
                ("We paid for lunch.", "Мы заплатили за обед."),
                ("Think about me.", "Подумай обо мне."),
                ("Forget about her.", "Забудь о ней."),
                ("Let's talk about it.", "Давай поговорим об этом."),
            ])

            PolyglotHeading("Похожие глаголы")
            PolyglotGridTable(rows: [
                ["Глагол", "Значение"],
                ["see", "видеть — само собой: I see a bird"],
                ["look at", "смотреть на — нарочно: Look at me!"],
                ["watch", "смотреть, следить — за тем, что движется: watch TV, watch a game"],
                ["hear", "слышать — само собой: I hear music"],
                ["listen to", "слушать — нарочно: Listen to me!"],
                ["ask", "и «спросить», и «попросить» — по смыслу"],
            ], firstColumnWidth: 86)

            PolyglotHeading("Фразовые глаголы")
            PolyglotParagraph("Предлог после глагола (послелог) даёт ему новый смысл: **go back** — вернуться, **look for** — искать, **look after** — присматривать.")
            PolyglotExamples(examples: [
                ("Go up the stairs.", "Поднимайся по лестнице."),
                ("They go down the mountain.", "Они спускаются с горы."),
                ("Go away from here!", "Уходите отсюда!"),
                ("Just go back home.", "Просто возвращайся домой."),
                ("Go along this street.", "Идите вдоль этой улицы."),
                ("I go for a walk.", "Я иду гулять."),
                ("Time goes by.", "Время идёт."),
                ("Don't look up.", "Не смотри вверх."),
                ("Go and look for her.", "Пойди поищи её."),
                ("Who looks after the children?", "Кто присматривает за детьми?"),
                ("She looked away from him.", "Она отвела от него взгляд."),
                ("They looked back and saw us.", "Они оглянулись и увидели нас."),
            ])
            PolyglotParagraph("Ещё встречается **go in for sports** — «заниматься спортом», но это скорее книжное британское выражение; в разговоре обычно говорят **do sports**.")
        } scheme: {
            PolyglotLesson8Reference()
        }
    }
}

/// Таблица предлогов — в уроке и в подсказке «Схема»
struct PolyglotLesson8Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Предлоги")
            PolyglotGridTable(rows: [
                ["", "Перевод", "Пример"],
                ["to", "к, в — куда", "go to school"],
                ["from", "из, от — откуда", "I am from Moscow"],
                ["over", "над, через", "a lamp over the table"],
                ["on", "на — на поверхности", "on the table"],
                ["under", "под", "under the bed"],
                ["between", "между", "between us"],
                ["in", "в — внутри", "in the box, in the kitchen"],
                ["at", "в, на — по делу", "at work, at the meeting"],
                ["with", "с, вместе с", "with me"],
                ["without", "без", "without them"],
                ["for", "для, за", "for you"],
                ["about", "о, об", "about her"],
            ], firstColumnWidth: 80, fontSize: 14)
            PolyglotParagraph("«На кухне» по-английски — **in** the kitchen: она внутри. После предлога — вторая форма местоимения: with **me**, without **them**, about **her**.")
        }
    }
}
