import SwiftUI

/// Урок 7: повторение схемы глаголов на материале всех уроков и повелительное наклонение
struct PolyglotLesson7View: View {
    var body: some View {
        PolyglotLessonPage(number: 7, title: "Повторение и просьбы",
                           videoURL: URL(string: "https://www.youtube.com/watch?v=p3G-lpdNwrc"),
                           makeRound: { PolyglotLesson7.round() }) {
            PolyglotParagraph("Пора закрепить главное: схему глаголов из урока 1. Теперь в неё встают всё, что мы прошли, — местоимения, время, сравнения. А в конце — новое: как просить, запрещать и предлагать.")

            PolyglotTableView()

            PolyglotHeading("Будущее: will")
            PolyglotParagraph("Утверждение — **кто + will + глагол**, вопрос — **will** в начале, отрицание — **will not**.")
            PolyglotExamples(examples: [
                ("She will become a doctor in two years.", "Она станет врачом через два года."),
                ("He will live in Moscow next year.", "Он будет жить в Москве в следующем году."),
                ("I will be there in a few hours.", "Я буду там через несколько часов."),
                ("Will she be back home at five?", "Она вернётся домой в пять?"),
                ("Will you pay in cash or by card?", "Вы заплатите наличными или картой?"),
                ("When will she come to Moscow?", "Когда она приедет в Москву?"),
                ("How much will this cost?", "Сколько это будет стоить?"),
                ("I will not live here next month.", "Я не буду жить здесь в следующем месяце."),
                ("He will not go to school tomorrow.", "Он не пойдёт завтра в школу."),
            ])

            PolyglotHeading("Настоящее: do, does")
            PolyglotParagraph("Утверждение — глагол как есть, с he и she — **-s**. Вопрос — **do / does** в начале, отрицание — **don't / doesn't**.")
            PolyglotExamples(examples: [
                ("She looks older than him.", "Она выглядит старше, чем он."),
                ("He buys the most expensive flowers.", "Он покупает самые дорогие цветы."),
                ("We go home at ten o'clock.", "Мы идём домой в десять часов."),
                ("Do you like my clothes today?", "Тебе нравится моя одежда сегодня?"),
                ("Does he write texts in English?", "Он пишет тексты на английском?"),
                ("I don't want to eat now.", "Я не хочу есть сейчас."),
                ("She doesn't work on Saturday.", "Она не работает в субботу."),
            ])

            PolyglotHeading("Прошедшее: did")
            PolyglotParagraph("Утверждение — **-ed** или вторая форма неправильного глагола. Вопрос — **did** в начале, отрицание — **didn't**; после did глагол снова в первой форме.")
            PolyglotExamples(examples: [
                ("We paid cash on Wednesday.", "Мы заплатили наличными в среду."),
                ("He played tennis on Tuesday.", "Он играл в теннис во вторник."),
                ("They made a few mistakes.", "Они сделали несколько ошибок."),
                ("Did you talk to him on Monday?", "Ты говорил с ним в понедельник?"),
                ("Did you go somewhere last night?", "Ты ходил куда-нибудь вчера вечером?"),
                ("They didn't talk to him on Thursday.", "Они не говорили с ним в четверг."),
                ("He didn't change his passport last week.", "Он не менял паспорт на прошлой неделе."),
            ])

            PolyglotHeading("Просьбы и запреты")
            PolyglotParagraph("Просьба — глагол в самом начале, без you: **Help me!** Запрет — **don't** + глагол: **Don't call him!** Вежливо — с **please**: Please wait.")
            PolyglotExamples(examples: [
                ("Help me!", "Помоги мне!"),
                ("Call her tomorrow.", "Позвони ей завтра."),
                ("Come back in a week.", "Возвращайся через неделю."),
                ("Don't call him!", "Не звони ему!"),
                ("Don't worry.", "Не волнуйся."),
                ("Please wait.", "Пожалуйста, подождите."),
            ])

            PolyglotHeading("Let's — «давай(те)»")
            PolyglotParagraph("Предложить что-то сделать вместе — **let's** + глагол.")
            PolyglotExamples(examples: [
                ("Let's talk about your problem.", "Давай поговорим о твоей проблеме."),
                ("Let's go and see his house.", "Пойдём посмотрим его дом."),
                ("Let's get away from here, please.", "Давай уйдём отсюда, пожалуйста."),
            ])

            PolyglotParagraph("Повторяйте понемногу каждый день — так схемы становятся привычкой, и говорить становится легко.")
        } scheme: {
            VStack(alignment: .leading, spacing: 14) {
                PolyglotTableView()
                PolyglotHeading("Просьбы")
                PolyglotGridTable(rows: [
                    ["", "Как", "Пример"],
                    ["просьба", "глагол в начале", "Help me."],
                    ["запрет", "don't + глагол", "Don't call him."],
                    ["вежливо", "please + глагол", "Please wait."],
                    ["давай", "let's + глагол", "Let's talk."],
                ], firstColumnWidth: 84, fontSize: 14)
            }
        }
    }
}
