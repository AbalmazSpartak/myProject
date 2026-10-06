import SwiftUI

/// Урок 5: степени сравнения прилагательных, слова и предлоги времени, месяцы и дни недели
struct PolyglotLesson5View: View {
    var body: some View {
        PolyglotLessonPage(number: 5, title: "Сравнения и время",
                           videoURL: URL(string: "https://www.youtube.com/watch?v=ocoj1w-yuAg"),
                           makeRound: { PolyglotLesson5.round() }) {
            PolyglotParagraph("Прилагательные отвечают на вопрос «какой?»: **big** — большой, **small** — маленький, **good** — хороший, **bad** — плохой. 30–40 прилагательных хватает почти на всю обычную речь.")

            PolyglotHeading("Короткие слова: -er и -est")
            PolyglotParagraph("Односложные: сравнение — **-er** и **than** («чем»), «самый» — **the** + **-est**. Двусложные на -y — так же, y меняется на i: happy → happier → the happiest.")
            PolyglotExamples(examples: [
                ("A car is faster than a bicycle.", "Машина быстрее, чем велосипед."),
                ("She is younger than them.", "Она моложе, чем они."),
                ("This house is older than that one.", "Этот дом старше, чем тот."),
                ("My car is the fastest.", "Моя машина самая быстрая."),
                ("She is the youngest here.", "Она самая молодая здесь."),
            ])
            PolyglotGridTable(rows: [
                ["Слово", "Сравнение", "Самый"],
                ["old", "older — старше", "the oldest"],
                ["young", "younger — моложе", "the youngest"],
                ["short", "shorter — короче", "the shortest"],
                ["long", "longer — длиннее", "the longest"],
                ["small", "smaller — меньше", "the smallest"],
                ["large", "larger — больше", "the largest"],
                ["big", "bigger — больше", "the biggest"],
                ["happy", "happier — счастливее", "the happiest"],
            ], firstColumnWidth: 70)
            PolyglotParagraph("Правила написания. Слово кончается на немую **e** — добавляются только **-r** и **-st**: large → large**r**, the large**st**. Одна согласная после одной гласной — удваивается: bi**gg**er, ho**tt**est.")

            PolyglotHeading("Длинные слова: more и most")
            PolyglotParagraph("Остальные двусложные и длинные слова не меняются: сравнение — **more** («более»), «самый» — **the most**.")
            PolyglotExamples(examples: [
                ("A car is more expensive than a bicycle.", "Машина дороже, чем велосипед."),
                ("She is more beautiful.", "Она красивее."),
                ("My car is the most expensive.", "Моя машина самая дорогая."),
                ("This house is the most comfortable.", "Этот дом самый удобный."),
            ])
            PolyglotGridTable(rows: [
                ["Слово", "Сравнение", "Самый"],
                ["expensive", "more expensive", "the most expensive"],
                ["beautiful", "more beautiful", "the most beautiful"],
                ["comfortable", "more comfortable", "the most comfortable"],
                ["interesting", "more interesting", "the most interesting"],
                ["famous", "more famous", "the most famous"],
            ])

            PolyglotHeading("Исключения")
            PolyglotGridTable(rows: [
                ["Слово", "Сравнение", "Самый"],
                ["good — хороший", "better — лучше", "the best"],
                ["bad — плохой", "worse — хуже", "the worst"],
                ["much / many — много", "more — больше", "the most"],
                ["little — мало", "less — меньше", "the least"],
            ])
            PolyglotParagraph("**Much** — с тем, что не посчитать (much water), **many** — с тем, что можно посчитать (many books). **Little** здесь — «мало», а не «маленький»: для размера — small, smaller.")

            PolyglotHeading("Слова времени")
            PolyglotGridTable(rows: [
                ["Слово", "Перевод"],
                ["now", "сейчас"],
                ["today", "сегодня"],
                ["yesterday", "вчера"],
                ["tomorrow", "завтра"],
            ])
            PolyglotExamples(examples: [
                ("He spoke yesterday.", "Он говорил вчера."),
                ("We won today.", "Мы выиграли сегодня."),
                ("Call her tomorrow.", "Позвони ей завтра."),
            ])

            PolyglotHeading("Через и назад: in и ago")
            PolyglotParagraph("**In** перед сроком — «через», о будущем. **Ago** после срока — «назад», о прошлом.")
            PolyglotGridTable(rows: [
                ["Через", "Назад"],
                ["in a week — через неделю", "a week ago — неделю назад"],
                ["in 3 days — через 3 дня", "3 days ago — 3 дня назад"],
                ["in 2 months — через 2 месяца", "2 months ago — 2 месяца назад"],
                ["in 1 year — через год", "1 year ago — год назад"],
            ])
            PolyglotExamples(examples: [
                ("I will be there in two weeks.", "Я буду там через две недели."),
                ("He will come in 3 days.", "Он придёт через 3 дня."),
                ("He was here 3 years ago.", "Он был здесь 3 года назад."),
                ("I saw him a week ago.", "Я видел его неделю назад."),
            ])

            PolyglotHeading("Месяцы и времена года: in")
            PolyglotParagraph("С месяцами и временами года **in** значит «в»: **in** June — в июне, **in** winter — зимой.")
            PolyglotGridTable(rows: [
                ["Месяц", "Перевод"],
                ["January", "январь"], ["February", "февраль"], ["March", "март"], ["April", "апрель"],
                ["May", "май"], ["June", "июнь"], ["July", "июль"], ["August", "август"],
                ["September", "сентябрь"], ["October", "октябрь"], ["November", "ноябрь"], ["December", "декабрь"],
            ])
            PolyglotGridTable(rows: [
                ["Время года", "Перевод"],
                ["winter", "зима — in winter, зимой"],
                ["spring", "весна — in spring, весной"],
                ["summer", "лето — in summer, летом"],
                ["autumn (в США — fall)", "осень — in autumn, осенью"],
            ])
            PolyglotExamples(examples: [
                ("He will come in June.", "Он придёт в июне."),
                ("I will go to Moscow in winter.", "Я поеду в Москву зимой."),
                ("We will be there in autumn.", "Мы будем там осенью."),
            ])

            PolyglotHeading("Дни недели: on")
            PolyglotGridTable(rows: [
                ["День", "Перевод"],
                ["Monday", "понедельник"], ["Tuesday", "вторник"], ["Wednesday", "среда"], ["Thursday", "четверг"],
                ["Friday", "пятница"], ["Saturday", "суббота"], ["Sunday", "воскресенье"],
            ])
            PolyglotExamples(examples: [
                ("I will be here on Monday.", "Я буду здесь в понедельник."),
                ("See you on Tuesday.", "Увидимся во вторник."),
                ("I work on Saturday.", "Я работаю в субботу."),
            ])

            PolyglotHeading("Часы: at")
            PolyglotExamples(examples: [
                ("Come at two o'clock.", "Приходи в два часа."),
                ("The bank opens at nine o'clock.", "Банк открывается в девять часов."),
                ("The store closes at seven.", "Магазин закрывается в семь."),
            ])

            PolyglotHeading("Last, this, next — без предлога")
            PolyglotParagraph("С **last** (прошлый), **this** (этот) и **next** (следующий) предлог не нужен: next year — в следующем году, а не «in next year».")
            PolyglotExamples(examples: [
                ("Was she here last November?", "Она была здесь в прошлом ноябре?"),
                ("I will come next year.", "Я приду в следующем году."),
                ("I was busy this month.", "Я был занят в этом месяце."),
                ("See you next winter.", "Увидимся следующей зимой."),
            ])

            PolyglotHeading("До и после: before, after")
            PolyglotExamples(examples: [
                ("We met before New Year.", "Мы встретились до Нового года."),
                ("May comes after April.", "Май идёт после апреля."),
                ("Come home before six.", "Приходи домой до шести."),
                ("It was after five o'clock.", "Это было после пяти часов."),
            ])
        } scheme: {
            PolyglotLesson5Reference()
        }
    }
}

/// Шпаргалка для упражнения: сравнение и предлоги времени
struct PolyglotLesson5Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("Сравнение")
            PolyglotGridTable(rows: [
                ["Слово", "Сравнение", "Самый"],
                ["короткое", "-er + than", "the -est"],
                ["длинное", "more … than", "the most …"],
                ["good / bad", "better / worse", "the best / the worst"],
            ])
            PolyglotParagraph("Than — «чем», не путайте с then — «потом». После than — вторая форма: than **me**, than **him**, than **them**.")
            PolyglotHeading("Время")
            PolyglotGridTable(rows: [
                ["", "Когда", "Пример"],
                ["in", "через срок; месяц, время года", "in two weeks, in June, in winter"],
                ["ago", "назад — после срока", "three days ago"],
                ["on", "день недели", "on Monday"],
                ["at", "час", "at five o'clock"],
                ["—", "next, last, this, tomorrow, yesterday", "next week, last year"],
            ], firstColumnWidth: 52)
        }
    }
}
