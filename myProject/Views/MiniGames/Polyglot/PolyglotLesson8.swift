import Foundation

/// «Полиглот», урок 8: предлоги места (on, under, in, over, at), with / without / for / about и фразовые глаголы
/// с go и look. Фразы трёх видов: где что лежит, с кем / без кого / для кого / о ком, и готовые фразовые глаголы
enum PolyglotLesson8 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Где: The book is on the table

    /// Предмет: книга (ж.), ключи (мн.), телефон (м.) — для «была / были / был»
    private struct Thing {
        let english: String
        let russian: String
        let isPlural: Bool
        let pastRussian: String
    }

    private static let things: [Thing] = [
        Thing(english: "book", russian: "Книга", isPlural: false, pastRussian: "была"),
        Thing(english: "cat", russian: "Кошка", isPlural: false, pastRussian: "была"),
        Thing(english: "bag", russian: "Сумка", isPlural: false, pastRussian: "была"),
        Thing(english: "phone", russian: "Телефон", isPlural: false, pastRussian: "был"),
        Thing(english: "keys", russian: "Ключи", isPlural: true, pastRussian: "были"),
    ]

    /// Над чем-то висит лампа, а не лежит книга: over — только с ней
    private static let lamp = Thing(english: "lamp", russian: "Лампа", isPlural: false, pastRussian: "была")

    /// Место и как по-русски с каждым предлогом: на столе, под столом, над столом
    private static let places: [(english: String, forms: [String: String])] = [
        ("table", ["on": "на столе", "under": "под столом", "over": "над столом"]),
        ("chair", ["on": "на стуле", "under": "под стулом"]),
        ("bed", ["on": "на кровати", "under": "под кроватью", "over": "над кроватью"]),
        ("box", ["in": "в коробке", "on": "на коробке", "under": "под коробкой"]),
        ("room", ["in": "в комнате"]),
        ("kitchen", ["in": "на кухне"]),
        ("door", ["over": "над дверью"]),
    ]

    /// «Ключи были под кроватью» → The keys were under the bed. «На кухне» — in the kitchen, не on
    static func placeTask() -> PolyglotTask? {
        let place = places.randomElement()!
        let (preposition, russianPlace) = place.forms.randomElement()!
        let thing = preposition == "over" ? lamp : things.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let be: [String]
        let russianBe: String
        switch tense {
        case .present: be = [thing.isPlural ? "are" : "is"]; russianBe = ""
        case .past: be = [thing.isPlural ? "were" : "was"]; russianBe = thing.pastRussian + " "
        case .future: be = ["will", "be"]; russianBe = (thing.isPlural ? "будут" : "будет") + " "
        }
        let answer = ["the", thing.english] + be + [preposition, "the", place.english]
        let russian = "\(thing.russian) \(russianBe)\(russianPlace)."
        let otherPrepositions = ["on", "in", "under", "over", "at"].filter { $0 != preposition }.shuffled().prefix(2)
        let wrongBe = (thing.isPlural ? ["is", "was"] : ["are", "were"]).filter { !answer.contains($0) }.prefix(1)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false,
                            tiles: (answer + otherPrepositions + wrongBe).shuffled())
    }

    // MARK: - С кем, без кого, для кого, о ком

    /// Местоимения урока 2 по порядку: me, you (ты), you (вы), him, her, us, them — и формы после предлогов
    private static let with = ["со мной", "с тобой", "с вами", "с ним", "с ней", "с нами", "с ними"]
    private static let without = ["без меня", "без тебя", "без вас", "без него", "без неё", "без нас", "без них"]
    private static let forForms = ["для меня", "для тебя", "для вас", "для него", "для неё", "для нас", "для них"]
    private static let about = ["обо мне", "о тебе", "о вас", "о нём", "о ней", "о нас", "о них"]

    static let go = Verb(base: "go", third: "goes", past: "went",
        present: ["иду", "идёшь", "идёт", "идём", "идёте", "идут"], pastRu: ("пошёл", "пошла", "пошли"),
        future: ["пойду", "пойдёшь", "пойдёт", "пойдём", "пойдёте", "пойдут"], objectCase: .accusative)
    static let talk = Verb(base: "talk", third: "talks", past: "talked",
        present: ["говорю", "говоришь", "говорит", "говорим", "говорите", "говорят"], pastRu: ("говорил", "говорила", "говорили"),
        future: ["буду говорить", "будешь говорить", "будет говорить", "будем говорить", "будете говорить", "будут говорить"], objectCase: .accusative)
    static let think = Verb(base: "think", third: "thinks", past: "thought",
        present: ["думаю", "думаешь", "думает", "думаем", "думаете", "думают"], pastRu: ("думал", "думала", "думали"),
        future: ["буду думать", "будешь думать", "будет думать", "будем думать", "будете думать", "будут думать"], objectCase: .accusative)

    /// «Я работаю с ними» → I work with them; «Они пошли без меня» → They went without me; «Мы говорили о ней» → We talked about her
    static func companionTask() -> PolyglotTask? {
        let options: [(Verb, String, [String])] = [
            (PolyglotLesson2.work, "with", with), (PolyglotLesson2.live, "with", with), (go, "with", with),
            (go, "without", without), (PolyglotLesson2.work, "without", without),
            (talk, "about", about), (think, "about", about),
        ]
        let (verb, preposition, forms) = options.randomElement()!
        let form: PolyglotLesson1.Form = Bool.random() ? .affirmative : .question
        // В вопросах «я» звучит странно: «Я буду думать о них?»
        let subject = PolyglotLesson1.pronouns.filter { form == .affirmative || $0.person != 0 }.randomElement()!
        let index = PolyglotLesson2.objects.indices.randomElement()!
        let object = PolyglotLesson2.objects[index]
        // «Я живу со мной», «мы думаем о нас», «ты говоришь о вас» — так не говорят
        let firstPerson: Set<Int> = [0, 3], secondPerson: Set<Int> = [1, 4]
        guard subject.person != object.person,
              !(firstPerson.contains(subject.person) && firstPerson.contains(object.person)),
              !(secondPerson.contains(subject.person) && secondPerson.contains(object.person)) else { return nil }
        let tense = Tense.allCases.randomElement()!
        let answer = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                                 tense: tense, form: form) + [preposition, object.english]
        let russian = subject.russian.capitalizedFirst + " " + verb.russian(tense, subject, feminine: Bool.random())
            + " " + forms[index] + (form == .question ? "?" : ".")
        let otherPrepositions = ["with", "without", "for", "about", "to"].filter { $0 != preposition }.shuffled().prefix(2)
        let extra = Array(otherPrepositions) + [object.subjectForm].filter { $0 != "your" && !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question, tiles: (answer + extra).shuffled())
    }

    /// «Этот подарок для тебя» → This gift is for you
    static func forTask() -> PolyglotTask? {
        let index = PolyglotLesson2.objects.indices.randomElement()!
        let object = PolyglotLesson2.objects[index]
        let gift: (english: String, russian: String) = [("gift", "Этот подарок"), ("letter", "Это письмо"), ("book", "Эта книга")].randomElement()!
        let answer = ["this", gift.english, "is", "for", object.english]
        let extra = ["to", "about", object.subjectForm].filter { $0 != "your" && !answer.contains($0) }
        return PolyglotTask(russian: "\(gift.russian) \(forForms[index]).", answer: answer, isQuestion: false,
                            tiles: (answer + extra).shuffled())
    }

    // MARK: - Фразовые глаголы: go и look с послелогами

    static let phrasal: [(russian: String, answer: [String], extra: [String])] = [
        ("Возвращайся домой.", ["go", "back", "home"], ["away", "up", "to"]),
        ("Уходи отсюда.", ["go", "away", "from", "here"], ["back", "to", "out"]),
        ("Время идёт.", ["time", "goes", "by"], ["go", "away", "back"]),
        ("Они спустились с горы.", ["they", "went", "down", "the", "mountain"], ["up", "go", "from"]),
        ("Поднимайся по лестнице.", ["go", "up", "the", "stairs"], ["down", "on", "to"]),
        ("Я иду гулять.", ["I", "go", "for", "a", "walk"], ["to", "on", "goes"]),
        ("Не смотри вверх.", ["don't", "look", "up"], ["down", "at", "not"]),
        ("Посмотри под кроватью.", ["look", "under", "the", "bed"], ["on", "in", "for"]),
        ("Он искал её.", ["he", "looked", "for", "her"], ["after", "at", "she"]),
        ("Она присматривает за детьми.", ["she", "looks", "after", "the", "children"], ["for", "at", "look"]),
        ("Кто присматривает за детьми?", ["who", "looks", "after", "the", "children"], ["for", "does", "look"]),
        ("Они оглянулись и увидели нас.", ["they", "looked", "back", "and", "saw", "us"], ["away", "we", "see"]),
        ("Она отвела взгляд от него.", ["she", "looked", "away", "from", "him"], ["back", "he", "to"]),
        ("Он смотрит вниз на пол.", ["he", "looks", "down", "at", "the", "floor"], ["up", "on", "look"]),
    ]

    static func phrasalTask() -> PolyglotTask? {
        let item = phrasal.randomElement()!
        return PolyglotTask(russian: item.russian, answer: item.answer, isQuestion: item.russian.hasSuffix("?"),
                            tiles: (item.answer + item.extra.filter { !item.answer.contains($0) }).shuffled())
    }

    // MARK: - Раунд: 5 «где», 5 «с кем / о ком», 1 «для кого», 4 фразовых глагола

    static func round() -> [PolyglotTask] {
        var tasks: [PolyglotTask] = []
        func add(_ count: Int, _ make: () -> PolyglotTask?) {
            var added = 0, attempts = 0
            while added < count, attempts < 60 {
                attempts += 1
                if let task = make(), !tasks.contains(where: { $0.russian == task.russian }) {
                    tasks.append(task)
                    added += 1
                }
            }
        }
        add(5, placeTask)
        add(5, companionTask)
        add(1, forTask)
        add(4, phrasalTask)
        return tasks.shuffled()
    }
}
