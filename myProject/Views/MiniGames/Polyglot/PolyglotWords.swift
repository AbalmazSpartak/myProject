import Foundation

/// Растущий запас слов для «Грамматики за 8 шагов»: каждое слово появляется в своём уроке и дальше используется во всех следующих.
/// Слова — из базы приложения (words.csv, уровни A1–A2), но с готовыми русскими формами: упражнения собирают перевод
/// («она плавала», «позвоню ему»), а в базе только словарная форма
enum PolyglotWords {
    typealias Verb = PolyglotLesson2.Verb

    /// Глагол, урок, с которого он появляется, и как его можно использовать:
    /// object — естественно «вижу его / помогаю ему»; alone — звучит и без дополнения («Я плаваю», но не «Я приглашу»)
    private struct Entry {
        let verb: Verb
        let lesson: Int
        var object = false
        var alone = true
    }

    private static let registry: [Entry] = [
        // Урок 1: только подлежащее и глагол — «Она плавает», «Ты водишь?»
        Entry(verb: PolyglotLesson2.love, lesson: 1, object: true), Entry(verb: PolyglotLesson2.want, lesson: 1),
        Entry(verb: PolyglotLesson2.work, lesson: 1), Entry(verb: PolyglotLesson2.live, lesson: 1),
        Entry(verb: play, lesson: 1), Entry(verb: PolyglotLesson2.know, lesson: 1, object: true),
        Entry(verb: PolyglotLesson2.speak, lesson: 1), Entry(verb: PolyglotLesson2.help, lesson: 1, object: true),
        Entry(verb: PolyglotLesson6.cook, lesson: 1), Entry(verb: PolyglotLesson6.read, lesson: 1),
        Entry(verb: swim, lesson: 1), Entry(verb: sleep, lesson: 1), Entry(verb: run, lesson: 1), Entry(verb: dance, lesson: 1),
        Entry(verb: sing, lesson: 1), Entry(verb: write, lesson: 1), Entry(verb: study, lesson: 1), Entry(verb: walk, lesson: 1),
        Entry(verb: draw, lesson: 1), Entry(verb: drink, lesson: 1), Entry(verb: eat, lesson: 1), Entry(verb: listen, lesson: 1),
        Entry(verb: wait, lesson: 1), Entry(verb: drive, lesson: 1),
        // Урок 2: глаголы с местоимением во второй форме — «Я встречу её», «Позвоню ему»
        Entry(verb: PolyglotLesson2.see, lesson: 2, object: true), Entry(verb: PolyglotLesson2.hear, lesson: 2, object: true),
        Entry(verb: PolyglotLesson2.ask, lesson: 2, object: true), Entry(verb: PolyglotLesson2.answer, lesson: 2, object: true),
        Entry(verb: PolyglotLesson2.take, lesson: 2, object: true, alone: false),
        Entry(verb: PolyglotLesson2.give, lesson: 2, object: true, alone: false),
        Entry(verb: PolyglotLesson2.travel, lesson: 2), Entry(verb: PolyglotLesson2.come, lesson: 2),
        Entry(verb: PolyglotLesson2.fly, lesson: 2),
        Entry(verb: meet, lesson: 2, object: true, alone: false), Entry(verb: call, lesson: 2, object: true),
        Entry(verb: visit, lesson: 2, object: true, alone: false), Entry(verb: invite, lesson: 2, object: true, alone: false),
        Entry(verb: teach, lesson: 2, object: true), Entry(verb: thank, lesson: 2, object: true, alone: false),
        Entry(verb: understand, lesson: 2, object: true), Entry(verb: remember, lesson: 2, object: true),
    ]

    /// Глаголы уроков 1…lesson: takingObject — с «его / ему» (урок 2), иначе — те, что звучат без дополнения (схема урока 1)
    static func verbs(upTo lesson: Int, takingObject: Bool = false) -> [Verb] {
        registry.filter { $0.lesson <= lesson && (takingObject ? $0.object : $0.alone) }.map(\.verb)
    }

    private static func will(_ infinitive: String) -> [String] {
        ["буду", "будешь", "будет", "будем", "будете", "будут"].map { "\($0) \(infinitive)" }
    }

    // MARK: - Урок 1 (A1)

    static let play = Verb(base: "play", third: "plays", past: "played",
        present: ["играю", "играешь", "играет", "играем", "играете", "играют"], pastRu: ("играл", "играла", "играли"),
        future: will("играть"), objectCase: .accusative)
    static let swim = Verb(base: "swim", third: "swims", past: "swam",
        present: ["плаваю", "плаваешь", "плавает", "плаваем", "плаваете", "плавают"], pastRu: ("плавал", "плавала", "плавали"),
        future: will("плавать"), objectCase: .accusative)
    static let sleep = Verb(base: "sleep", third: "sleeps", past: "slept",
        present: ["сплю", "спишь", "спит", "спим", "спите", "спят"], pastRu: ("спал", "спала", "спали"),
        future: will("спать"), objectCase: .accusative)
    static let run = Verb(base: "run", third: "runs", past: "ran",
        present: ["бегаю", "бегаешь", "бегает", "бегаем", "бегаете", "бегают"], pastRu: ("бегал", "бегала", "бегали"),
        future: will("бегать"), objectCase: .accusative)
    static let dance = Verb(base: "dance", third: "dances", past: "danced",
        present: ["танцую", "танцуешь", "танцует", "танцуем", "танцуете", "танцуют"], pastRu: ("танцевал", "танцевала", "танцевали"),
        future: will("танцевать"), objectCase: .accusative)
    static let sing = Verb(base: "sing", third: "sings", past: "sang",
        present: ["пою", "поёшь", "поёт", "поём", "поёте", "поют"], pastRu: ("пел", "пела", "пели"),
        future: will("петь"), objectCase: .accusative)
    static let write = Verb(base: "write", third: "writes", past: "wrote",
        present: ["пишу", "пишешь", "пишет", "пишем", "пишете", "пишут"], pastRu: ("писал", "писала", "писали"),
        future: will("писать"), objectCase: .accusative)
    static let study = Verb(base: "study", third: "studies", past: "studied",
        present: ["учусь", "учишься", "учится", "учимся", "учитесь", "учатся"], pastRu: ("учился", "училась", "учились"),
        future: will("учиться"), objectCase: .accusative)
    static let walk = Verb(base: "walk", third: "walks", past: "walked",
        present: ["гуляю", "гуляешь", "гуляет", "гуляем", "гуляете", "гуляют"], pastRu: ("гулял", "гуляла", "гуляли"),
        future: will("гулять"), objectCase: .accusative)
    static let draw = Verb(base: "draw", third: "draws", past: "drew",
        present: ["рисую", "рисуешь", "рисует", "рисуем", "рисуете", "рисуют"], pastRu: ("рисовал", "рисовала", "рисовали"),
        future: will("рисовать"), objectCase: .accusative)
    static let drink = Verb(base: "drink", third: "drinks", past: "drank",
        present: ["пью", "пьёшь", "пьёт", "пьём", "пьёте", "пьют"], pastRu: ("пил", "пила", "пили"),
        future: will("пить"), objectCase: .accusative)
    static let eat = Verb(base: "eat", third: "eats", past: "ate",
        present: ["ем", "ешь", "ест", "едим", "едите", "едят"], pastRu: ("ел", "ела", "ели"),
        future: will("есть"), objectCase: .accusative)
    static let listen = Verb(base: "listen", third: "listens", past: "listened",
        present: ["слушаю", "слушаешь", "слушает", "слушаем", "слушаете", "слушают"], pastRu: ("слушал", "слушала", "слушали"),
        future: will("слушать"), objectCase: .accusative)
    static let wait = Verb(base: "wait", third: "waits", past: "waited",
        present: ["жду", "ждёшь", "ждёт", "ждём", "ждёте", "ждут"], pastRu: ("ждал", "ждала", "ждали"),
        future: will("ждать"), objectCase: .accusative)
    static let drive = Verb(base: "drive", third: "drives", past: "drove",
        present: ["вожу", "водишь", "водит", "водим", "водите", "водят"], pastRu: ("водил", "водила", "водили"),
        future: will("водить"), objectCase: .accusative)

    // MARK: - Урок 2 (A1–A2): с местоимением во второй форме

    static let meet = Verb(base: "meet", third: "meets", past: "met",
        present: ["встречаю", "встречаешь", "встречает", "встречаем", "встречаете", "встречают"], pastRu: ("встретил", "встретила", "встретили"),
        future: ["встречу", "встретишь", "встретит", "встретим", "встретите", "встретят"], objectCase: .accusative)
    static let call = Verb(base: "call", third: "calls", past: "called",
        present: ["звоню", "звонишь", "звонит", "звоним", "звоните", "звонят"], pastRu: ("позвонил", "позвонила", "позвонили"),
        future: ["позвоню", "позвонишь", "позвонит", "позвоним", "позвоните", "позвонят"], objectCase: .dative)
    static let visit = Verb(base: "visit", third: "visits", past: "visited",
        present: ["навещаю", "навещаешь", "навещает", "навещаем", "навещаете", "навещают"], pastRu: ("навестил", "навестила", "навестили"),
        future: ["навещу", "навестишь", "навестит", "навестим", "навестите", "навестят"], objectCase: .accusative)
    static let invite = Verb(base: "invite", third: "invites", past: "invited",
        present: ["приглашаю", "приглашаешь", "приглашает", "приглашаем", "приглашаете", "приглашают"], pastRu: ("пригласил", "пригласила", "пригласили"),
        future: ["приглашу", "пригласишь", "пригласит", "пригласим", "пригласите", "пригласят"], objectCase: .accusative)
    static let teach = Verb(base: "teach", third: "teaches", past: "taught",
        present: ["учу", "учишь", "учит", "учим", "учите", "учат"], pastRu: ("учил", "учила", "учили"),
        future: will("учить"), objectCase: .accusative)
    static let thank = Verb(base: "thank", third: "thanks", past: "thanked",
        present: ["благодарю", "благодаришь", "благодарит", "благодарим", "благодарите", "благодарят"], pastRu: ("поблагодарил", "поблагодарила", "поблагодарили"),
        future: ["поблагодарю", "поблагодаришь", "поблагодарит", "поблагодарим", "поблагодарите", "поблагодарят"], objectCase: .accusative)
    static let understand = Verb(base: "understand", third: "understands", past: "understood",
        present: ["понимаю", "понимаешь", "понимает", "понимаем", "понимаете", "понимают"], pastRu: ("понял", "поняла", "поняли"),
        future: ["пойму", "поймёшь", "поймёт", "поймём", "поймёте", "поймут"], objectCase: .accusative)
    static let remember = Verb(base: "remember", third: "remembers", past: "remembered",
        present: ["помню", "помнишь", "помнит", "помним", "помните", "помнят"], pastRu: ("помнил", "помнила", "помнили"),
        future: will("помнить"), objectCase: .accusative)
}

/// Набор раунда: задания нескольких видов по очереди, без повторов одной и той же русской фразы
enum PolyglotRound {
    static func build(_ parts: [(count: Int, make: () -> PolyglotTask?)]) -> [PolyglotTask] {
        var tasks: [PolyglotTask] = []
        for part in parts {
            var added = 0, attempts = 0
            while added < part.count, attempts < 60 {
                attempts += 1
                if let task = part.make(), !tasks.contains(where: { $0.russian == task.russian }) {
                    tasks.append(task)
                    added += 1
                }
            }
        }
        return tasks.shuffled()
    }
}
