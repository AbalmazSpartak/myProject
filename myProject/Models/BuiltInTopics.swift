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

    static let all: [Topic] = [tenses, irregularVerbs, articles, movieQuotes, airport, cafe, vowelReading]

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
}
