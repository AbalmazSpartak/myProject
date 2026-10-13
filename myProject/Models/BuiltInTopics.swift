import Foundation
import SwiftData

/// Темы «Сообщества», которые идут вместе с приложением: появляются при первом запуске, возвращаются после
/// переустановки и обновляются с новой версией. Только для чтения (isMine = false) — свои темы пользователя не трогаются
enum BuiltInTopics {
    struct Topic {
        let number: Int
        let section: String
        let title: String
        let blocks: [TopicBlock]
        let words: [(String, String)]
    }

    /// Добавляет недостающие, обновляет изменённые, убирает встроенные темы, которых больше нет в списке.
    /// «В мои подборки» (savedAt) при обновлении сохраняется
    static func sync(context: ModelContext) {
        let existing = ((try? context.fetch(FetchDescriptor<CommunityTopic>())) ?? []).filter { !$0.isMine }
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for topic in all {
            let id = uuid(topic: topic.number)
            let words = topic.words.enumerated().map { index, pair in
                TopicWord(id: uuid(topic: topic.number, item: 500 + index), english: pair.0, russian: pair.1)
            }
            if let stored = byID.removeValue(forKey: id) {
                guard stored.section != topic.section || stored.title != topic.title
                        || stored.blocks != topic.blocks || stored.words != words else { continue }
                stored.section = topic.section
                stored.title = topic.title
                stored.words = words
                stored.setBlocks(topic.blocks)
            } else {
                let created = CommunityTopic(section: topic.section, title: topic.title, blocks: topic.blocks, words: words)
                created.id = id
                created.isMine = false
                // Встроенные — в конце ленты, в порядке списка: «новее» идут выше
                created.createdAt = Date(timeIntervalSince1970: 1_700_000_000 - Double(topic.number) * 60)
                context.insert(created)
            }
        }
        for removed in byID.values { context.delete(removed) }
        try? context.save()
    }

    // MARK: - Сборка блоков

    /// Постоянные номера: тема B1A70000-00TT-…, её блоки и слова — по номеру внутри темы
    private static func uuid(topic: Int, item: Int = 0) -> UUID {
        UUID(uuidString: String(format: "B1A70000-%04X-4000-8000-%012X", topic, item))!
    }

    /// Блоки темы с постоянными id — иначе каждое сравнение видело бы «изменения»
    private static func blocks(_ topic: Int, _ items: [TopicBlock]) -> [TopicBlock] {
        items.enumerated().map { index, block in
            var block = block
            block.id = uuid(topic: topic, item: index + 1)
            return block
        }
    }

    private static func heading(_ text: String) -> TopicBlock {
        var block = TopicBlock(kind: .heading)
        block.text = text
        return block
    }

    private static func text(_ text: String) -> TopicBlock {
        var block = TopicBlock(kind: .text)
        block.text = text
        return block
    }

    /// Первая строка — шапка; labels — первый столбец тоже шапка (подписи строк)
    /// highlighted — строки, выделенные цветом целиком (кроме подписи слева): например, транскрипция над примерами
    private static func table(_ rows: [[String]], labels: Bool = false, highlighted: Set<Int> = []) -> TopicBlock {
        var block = TopicBlock(kind: .table)
        var table = TopicTable()
        table.cells = rows
        table.hasHeaderRow = true
        table.hasHeaderColumn = labels
        for row in highlighted {
            for column in (labels ? 1 : 0)..<(rows.first?.count ?? 0) {
                var style = table.style(row: row, column: column)
                style.tone = .red
                table.setStyle(style, row: row, column: column)
            }
        }
        block.table = table
        return block
    }

    /// Видео по ссылке (YouTube — плеер прямо в теме); подпись — под плеером
    private static func video(_ url: String, caption: String) -> TopicBlock {
        var block = TopicBlock(kind: .video)
        block.videoURL = url
        block.text = caption
        return block
    }

    /// Карточка тренировки: открывает упражнение по его id
    private static func exercise(_ id: String, title: String) -> TopicBlock {
        var block = TopicBlock(kind: .exercise)
        block.exerciseID = id
        block.text = title
        return block
    }

    /// Озвучка английской фразы; подпись — что звучит
    private static func speech(_ english: String, caption: String) -> TopicBlock {
        var block = TopicBlock(kind: .audio)
        block.audioSource = .speech
        block.speechText = english
        block.text = caption
        return block
    }

    // MARK: - Темы

    static let grammarSection = "Грамматика"

    /// «10 знаменитых фраз из фильмов» — плитка в ленте «Английский по кино»
    static let movieQuotesID = uuid(topic: 4)
    /// Плитки лент: «Фэнтези» у кино, «Слова о музыке» и «Gonna, wanna» у музыки
    static let fantasyID = uuid(topic: 18)
    static let musicWordsID = uuid(topic: 20)
    static let songSlangID = uuid(topic: 21)

    static let all: [Topic] = [tenses, irregularVerbs, articles, movieQuotes, airport, cafe, vowelReading,
                               hotel, doctor, shopping, city, timePrepositions, quantifiers, comparatives,
                               thSound, minimalPairs, silentLetters, fantasyPhrases, seriesPhrases, musicWords, songSlang,
                               idioms, textingSlang]

    static let pronunciationSection = "Произношение"

    private static let tenses = Topic(
        number: 1,
        section: grammarSection,
        title: "Времена глагола: вся система",
        blocks: blocks(1, [
            text("В английском три времени — прошедшее, настоящее и будущее — и четыре вида: Simple, Continuous, Perfect и Perfect Continuous. Вместе получается 12 форм. Ниже — все они на примере I + work."),
            heading("Past — прошедшее"),
            table([
                ["Вид", "Форма"],
                ["Simple", "worked"],
                ["Continuous", "was working"],
                ["Perfect", "had worked"],
                ["Perfect\nContinuous", "had been working"],
            ], labels: true),
            heading("Present — настоящее"),
            table([
                ["Вид", "Форма"],
                ["Simple", "work"],
                ["Continuous", "am working"],
                ["Perfect", "have worked"],
                ["Perfect\nContinuous", "have been working"],
            ], labels: true),
            heading("Future — будущее"),
            table([
                ["Вид", "Форма"],
                ["Simple", "will work"],
                ["Continuous", "will be working"],
                ["Perfect", "will have worked"],
                ["Perfect\nContinuous", "will have been working"],
            ], labels: true),
            heading("Что значит каждый вид"),
            table([
                ["Вид", "Значение и пример"],
                ["Simple", "Факт, привычка, расписание\n*She works in a bank.*"],
                ["Continuous", "Действие в процессе\n*She is working now.*"],
                ["Perfect", "Результат к какому-то моменту\n*She has finished the report.*"],
                ["Perfect\nContinuous", "Как долго длится действие\n*She has been working here for five years.*"],
            ], labels: true),
            speech("She has been working here for five years.", caption: "Present Perfect Continuous"),
        ]),
        words: [("habit", "привычка"), ("schedule", "расписание"), ("result", "результат")]
    )

    private static let irregularVerbs = Topic(
        number: 2,
        section: grammarSection,
        title: "Неправильные глаголы: 28 самых частых",
        blocks: blocks(2, [
            text("У неправильных глаголов прошедшее время и причастие образуются не через -ed, их нужно запомнить. Вторая форма (V2, Past Simple) — для прошедшего времени: I went. Третья (V3, Past Participle) — для времён Perfect и пассива: I have gone, it was written."),
            heading("Часть 1"),
            table([
                ["Глагол", "V2", "V3"],
                ["be\nбыть", "was / were", "been"],
                ["have\nиметь", "had", "had"],
                ["do\nделать", "did", "done"],
                ["say\nсказать", "said", "said"],
                ["go\nидти, ехать", "went", "gone"],
                ["get\nполучать", "got", "gotten"],
                ["make\nделать, создавать", "made", "made"],
                ["know\nзнать", "knew", "known"],
                ["think\nдумать", "thought", "thought"],
                ["take\nбрать", "took", "taken"],
                ["see\nвидеть", "saw", "seen"],
                ["come\nприходить", "came", "come"],
                ["give\nдавать", "gave", "given"],
                ["find\nнаходить", "found", "found"],
            ]),
            heading("Часть 2"),
            table([
                ["Глагол", "V2", "V3"],
                ["tell\nрассказывать", "told", "told"],
                ["feel\nчувствовать", "felt", "felt"],
                ["become\nстановиться", "became", "become"],
                ["leave\nуходить, оставлять", "left", "left"],
                ["put\nкласть", "put", "put"],
                ["bring\nприносить", "brought", "brought"],
                ["begin\nначинать", "began", "begun"],
                ["keep\nхранить, держать", "kept", "kept"],
                ["write\nписать", "wrote", "written"],
                ["stand\nстоять", "stood", "stood"],
                ["hear\nслышать", "heard", "heard"],
                ["let\nпозволять", "let", "let"],
                ["mean\nзначить", "meant", "meant"],
                ["meet\nвстречать", "met", "met"],
            ]),
            text("В американском английском у get третья форма — gotten (I have gotten), в британском — got."),
        ]),
        words: [
            ("be", "быть"), ("have", "иметь"), ("do", "делать"), ("say", "сказать"), ("go", "идти"),
            ("get", "получать"), ("make", "делать"), ("know", "знать"), ("think", "думать"), ("take", "брать"),
            ("see", "видеть"), ("come", "приходить"), ("give", "давать"), ("find", "находить"),
            ("tell", "рассказывать"), ("feel", "чувствовать"), ("become", "становиться"), ("leave", "уходить"),
            ("put", "класть"), ("bring", "приносить"), ("begin", "начинать"), ("keep", "хранить"),
            ("write", "писать"), ("stand", "стоять"), ("hear", "слышать"), ("let", "позволять"),
            ("mean", "значить"), ("meet", "встречать"),
        ]
    )

    private static let articles = Topic(
        number: 3,
        section: grammarSection,
        title: "Артикли a, an, the",
        blocks: blocks(3, [
            text("Артикль показывает, о каком предмете речь: об одном из многих (a, an) или о конкретном, уже знакомом (the). A или an выбирают по первому звуку следующего слова, а не по букве."),
            table([
                ["Артикль", "Когда и пример"],
                ["a", "Один из многих, перед согласным звуком\n*a book, a university*"],
                ["an", "Один из многих, перед гласным звуком\n*an apple, an hour*"],
                ["the", "Конкретный, уже упомянутый или единственный\n*the sun, the book on the table*"],
                ["—", "Множественное или неисчисляемое в общем смысле\n*Cats like milk.*"],
            ], labels: true),
            heading("Сравните"),
            speech("I saw a dog. The dog was very big.", caption: "Сначала a — «какая-то собака», потом the — «та самая»"),
        ]),
        words: [("article", "артикль"), ("countable", "исчисляемый"), ("uncountable", "неисчисляемый")]
    )

    private static let movieQuotes = Topic(
        number: 4,
        section: "Английский по кино",
        title: "10 знаменитых фраз из фильмов",
        blocks: blocks(4, [
            text("Фразы, которые знают даже те, кто не видел фильм. Короткие, живые и хорошо запоминаются. Курсивом — название фильма."),
            table([
                ["Фраза и перевод"],
                ["**May the Force be with you.**\nДа пребудет с тобой Сила. *Star Wars*"],
                ["**I'll be back.**\nЯ вернусь. *The Terminator*"],
                ["**Houston, we have a problem.**\nХьюстон, у нас проблема. *Apollo 13*"],
                ["**There's no place like home.**\nНет места лучше дома. *The Wizard of Oz*"],
                ["**To infinity and beyond!**\nВ бесконечность и дальше! *Toy Story*"],
                ["**Why so serious?**\nПочему такой серьёзный? *The Dark Knight*"],
                ["**Just keep swimming.**\nПросто продолжай плыть. *Finding Nemo*"],
                ["**Life is like a box of chocolates.**\nЖизнь как коробка шоколадных конфет. *Forrest Gump*"],
                ["**You're gonna need a bigger boat.**\nНам понадобится лодка побольше. *Jaws*"],
                ["**I'm the king of the world!**\nЯ король мира! *Titanic*"],
            ]),
            heading("Послушайте"),
            speech("Houston, we have a problem.", caption: "Apollo 13"),
            speech("Life is like a box of chocolates.", caption: "Forrest Gump"),
            speech("You're gonna need a bigger boat.", caption: "Jaws"),
            text("Gonna — разговорное going to: «собираться». В речи звучит постоянно, на письме — только в неформальном тексте."),
        ]),
        words: [
            ("force", "сила"), ("infinity", "бесконечность"), ("beyond", "за пределами"),
            ("serious", "серьёзный"), ("swim", "плавать"), ("box", "коробка"),
        ]
    )

    private static let airport = Topic(
        number: 5,
        section: "Подборки слов",
        title: "В аэропорту",
        blocks: blocks(5, [
            text("Слова и фразы, которые пригодятся от регистрации до выдачи багажа."),
            table([
                ["Фраза и перевод"],
                ["**Where is the check-in desk?**\nГде стойка регистрации?"],
                ["**I'd like a window seat, please.**\nЯ бы хотел место у окна."],
                ["**How many bags can I check?**\nСколько сумок можно сдать в багаж?"],
                ["**Is the flight on time?**\nРейс вылетает вовремя?"],
                ["**Which gate is it?**\nКакой выход на посадку?"],
                ["**Do I need to take off my shoes?**\nНужно снять обувь?"],
                ["**My luggage is lost.**\nМой багаж потерялся."],
            ]),
            heading("Послушайте"),
            speech("I'd like a window seat, please.", caption: "Место у окна"),
            speech("Which gate is it?", caption: "Выход на посадку"),
        ]),
        words: [
            ("boarding pass", "посадочный талон"), ("gate", "выход на посадку"), ("luggage", "багаж"),
            ("departure", "вылет"), ("arrival", "прибытие"), ("delay", "задержка"),
            ("customs", "таможня"), ("aisle seat", "место у прохода"),
        ]
    )

    private static let cafe = Topic(
        number: 6,
        section: "Подборки слов",
        title: "В кафе и ресторане",
        blocks: blocks(6, [
            text("Как заказать столик и еду, спросить совета и попросить счёт."),
            table([
                ["Фраза и перевод"],
                ["**A table for two, please.**\nСтолик на двоих, пожалуйста."],
                ["**Can I see the menu, please?**\nМожно меню?"],
                ["**What do you recommend?**\nЧто вы посоветуете?"],
                ["**I'll have the soup, please.**\nМне суп, пожалуйста."],
                ["**Could I have the check, please?**\nМожно счёт?"],
                ["**Is service included?**\nОбслуживание включено в счёт?"],
                ["**Can I pay by card?**\nМожно оплатить картой?"],
            ]),
            text("В США счёт в ресторане — check, в Великобритании — bill. Чаевые в США обычно 15–20%."),
            speech("Could I have the check, please?", caption: "Попросить счёт"),
        ]),
        words: [
            ("menu", "меню"), ("waiter", "официант"), ("check", "счёт"), ("tip", "чаевые"),
            ("order", "заказывать"), ("dessert", "десерт"), ("reservation", "бронь"),
        ]
    )

    private static let vowelReading = Topic(
        number: 7,
        section: pronunciationSection,
        title: "Как читаются гласные: четыре типа слога",
        blocks: blocks(7, [
            video("https://youtu.be/hzF_iJ5g2gY", caption: "Видео-урок: правила чтения гласных и согласных"),
            text("Одна и та же гласная буква в английском читается по-разному. Как именно — подсказывает слог, в котором она стоит. Типов слога четыре, и у каждой гласной в каждом типе — свой звук."),
            heading("1. Открытый слог"),
            text("Слог заканчивается на гласную (me, we, fly) или после одной согласной идёт немая e на конце (name, hope, cute). Гласная читается так, как называется в алфавите: a — [ei], o — [əʊ], u — [ju:], e — [i:], i и y — [ai]."),
            heading("2. Закрытый слог"),
            text("Слог заканчивается на согласную: cat, hot, cup, met, kit. Гласная звучит коротко: [æ], [ɔ], [ʌ], [e], [i]."),
            heading("3. Гласная + r"),
            text("Буква r после гласной в британском варианте не читается, а гласная становится долгой: car [a:], for [ɔ:]. Сочетания er, ir, ur и yr звучат одинаково — [ɜ:]: verb, girl, hurt. В американском варианте r произносится: car [kɑːr]."),
            heading("4. Гласная + re"),
            text("После r идёт ещё гласная, обычно немая e: hare, here, fire, cure. Получается звук с призвуком [ə] на конце: [ɛə], [ɪə], [aiə], [jʊə]. У o звук тот же, что перед r, — [ɔ:]: more."),
            heading("Таблица: a, o, u"),
            text("Откр. — открытый слог, закр. — закрытый, +r и +re — гласная перед r и перед re."),
            table([
                ["", "Откр.", "Закр.", "+r", "+re"],
                ["a", "[ei]", "[æ]", "[a:]", "[ɛə]"],
                ["", "name", "cat", "car", "hare"],
                ["", "take", "fat", "far", "care"],
                ["", "baby", "rat", "dark", "dare"],
                ["o", "[əʊ]", "[ɔ]", "[ɔ:]", "[ɔ:]"],
                ["", "hope", "hot", "for", "more"],
                ["", "Rome", "dog", "sport", "before"],
                ["", "home", "stop", "horse", "score"],
                ["u", "[ju:]", "[ʌ]", "[ɜ:]", "[jʊə]"],
                ["", "cute", "cup", "turkey", "cure"],
                ["", "computer", "bus", "hurt", "endure"],
                ["", "cube", "lunch", "lurk", "pure"],
            ], labels: true, highlighted: [1, 5, 9]),
            heading("Таблица: e, i, y"),
            table([
                ["", "Откр.", "Закр.", "+r", "+re"],
                ["e", "[i:]", "[e]", "[ɜ:]", "[ɪə]"],
                ["", "me", "met", "German", "here"],
                ["", "theme", "pet", "perfume", "mere"],
                ["", "we", "let", "verb", "sphere"],
                ["i", "[ai]", "[i]", "[ɜ:]", "[aiə]"],
                ["", "wife", "kit", "girl", "fire"],
                ["", "bike", "lit", "bird", "tired"],
                ["", "kite", "fit", "", ""],
                ["y", "[ai]", "[i]", "[ɜ:] или\n[ə:]", "[aiə]"],
                ["", "fly", "typical", "Myrtle", "tyre"],
                ["", "why", "system", "", ""],
            ], labels: true, highlighted: [1, 5, 9]),
            exercise(VowelReading.exerciseID, title: "Тренировка: как читается?"),
            heading("Немая e меняет звук"),
            text("Добавьте e на конце — и закрытый слог становится открытым: hat → hate, kit → kite, hop → hope, cub → cube, pet → Pete."),
            speech("hat, hate. kit, kite. hop, hope. cub, cube.", caption: "Закрытый и открытый слог"),
            heading("Послушайте по строкам"),
            speech("name, cat, car, hare", caption: "a: [ei] — [æ] — [a:] — [ɛə]"),
            speech("hope, hot, for, more", caption: "o: [əʊ] — [ɔ] — [ɔ:] — [ɔ:]"),
            speech("cute, cup, hurt, cure", caption: "u: [ju:] — [ʌ] — [ɜ:] — [jʊə]"),
            speech("me, met, verb, here", caption: "e: [i:] — [e] — [ɜ:] — [ɪə]"),
            speech("bike, kit, girl, fire", caption: "i: [ai] — [i] — [ɜ:] — [aiə]"),
            speech("fly, system, Myrtle, tyre", caption: "y: [ai] — [i] — [ɜ:] — [aiə]"),
            text("Правила работают в ударных слогах и знают много исключений — например, have, give, love, come читаются как в закрытом слоге. Но для большинства слов таблица подсказывает чтение верно."),
        ]),
        words: [
            ("name", "имя"), ("cat", "кошка"), ("car", "машина"), ("hope", "надеяться"), ("hot", "горячий"),
            ("cup", "чашка"), ("cute", "милый"), ("here", "здесь"), ("bike", "велосипед"), ("bird", "птица"),
            ("fly", "летать"), ("fire", "огонь"),
        ]
    )

    // MARK: - Подборки слов

    private static let hotel = Topic(
        number: 8,
        section: "Подборки слов",
        title: "В отеле",
        blocks: blocks(8, [
            text("От бронирования до выезда: как заселиться, попросить что-нибудь в номер и решить проблему."),
            table([
                ["Фраза и перевод"],
                ["**I have a reservation under the name Ivanov.**\nУ меня бронь на имя Иванов."],
                ["**What time is check-out?**\nДо скольких нужно выехать?"],
                ["**Is breakfast included?**\nЗавтрак включён?"],
                ["**Could I have an extra towel, please?**\nМожно ещё одно полотенце?"],
                ["**The air conditioning doesn't work.**\nНе работает кондиционер."],
                ["**What's the Wi-Fi password?**\nКакой пароль от вайфая?"],
                ["**Can I leave my luggage here?**\nМожно оставить у вас багаж?"],
                ["**I'd like to check out, please.**\nЯ хотел бы выехать."],
            ]),
            text("Check in — заселиться, check out — выехать. Reception — стойка администратора; там же говорят front desk."),
            speech("I have a reservation under the name Ivanov.", caption: "Заселение"),
            speech("Could I have an extra towel, please?", caption: "Просьба в номер"),
        ]),
        words: [
            ("reservation", "бронирование"), ("reception", "стойка администратора"), ("towel", "полотенце"),
            ("key", "ключ"), ("floor", "этаж"), ("single room", "одноместный номер"), ("double room", "двухместный номер"),
        ]
    )

    private static let doctor = Topic(
        number: 9,
        section: "Подборки слов",
        title: "У врача и в аптеке",
        blocks: blocks(9, [
            text("Как описать, что болит, и купить лекарство. В экстренной ситуации в США звонят 911, в Великобритании — 999, в Европе — 112."),
            table([
                ["Фраза и перевод"],
                ["**I don't feel well.**\nМне нехорошо."],
                ["**I have a headache.**\nУ меня болит голова."],
                ["**I have a sore throat.**\nУ меня болит горло."],
                ["**I have a fever.**\nУ меня температура."],
                ["**It hurts here.**\nБолит вот здесь."],
                ["**I'm allergic to penicillin.**\nУ меня аллергия на пенициллин."],
                ["**Do I need a prescription?**\nНужен рецепт?"],
                ["**How often should I take it?**\nКак часто это принимать?"],
            ]),
            heading("Что болит: -ache"),
            text("headache — голова, toothache — зуб, stomachache — живот, backache — спина. Остальное — через hurt: My knee hurts — болит колено."),
            speech("I have a headache and a sore throat.", caption: "Голова и горло"),
        ]),
        words: [
            ("headache", "головная боль"), ("fever", "жар"), ("cough", "кашель"), ("pill", "таблетка"),
            ("prescription", "рецепт (врача)"), ("pharmacy", "аптека"), ("hurt", "болеть"), ("medicine", "лекарство"),
        ]
    )

    private static let shopping = Topic(
        number: 10,
        section: "Подборки слов",
        title: "Покупки и одежда",
        blocks: blocks(10, [
            text("Спросить размер, примерить, узнать цену и вернуть покупку."),
            table([
                ["Фраза и перевод"],
                ["**I'm just looking, thanks.**\nЯ просто смотрю, спасибо."],
                ["**Do you have this in a medium?**\nЕсть такое размера M?"],
                ["**Can I try it on?**\nМожно примерить?"],
                ["**Where are the fitting rooms?**\nГде примерочные?"],
                ["**It's too small. Do you have a bigger size?**\nМаловато. Есть размер побольше?"],
                ["**How much is it?**\nСколько стоит?"],
                ["**Is it on sale?**\nНа это есть скидка?"],
                ["**I'd like to return this.**\nЯ хочу это вернуть."],
            ]),
            text("Размеры одежды: small (S), medium (M), large (L). Обувь в США и Великобритании меряют своими номерами — например, русский 42 — это примерно US 9 и UK 8."),
            speech("Can I try it on?", caption: "Примерить"),
        ]),
        words: [
            ("size", "размер"), ("shirt", "рубашка"), ("dress", "платье"), ("shoes", "обувь"),
            ("jacket", "куртка"), ("price", "цена"), ("receipt", "чек"), ("discount", "скидка"),
        ]
    )

    private static let city = Topic(
        number: 11,
        section: "Подборки слов",
        title: "Транспорт и город",
        blocks: blocks(11, [
            text("Как спросить дорогу, купить билет и не уехать не туда."),
            table([
                ["Фраза и перевод"],
                ["**Excuse me, how do I get to the station?**\nИзвините, как пройти к вокзалу?"],
                ["**Is it far from here?**\nЭто далеко отсюда?"],
                ["**Go straight and turn left.**\nИдите прямо и поверните налево."],
                ["**Which bus goes to the city centre?**\nКакой автобус идёт в центр?"],
                ["**A return ticket, please.**\nБилет туда и обратно, пожалуйста."],
                ["**Where do I change trains?**\nГде пересадка?"],
                ["**Could you call me a taxi?**\nВызовите мне такси, пожалуйста."],
                ["**Is this seat free?**\nЭто место свободно?"],
            ]),
            text("В Лондоне метро — the Underground или the Tube, в Нью-Йорке — the subway. Билет в одну сторону: в Британии single, в США one-way."),
            speech("Excuse me, how do I get to the station?", caption: "Спросить дорогу"),
        ]),
        words: [
            ("ticket", "билет"), ("station", "вокзал"), ("bus stop", "остановка"), ("straight", "прямо"),
            ("turn", "поворачивать"), ("map", "карта"), ("traffic", "дорожное движение"), ("crossroads", "перекрёсток"),
        ]
    )

    // MARK: - Грамматика

    private static let timePrepositions = Topic(
        number: 12,
        section: grammarSection,
        title: "Предлоги времени: in, on, at",
        blocks: blocks(12, [
            text("Три предлога на все случаи: чем короче и точнее время, тем «острее» предлог. **in** — большие отрезки, **on** — дни, **at** — точка на часах."),
            table([
                ["Предлог", "Когда и пример"],
                ["in", "Месяцы, годы, века, времена года, части суток\n*in May, in 2020, in summer, in the morning*"],
                ["on", "Дни недели и даты\n*on Monday, on the 5th of June, on my birthday*"],
                ["at", "Точное время и праздники-моменты\n*at 7 o'clock, at noon, at night, at the weekend*"],
            ], labels: true),
            heading("Без предлога"),
            text("Перед this, next, last, every, tomorrow, yesterday предлог не нужен: *next Friday*, *last year*, *every morning*."),
            speech("I get up at seven in the morning on weekdays.", caption: "Все три предлога в одной фразе"),
            text("*at the weekend* — по-британски; американцы говорят *on the weekend*."),
        ]),
        words: [("weekday", "будний день"), ("noon", "полдень"), ("century", "век")]
    )

    private static let quantifiers = Topic(
        number: 13,
        section: grammarSection,
        title: "Some, any, much, many",
        blocks: blocks(13, [
            text("Сначала решите: предмет можно посчитать (apples, chairs) или нет (milk, money, time)? От этого зависит, какое слово выбрать."),
            table([
                ["Слово", "Когда и пример"],
                ["some", "В утверждении — «немного, несколько»\n*I have some apples. There's some milk.*"],
                ["any", "В вопросе и отрицании\n*Do you have any money? I don't have any time.*"],
                ["many", "Много — с тем, что считают\n*How many friends? Not many people.*"],
                ["much", "Много — с тем, что не считают\n*How much water? Not much time.*"],
                ["a lot of", "Много — и с тем, и с другим, в утверждении\n*a lot of books, a lot of fun*"],
            ], labels: true),
            heading("Исключение для some"),
            text("В просьбах и предложениях some остаётся и в вопросе: *Would you like some tea? Can I have some water?*"),
            speech("How much does it cost? How many do you need?", caption: "Сколько стоит? Сколько нужно?"),
        ]),
        words: [("countable", "исчисляемый"), ("uncountable", "неисчисляемый"), ("amount", "количество")]
    )

    private static let comparatives = Topic(
        number: 14,
        section: grammarSection,
        title: "Сравнение: bigger, the biggest",
        blocks: blocks(14, [
            text("Короткие прилагательные получают -er и -est, длинные — more и most. Неправильных всего несколько — их стоит выучить."),
            table([
                ["Правило", "Пример"],
                ["Короткое: -er, the -est", "cheap — cheaper — the cheapest"],
                ["Гласная + согласная: удвоение", "big — bigger — the biggest"],
                ["На -y: -ier, -iest", "easy — easier — the easiest"],
                ["Длинное: more, the most", "expensive — more expensive — the most expensive"],
            ]),
            heading("Неправильные"),
            table([
                ["Слово", "Сравнение", "Превосходная"],
                ["good", "better", "the best"],
                ["bad", "worse", "the worst"],
                ["far", "farther", "the farthest"],
                ["many / much", "more", "the most"],
                ["little", "less", "the least"],
            ]),
            text("«Чем» — **than**: *My brother is taller than me.* «Такой же, как» — **as … as**: *She is as tall as her mother.*"),
            speech("This is the best day of my life.", caption: "Лучший день в моей жизни"),
        ]),
        words: [("cheap", "дешёвый"), ("expensive", "дорогой"), ("easy", "лёгкий"), ("tall", "высокий"), ("than", "чем")]
    )

    // MARK: - Произношение

    private static let thSound = Topic(
        number: 15,
        section: pronunciationSection,
        title: "Звук th",
        blocks: blocks(15, [
            text("В русском такого звука нет, поэтому вместо th часто говорят «с», «з» или «ф». Секрет простой: кончик языка — между зубами, и дуть сквозь щель."),
            table([
                ["Звук", "Как и примеры"],
                ["[θ]", "Глухой: язык между зубами, без голоса\n*think, three, thank, month, birthday*"],
                ["[ð]", "Звонкий: то же, но с голосом\n*this, that, mother, weather, they*"],
            ], labels: true),
            heading("Не перепутайте"),
            table([
                ["С th", "Без th"],
                ["think — думать", "sink — раковина"],
                ["three — три", "tree — дерево"],
                ["thank — благодарить", "tank — бак, танк"],
                ["they — они", "day — день"],
            ]),
            speech("think, sink. three, tree. thank, tank.", caption: "Глухой th и похожие слова"),
            speech("this, that, mother, weather.", caption: "Звонкий th"),
            speech("Thank you for the three things you brought.", caption: "Скороговорка"),
        ]),
        words: [("think", "думать"), ("three", "три"), ("thank", "благодарить"), ("weather", "погода"), ("month", "месяц")]
    )

    private static let minimalPairs = Topic(
        number: 16,
        section: pronunciationSection,
        title: "Ship или sheep: долгие и краткие звуки",
        blocks: blocks(16, [
            text("В английском длина гласного меняет смысл. Краткий звук — коротко и расслабленно, долгий — тянем, губы напряжены. Двоеточие в транскрипции [i:] и значит «долгий»."),
            table([
                ["Краткий", "Долгий"],
                ["ship [ʃɪp] — корабль", "sheep [ʃi:p] — овца"],
                ["live [lɪv] — жить", "leave [li:v] — уходить"],
                ["full [fʊl] — полный", "fool [fu:l] — дурак"],
                ["pull [pʊl] — тянуть", "pool [pu:l] — бассейн"],
                ["cot [kɒt] — детская кроватка", "caught [kɔ:t] — поймал"],
            ]),
            speech("ship, sheep. live, leave. full, fool.", caption: "Краткий и долгий"),
            text("Ещё одна важная пара — [e] и [æ]: bed — кровать, bad — плохой; men — мужчины, man — мужчина. Для [æ] рот открыт шире, почти как для «а»."),
            speech("bed, bad. men, man.", caption: "[e] и [æ]"),
        ]),
        words: [("ship", "корабль"), ("sheep", "овца"), ("leave", "уходить"), ("pool", "бассейн"), ("bad", "плохой")]
    )

    private static let silentLetters = Topic(
        number: 17,
        section: pronunciationSection,
        title: "Немые буквы",
        blocks: blocks(17, [
            text("Пишется, но не читается: в старом английском эти буквы звучали, а написание осталось. Запомните несколько частых сочетаний — и большая часть слов станет понятной."),
            table([
                ["Буква", "Когда молчит и пример"],
                ["k", "kn- в начале\n*know, knife, knee, knock*"],
                ["w", "wr- в начале и в who, whole\n*write, wrong, answer*"],
                ["b", "после m в конце\n*climb, comb, lamb, thumb*"],
                ["h", "в начале нескольких слов\n*hour, honest, honour*"],
                ["l", "в -alk, -ould и некоторых других\n*walk, talk, could, should, half*"],
                ["gh", "часто в середине и конце\n*night, light, daughter, though*"],
            ], labels: true),
            text("Из-за немой h говорят **an** hour и **an** honest man: слово начинается с гласного звука."),
            speech("know, write, climb, hour, walk, night.", caption: "Немые буквы"),
        ]),
        words: [("knife", "нож"), ("knee", "колено"), ("climb", "карабкаться"), ("honest", "честный"), ("daughter", "дочь")]
    )

    // MARK: - Кино

    private static let fantasyPhrases = Topic(
        number: 18,
        section: "Английский по кино",
        title: "Фэнтези: короткие фразы из фильмов",
        blocks: blocks(18, [
            text("Короткие реплики из фэнтези-фильмов, которые давно живут своей жизнью. Курсивом — фильм."),
            table([
                ["Фраза и перевод"],
                ["**You shall not pass!**\nТы не пройдёшь! *The Lord of the Rings*"],
                ["**One does not simply walk into Mordor.**\nНельзя просто так взять и войти в Мордор. *The Lord of the Rings*"],
                ["**After all this time? Always.**\nСпустя столько времени? Всегда. *Harry Potter*"],
                ["**Winter is coming.**\nЗима близко. *Game of Thrones*"],
                ["**I am Groot.**\nЯ есть Грут. *Guardians of the Galaxy*"],
                ["**Hakuna matata.**\nАкуна матата — «нет проблем» на суахили. *The Lion King*"],
            ]),
            text("**shall** — старинное «будет, должен»: в фэнтези звучит торжественно. В обычной речи вместо него — will или must."),
            speech("You shall not pass!", caption: "The Lord of the Rings"),
            speech("Winter is coming.", caption: "Game of Thrones"),
        ]),
        words: [("pass", "проходить"), ("simply", "просто"), ("always", "всегда"), ("winter", "зима")]
    )

    private static let seriesPhrases = Topic(
        number: 19,
        section: "Английский по кино",
        title: "Как говорят в сериалах",
        blocks: blocks(19, [
            text("Разговорные выражения, которые слышишь в каждом сериале, но редко встречаешь в учебниках."),
            table([
                ["Фраза и перевод"],
                ["**What's up?**\nКак дела? Что нового?"],
                ["**No way!**\nДа ладно! Не может быть! / Ни за что!"],
                ["**I'm on it.**\nУже занимаюсь. Сделаю."],
                ["**Fair enough.**\nСправедливо. Резонно."],
                ["**My bad.**\nМоя ошибка. Виноват."],
                ["**Hang on a sec.**\nПодожди секунду."],
                ["**You got this.**\nУ тебя получится."],
                ["**It's not a big deal.**\nНичего страшного."],
                ["**I'm good, thanks.**\nНе нужно, спасибо. — вежливый отказ"],
            ]),
            text("«I'm good» на вопрос «Хочешь чаю?» — это не «мне хорошо», а «нет, спасибо»."),
            speech("Hang on a sec. I'm on it.", caption: "Подожди секунду, уже делаю"),
        ]),
        words: [("deal", "дело, сделка"), ("fair", "справедливый"), ("enough", "достаточно")]
    )

    // MARK: - Музыка

    private static let musicWords = Topic(
        number: 20,
        section: "Английский по музыке",
        title: "Слова о музыке",
        blocks: blocks(20, [
            text("Чтобы рассказать о любимой группе, концерте или песне, которая не выходит из головы."),
            table([
                ["Фраза и перевод"],
                ["**What kind of music are you into?**\nКакую музыку ты любишь?"],
                ["**This song is stuck in my head.**\nЭта песня не выходит у меня из головы."],
                ["**They're going on tour next year.**\nВ следующем году они едут в тур."],
                ["**I can't carry a tune.**\nМне медведь на ухо наступил."],
                ["**Turn it up!**\nСделай погромче!"],
                ["**The lyrics are really deep.**\nУ песни очень глубокий текст."],
            ]),
            text("**lyrics** — текст песни, всегда во множественном числе. **Band** — группа, **singer** — певец, **gig** — небольшой концерт."),
            speech("This song is stuck in my head.", caption: "Песня застряла в голове"),
        ]),
        words: [
            ("song", "песня"), ("lyrics", "текст песни"), ("band", "музыкальная группа"), ("singer", "певец"),
            ("concert", "концерт"), ("album", "альбом"), ("tune", "мелодия"),
        ]
    )

    private static let songSlang = Topic(
        number: 21,
        section: "Английский по музыке",
        title: "Gonna, wanna, ain't: разговорное в песнях",
        blocks: blocks(21, [
            text("В песнях почти никогда не поют «going to» или «I am not» — поют так, как говорят. Вот самые частые сокращения: их полезно узнавать на слух, но в письме и на экзамене лучше полные формы."),
            table([
                ["Как поют", "Полная форма"],
                ["gonna", "going to — собираться"],
                ["wanna", "want to — хотеть"],
                ["gotta", "have got to — должен"],
                ["ain't", "am not / isn't / haven't"],
                ["'cause", "because — потому что"],
                ["ya", "you — ты"],
                ["lemme", "let me — дай мне"],
                ["kinda", "kind of — вроде, типа"],
            ]),
            speech("I'm gonna tell you. I wanna know. I gotta go.", caption: "Как это звучит"),
            text("Ain't — очень разговорное и грамматически «неправильное»: в песнях и кино встречается часто, но в обычной вежливой речи его избегают."),
        ]),
        words: [("because", "потому что"), ("kind of", "вроде, отчасти"), ("let me", "позволь мне")]
    )

    // MARK: - Идиомы и переписка

    private static let idioms = Topic(
        number: 22,
        section: "Идиомы",
        title: "Идиомы на каждый день",
        blocks: blocks(22, [
            text("Выражения, смысл которых не сложить из отдельных слов. Носители используют их постоянно — и в разговоре, и на работе."),
            table([
                ["Идиома и значение"],
                ["**It's a piece of cake.**\nПроще простого."],
                ["**Break a leg!**\nНи пуха ни пера! — пожелание удачи перед выступлением"],
                ["**I'm under the weather.**\nМне нездоровится."],
                ["**Let's call it a day.**\nНа сегодня хватит."],
                ["**It costs an arm and a leg.**\nСтоит бешеных денег."],
                ["**Once in a blue moon.**\nРаз в сто лет."],
                ["**Hit the books.**\nЗасесть за учебники."],
                ["**Spill the beans.**\nПроболтаться, выдать секрет."],
            ]),
            speech("Let's call it a day.", caption: "На сегодня хватит"),
            speech("It's a piece of cake.", caption: "Проще простого"),
        ]),
        words: [("piece", "кусок"), ("cake", "торт"), ("weather", "погода"), ("leg", "нога")]
    )

    private static let textingSlang = Topic(
        number: 23,
        section: "Сленг и переписка",
        title: "Сокращения в переписке",
        blocks: blocks(23, [
            text("В чатах и комментариях пишут коротко. Без этих сокращений половину сообщений не понять."),
            table([
                ["Сокращение", "Значение"],
                ["btw", "by the way — кстати"],
                ["idk", "I don't know — не знаю"],
                ["imo", "in my opinion — по-моему"],
                ["tbh", "to be honest — честно говоря"],
                ["lol", "laughing out loud — смеюсь"],
                ["brb", "be right back — скоро вернусь"],
                ["asap", "as soon as possible — как можно скорее"],
                ["ngl", "not gonna lie — не буду врать"],
                ["np", "no problem — не за что"],
                ["thx / ty", "thanks / thank you — спасибо"],
            ]),
            text("Asap уместно и в рабочей переписке, остальные — только с друзьями."),
        ]),
        words: [("opinion", "мнение"), ("honest", "честный"), ("possible", "возможный")]
    )
}
