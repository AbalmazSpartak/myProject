import SwiftUI

/// Урок 6: much / many / a lot of, little / few, a little / a few и слова-параметры
struct PolyglotLesson6View: View {
    var body: some View {
        PolyglotLessonPage(number: 6, title: "Много, мало и слова-параметры",
                           videoURL: URL(string: "https://www.youtube.com/watch?v=eIB06Swazs0"),
                           makeRound: { PolyglotLesson6.round() }) {
            PolyglotParagraph("«Много» по-английски — **much** или **many**, «мало» — **little** или **few**. Выбор зависит от одного: можно ли это посчитать.")

            PolyglotHeading("Much и many")
            PolyglotParagraph("**Much** — с тем, что не посчитать (время, деньги, вода). **Many** — с тем, что считается (часы, рубли, литры).")
            PolyglotGridTable(rows: [
                ["much — не посчитать", "many — посчитать"],
                ["much time — много времени", "many hours — много часов"],
                ["much money — много денег", "many roubles — много рублей"],
                ["much water — много воды", "many liters — много литров"],
            ])
            PolyglotParagraph("**How much** и **how many** — «сколько».")
            PolyglotExamples(examples: [
                ("How much money do you have?", "Сколько у тебя денег?"),
                ("How many days do you need?", "Сколько дней тебе нужно?"),
                ("How much time is left?", "Сколько времени осталось?"),
                ("How many people work there?", "Сколько человек там работает?"),
            ])

            PolyglotHeading("A lot of — когда сомневаетесь")
            PolyglotParagraph("**A lot of** (и разговорное **plenty of** — «уйма») подходит к любым словам. В утверждениях обычно говорят именно так. В вопросах и отрицаниях привычнее much и many. После **too, very, so** — только much и many: too much, very many.")
            PolyglotParagraph("Осторожно: **advice** (совет), **news** (новости), **research** (исследование), **travel** (путешествия) по-английски не считаются — much advice, a lot of news.")
            PolyglotExamples(examples: [
                ("I have plenty of time.", "У меня уйма времени."),
                ("He knows a lot of doctors.", "Он знает много врачей."),
                ("Russia exports a lot of oil.", "Россия экспортирует много нефти."),
                ("They eat a lot of rice.", "Они едят много риса."),
            ])

            PolyglotHeading("Little и few")
            PolyglotParagraph("«Мало» — по тому же правилу: **little** — не посчитать, **few** — посчитать.")
            PolyglotGridTable(rows: [
                ["little — не посчитать", "few — посчитать"],
                ["little time — мало времени", "few days — мало дней"],
                ["little money — мало денег", "few dollars — мало долларов"],
                ["little milk — мало молока", "few bottles — мало бутылок"],
            ])
            PolyglotExamples(examples: [
                ("I have few English books.", "У меня мало книг на английском."),
                ("Few people think so.", "Мало кто так думает."),
                ("You have very little time.", "У тебя очень мало времени."),
                ("We have little money now.", "У нас сейчас мало денег."),
            ])

            PolyglotHeading("A few и a little — «немного»")
            PolyglotParagraph("С артиклем смысл меняется: **few / little** — «мало» (и это плохо), **a few / a little** — «несколько, немного» (и этого хватает). После **only** — только a few и a little: only a few days.")
            PolyglotExamples(examples: [
                ("I took a few books.", "Я взял несколько книг."),
                ("I took few books.", "Я взял мало книг."),
                ("A few people have two cars.", "У нескольких человек две машины."),
                ("Few people have two cars.", "Мало у кого две машины."),
                ("He gave a little money.", "Он дал немного денег."),
                ("He gave little money.", "Он дал мало денег."),
                ("They need little sugar.", "Им нужно мало сахара."),
            ])

            PolyglotHeading("Слова-параметры")
            PolyglotParagraph("Всё, часть, ничего — для людей, вещей, мест и времени:")
            PolyglotLesson6Reference()
            PolyglotExamples(examples: [
                ("Hello, everybody!", "Всем привет!"),
                ("I see somebody.", "Я кого-то вижу."),
                ("He saw nobody.", "Он никого не видел."),
                ("You always forget.", "Ты всегда забываешь."),
                ("I sometimes cook.", "Я иногда готовлю."),
                ("He never lies.", "Он никогда не врёт."),
                ("Did you like everything?", "Вам всё понравилось?"),
                ("We found something.", "Мы кое-что нашли."),
                ("I have nothing.", "У меня ничего нет."),
                ("She checked everywhere.", "Она проверила везде."),
                ("Take us somewhere.", "Отвези нас куда-нибудь."),
                ("He is nowhere to be found.", "Его нигде нет."),
            ])
        } scheme: {
            VStack(alignment: .leading, spacing: 14) {
                PolyglotHeading("Много и мало")
                PolyglotGridTable(rows: [
                    ["", "не посчитать", "посчитать"],
                    ["много", "much, a lot of", "many, a lot of"],
                    ["мало", "little", "few"],
                    ["немного", "a little", "a few"],
                ], firstColumnWidth: 90)
                PolyglotParagraph("В утверждении «много» — a lot of, в вопросе — much / many.")
                PolyglotHeading("Слова-параметры")
                PolyglotLesson6Reference()
            }
        }
    }
}

/// Таблица слов-параметров и правило одного отрицания — в уроке и в подсказке «Схема»
struct PolyglotLesson6Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotGridTable(rows: [
                ["", "всё", "часть", "ничего"],
                ["люди", "everybody\nвсе", "somebody\nкто-то", "nobody\nникто"],
                ["вещи", "everything\nвсё", "something\nчто-то", "nothing\nничего"],
                ["место", "everywhere\nвезде", "somewhere\nгде-то", "nowhere\nнигде"],
                ["время", "always\nвсегда", "sometimes\nиногда", "never\nникогда"],
            ], firstColumnWidth: 66, fontSize: 13)
            PolyglotParagraph("То же значение у **everyone, someone, no one**. **Anybody, anything, anywhere** — «кто / что / где угодно», в вопросах — «кто-нибудь»: Is anybody here?")
            PolyglotParagraph("Главное: в английском **одно отрицание**. По-русски «никогда **не** врёт», «**ничего не** вижу», по-английски — He **never** lies, I see **nothing**. Never, nobody, nothing уже отрицание — don't, doesn't, didn't с ними не нужны. Always, sometimes, never стоят перед глаголом: He **always** works.")
        }
    }
}
