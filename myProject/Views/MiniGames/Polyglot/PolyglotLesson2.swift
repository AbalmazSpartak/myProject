import Foundation

/// «Полиглот», урок 2: местоимения во второй форме (me, him…), вопросительные слова и предлоги направления —
/// поверх схемы урока 1. Фразы трёх видов: с местоимением, с вопросом, с предлогом
enum PolyglotLesson2 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form
    typealias Pronoun = PolyglotLesson1.Pronoun

    enum Case { case accusative, dative }

    /// Глагол с живыми русскими формами: «помогу», «взял» — а не «буду помогать», «брал»
    struct Verb {
        let base: String
        let third: String
        let past: String
        /// я, ты, он/она, мы, вы, они
        let present: [String]
        let pastRu: (masculine: String, feminine: String, plural: String)
        let future: [String]
        /// Падеж местоимения после глагола: вижу его, но помогаю ему
        let objectCase: Case

        func russian(_ tense: Tense, _ subject: Pronoun, feminine: Bool) -> String {
            switch tense {
            case .present: return present[subject.person]
            case .future: return future[subject.person]
            case .past:
                switch subject.pastGender {
                case .masculine?: return pastRu.masculine
                case .feminine?: return pastRu.feminine
                case .plural?: return pastRu.plural
                case nil: return feminine ? pastRu.feminine : pastRu.masculine
                }
            }
        }

        func english(_ tense: Tense, thirdPerson: Bool) -> String {
            switch tense {
            case .present: return thirdPerson ? third : base
            case .past: return past
            case .future: return base
            }
        }
    }

    private static func will(_ infinitive: String) -> [String] {
        ["буду", "будешь", "будет", "будем", "будете", "будут"].map { "\($0) \(infinitive)" }
    }

    static let see = Verb(base: "see", third: "sees", past: "saw",
        present: ["вижу", "видишь", "видит", "видим", "видите", "видят"], pastRu: ("видел", "видела", "видели"),
        future: ["увижу", "увидишь", "увидит", "увидим", "увидите", "увидят"], objectCase: .accusative)
    static let love = Verb(base: "love", third: "loves", past: "loved",
        present: ["люблю", "любишь", "любит", "любим", "любите", "любят"], pastRu: ("любил", "любила", "любили"),
        future: will("любить"), objectCase: .accusative)
    static let know = Verb(base: "know", third: "knows", past: "knew",
        present: ["знаю", "знаешь", "знает", "знаем", "знаете", "знают"], pastRu: ("знал", "знала", "знали"),
        future: will("знать"), objectCase: .accusative)
    static let hear = Verb(base: "hear", third: "hears", past: "heard",
        present: ["слышу", "слышишь", "слышит", "слышим", "слышите", "слышат"], pastRu: ("слышал", "слышала", "слышали"),
        future: ["услышу", "услышишь", "услышит", "услышим", "услышите", "услышат"], objectCase: .accusative)
    static let help = Verb(base: "help", third: "helps", past: "helped",
        present: ["помогаю", "помогаешь", "помогает", "помогаем", "помогаете", "помогают"], pastRu: ("помог", "помогла", "помогли"),
        future: ["помогу", "поможешь", "поможет", "поможем", "поможете", "помогут"], objectCase: .dative)
    static let ask = Verb(base: "ask", third: "asks", past: "asked",
        present: ["спрашиваю", "спрашиваешь", "спрашивает", "спрашиваем", "спрашиваете", "спрашивают"], pastRu: ("спросил", "спросила", "спросили"),
        future: ["спрошу", "спросишь", "спросит", "спросим", "спросите", "спросят"], objectCase: .accusative)
    static let answer = Verb(base: "answer", third: "answers", past: "answered",
        present: ["отвечаю", "отвечаешь", "отвечает", "отвечаем", "отвечаете", "отвечают"], pastRu: ("ответил", "ответила", "ответили"),
        future: ["отвечу", "ответишь", "ответит", "ответим", "ответите", "ответят"], objectCase: .dative)
    static let take = Verb(base: "take", third: "takes", past: "took",
        present: ["беру", "берёшь", "берёт", "берём", "берёте", "берут"], pastRu: ("взял", "взяла", "взяли"),
        future: ["возьму", "возьмёшь", "возьмёт", "возьмём", "возьмёте", "возьмут"], objectCase: .accusative)
    static let give = Verb(base: "give", third: "gives", past: "gave",
        present: ["даю", "даёшь", "даёт", "даём", "даёте", "дают"], pastRu: ("дал", "дала", "дали"),
        future: ["дам", "дашь", "даст", "дадим", "дадите", "дадут"], objectCase: .dative)
    static let live = Verb(base: "live", third: "lives", past: "lived",
        present: ["живу", "живёшь", "живёт", "живём", "живёте", "живут"], pastRu: ("жил", "жила", "жили"),
        future: will("жить"), objectCase: .accusative)
    static let work = Verb(base: "work", third: "works", past: "worked",
        present: ["работаю", "работаешь", "работает", "работаем", "работаете", "работают"], pastRu: ("работал", "работала", "работали"),
        future: will("работать"), objectCase: .accusative)
    static let speak = Verb(base: "speak", third: "speaks", past: "spoke",
        present: ["говорю", "говоришь", "говорит", "говорим", "говорите", "говорят"], pastRu: ("говорил", "говорила", "говорили"),
        future: will("говорить"), objectCase: .accusative)
    static let travel = Verb(base: "travel", third: "travels", past: "traveled",
        present: ["путешествую", "путешествуешь", "путешествует", "путешествуем", "путешествуете", "путешествуют"],
        pastRu: ("путешествовал", "путешествовала", "путешествовали"), future: will("путешествовать"), objectCase: .accusative)
    static let come = Verb(base: "come", third: "comes", past: "came",
        present: ["прихожу", "приходишь", "приходит", "приходим", "приходите", "приходят"], pastRu: ("пришёл", "пришла", "пришли"),
        future: ["приду", "придёшь", "придёт", "придём", "придёте", "придут"], objectCase: .dative)
    static let fly = Verb(base: "fly", third: "flies", past: "flew",
        present: ["лечу", "летишь", "летит", "летим", "летите", "летят"], pastRu: ("летел", "летела", "летели"),
        future: ["полечу", "полетишь", "полетит", "полетим", "полетите", "полетят"], objectCase: .accusative)
    static let want = Verb(base: "want", third: "wants", past: "wanted",
        present: ["хочу", "хочешь", "хочет", "хотим", "хотите", "хотят"], pastRu: ("хотел", "хотела", "хотели"),
        future: will("хотеть"), objectCase: .accusative)

    /// Местоимение во второй форме: английское, «кого?», «кому?», с предлогом «к», и первая форма — для лишних карточек
    struct Object {
        let english: String
        let accusative: String
        let dative: String
        let toForm: String
        let subjectForm: String
        let person: Int
    }

    static let objects: [Object] = [
        Object(english: "me", accusative: "меня", dative: "мне", toForm: "ко мне", subjectForm: "I", person: 0),
        Object(english: "you", accusative: "тебя", dative: "тебе", toForm: "к тебе", subjectForm: "your", person: 1),
        Object(english: "you", accusative: "вас", dative: "вам", toForm: "к вам", subjectForm: "your", person: 4),
        Object(english: "him", accusative: "его", dative: "ему", toForm: "к нему", subjectForm: "he", person: 2),
        Object(english: "her", accusative: "её", dative: "ей", toForm: "к ней", subjectForm: "she", person: 2),
        Object(english: "us", accusative: "нас", dative: "нам", toForm: "к нам", subjectForm: "we", person: 3),
        Object(english: "them", accusative: "их", dative: "им", toForm: "к ним", subjectForm: "they", person: 5),
    ]

    /// Город: «в Лондон» (куда), «в Лондоне» (где), «из Лондона» (откуда)
    struct City {
        let english: String
        let to: String
        let inside: String
        let from: String
    }

    static let cities: [City] = [
        City(english: "London", to: "в Лондон", inside: "в Лондоне", from: "из Лондона"),
        City(english: "Paris", to: "в Париж", inside: "в Париже", from: "из Парижа"),
        City(english: "Moscow", to: "в Москву", inside: "в Москве", from: "из Москвы"),
        City(english: "Rome", to: "в Рим", inside: "в Риме", from: "из Рима"),
        City(english: "Berlin", to: "в Берлин", inside: "в Берлине", from: "из Берлина"),
        City(english: "Madrid", to: "в Мадрид", inside: "в Мадриде", from: "из Мадрида"),
    ]

    /// «Я вижу меня», «мы слышим меня», «you see you» — не бывает
    private static func fits(_ subject: Pronoun, _ object: Object) -> Bool {
        let firstPerson: Set<Int> = [0, 3]
        let secondPerson: Set<Int> = [1, 4]
        return !(firstPerson.contains(subject.person) && firstPerson.contains(object.person))
            && !(secondPerson.contains(subject.person) && secondPerson.contains(object.person))
            && subject.person != object.person
    }

    /// В вопросах «я» звучит странно («Почему я помогу?») — спрашиваем о других
    private static var questionSubjects: [Pronoun] { PolyglotLesson1.pronouns.filter { $0.person != 0 } }

    // MARK: - Раунд

    static func round(count: Int = 15) -> [PolyglotTask] {
        let makers: [() -> PolyglotTask?] = [withObject, withQuestionWord, withPreposition]
        var tasks: [PolyglotTask] = []
        var attempts = 0
        while tasks.count < count, attempts < count * 20 {
            attempts += 1
            // Поровну трёх видов: по очереди
            if let task = makers[tasks.count % makers.count](),
               !tasks.contains(where: { $0.russian == task.russian }) {
                tasks.append(task)
            }
        }
        return tasks.shuffled()
    }

    // MARK: - С местоимением: «Она не любит нас» → She doesn't love us

    static func withObject() -> PolyglotTask? {
        let verb = [see, love, know, hear, help, ask, answer, take].randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let object = objects.randomElement()!
        guard fits(subject, object) else { return nil }
        let tense = Tense.allCases.randomElement()!
        let form = Form.allCases.randomElement()!
        return objectTask(verb: verb, subject: subject, object: object, tense: tense, form: form, feminine: Bool.random())
    }

    static func objectTask(verb: Verb, subject: Pronoun, object: Object, tense: Tense, form: Form, feminine: Bool) -> PolyglotTask {
        let core = englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular, tense: tense, form: form)
        let answer = core + [object.english]
        let objectRu = verb.objectCase == .accusative ? object.accusative : object.dative
        let russian = subject.russian.capitalizedFirst + " " + (form == .negative ? "не " : "")
            + verb.russian(tense, subject, feminine: feminine) + " " + objectRu + (form == .question ? "?" : ".")
        var extra = auxiliaryDistractors(excluding: answer, count: 2)
        // Главная ловушка урока — первая форма вместо второй: he вместо him
        if !answer.contains(object.subjectForm), object.subjectForm != "your" { extra.append(object.subjectForm) }
        extra += formDistractor(verb, excluding: answer)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question, tiles: (answer + extra).shuffled())
    }

    // MARK: - С вопросительным словом: «Где ты живёшь?» → Where do you live?

    /// Какие глаголы с каким словом звучат естественно
    private static let questionVerbs: [(english: String, russian: String, verbs: [Verb])] = [
        ("what", "что", [take, see, give, know, want]),
        ("where", "где", [live, work]),
        ("when", "когда", [help, come, answer]),
        ("why", "почему", [ask, help, travel]),
        ("how", "как", [work, speak, live, travel]),
    ]

    static func withQuestionWord() -> PolyglotTask? {
        // Who — в каждом шестом задании: у него свой порядок слов
        if Int.random(in: 0..<6) == 0 { return whoTask() }
        let (word, wordRu, verbs) = questionVerbs.randomElement()!
        let verb = verbs.randomElement()!
        let subject = questionSubjects.randomElement()!
        let tense = Tense.allCases.randomElement()!
        return questionTask(word: word, wordRu: wordRu, verb: verb, subject: subject, tense: tense, feminine: Bool.random())
    }

    static func questionTask(word: String, wordRu: String, verb: Verb, subject: Pronoun, tense: Tense, feminine: Bool) -> PolyglotTask {
        let answer = [word] + englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular, tense: tense, form: .question)
        let russian = wordRu.capitalizedFirst + " " + subject.russian + " " + verb.russian(tense, subject, feminine: feminine) + "?"
        let otherWord = questionVerbs.map(\.english).filter { $0 != word }.randomElement()!
        let extra = [otherWord] + auxiliaryDistractors(excluding: answer, count: 2) + formDistractor(verb, excluding: answer)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true, tiles: (answer + extra).shuffled())
    }

    /// Who — подлежащее: do/does/did не нужны. «Кто знает?» → Who knows?
    static func whoTask() -> PolyglotTask {
        let options: [(Verb, [Tense])] = [(know, [.present, .past]), (help, Tense.allCases), (speak, Tense.allCases), (come, Tense.allCases)]
        let (verb, tenses) = options.randomElement()!
        let tense = tenses.randomElement()!
        let he = PolyglotLesson1.pronouns.first { $0.russian == "он" }!
        let answer: [String]
        switch tense {
        case .present: answer = ["who", verb.third]
        case .past: answer = ["who", verb.past]
        case .future: answer = ["who", "will", verb.base]
        }
        let russian = "Кто " + verb.russian(tense, he, feminine: false) + "?"
        // Ловушка — привычное do/does/did после вопросительного слова
        let extra = ["does", "did", "do"].filter { !answer.contains($0) }.shuffled().prefix(2) + formDistractor(verb, excluding: answer)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true, tiles: (answer + extra).shuffled())
    }

    // MARK: - С предлогом: «Мы работали в Лондоне» → We worked in London

    static func withPreposition() -> PolyglotTask? {
        let form: Form = Bool.random() ? .affirmative : .question
        let subject = (form == .question ? questionSubjects : PolyglotLesson1.pronouns).randomElement()!
        let tense = Tense.allCases.randomElement()!
        let feminine = Bool.random()
        switch Int.random(in: 0..<3) {
        case 0:
            return cityTask(verb: fly, preposition: Bool.random() ? "to" : "from", city: cities.randomElement()!,
                            subject: subject, tense: tense, form: form, feminine: feminine)
        case 1:
            return cityTask(verb: Bool.random() ? live : work, preposition: "in", city: cities.randomElement()!,
                            subject: subject, tense: tense, form: form, feminine: feminine)
        default:
            let object = objects.randomElement()!
            guard fits(subject, object) else { return nil }
            return comeToTask(subject: subject, object: object, tense: tense, form: form, feminine: feminine)
        }
    }

    static func cityTask(verb: Verb, preposition: String, city: City, subject: Pronoun, tense: Tense, form: Form, feminine: Bool) -> PolyglotTask {
        let answer = englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular, tense: tense, form: form)
            + [preposition, city.english]
        let place = preposition == "to" ? city.to : preposition == "from" ? city.from : city.inside
        let russian = subject.russian.capitalizedFirst + " " + verb.russian(tense, subject, feminine: feminine) + " " + place
            + (form == .question ? "?" : ".")
        return prepositionTask(russian: russian, answer: answer, preposition: preposition, verb: verb, isQuestion: form == .question)
    }

    /// «Я приду к тебе» → I will come to you
    static func comeToTask(subject: Pronoun, object: Object, tense: Tense, form: Form, feminine: Bool) -> PolyglotTask {
        let answer = englishCore(verb: come, subject: subject.english, thirdPerson: subject.isThirdSingular, tense: tense, form: form)
            + ["to", object.english]
        let russian = subject.russian.capitalizedFirst + " " + come.russian(tense, subject, feminine: feminine) + " " + object.toForm
            + (form == .question ? "?" : ".")
        return prepositionTask(russian: russian, answer: answer, preposition: "to", verb: come, isQuestion: form == .question)
    }

    private static func prepositionTask(russian: String, answer: [String], preposition: String, verb: Verb, isQuestion: Bool) -> PolyglotTask {
        let otherPrepositions = ["in", "to", "from"].filter { $0 != preposition }
        let extra = otherPrepositions + auxiliaryDistractors(excluding: answer, count: 1) + formDistractor(verb, excluding: answer)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: isQuestion, tiles: (answer + extra).shuffled())
    }

    // MARK: - Схема урока 1

    /// Подлежащее и глагол по схеме урока 1: «does she love», «I will not love», «they loved»
    static func englishCore(verb: Verb, subject: String, thirdPerson: Bool, tense: Tense, form: Form) -> [String] {
        switch (tense, form) {
        case (.future, .question): return ["will", subject, verb.base]
        case (.future, .affirmative): return [subject, "will", verb.base]
        case (.future, .negative): return [subject, "will", "not", verb.base]
        case (.present, .question): return [thirdPerson ? "does" : "do", subject, verb.base]
        case (.present, .affirmative): return [subject, verb.english(.present, thirdPerson: thirdPerson)]
        case (.present, .negative): return [subject, thirdPerson ? "doesn't" : "don't", verb.base]
        case (.past, .question): return ["did", subject, verb.base]
        case (.past, .affirmative): return [subject, verb.past]
        case (.past, .negative): return [subject, "did", "not", verb.base]
        }
    }

    private static func auxiliaryDistractors(excluding answer: [String], count: Int) -> [String] {
        Array(["will", "do", "does", "did", "don't", "doesn't", "not"].filter { !answer.contains($0) }.shuffled().prefix(count))
    }

    private static func formDistractor(_ verb: Verb, excluding answer: [String]) -> [String] {
        Array(Set([verb.base, verb.third, verb.past]).filter { !answer.contains($0) }.shuffled().prefix(1))
    }
}
