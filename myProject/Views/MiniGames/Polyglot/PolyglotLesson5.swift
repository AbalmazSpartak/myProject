import Foundation

/// «Полиглот», урок 5: степени сравнения прилагательных и слова времени — in (через, в июне), ago, on, at, next, last.
/// Фразы двух видов: сравнение (She is younger than him, He is the tallest here) и время (I will come in two weeks)
enum PolyglotLesson5 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Pronoun = PolyglotLesson1.Pronoun

    // MARK: - Сравнение

    struct Adjective {
        let base: String
        /// younger или «more beautiful» — словами
        let comparative: [String]
        /// the youngest / the most beautiful
        let superlative: [String]
        /// моложе, красивее
        let russianComparative: String
        /// самый молодой / самая молодая / самые молодые
        let russianSuperlative: (masculine: String, feminine: String, plural: String)
        /// Частая ошибка с этим словом — для лишних карточек: more у короткого, -er у длинного, gooder…
        let wrong: [String]
    }

    static let adjectives: [Adjective] = [
        Adjective(base: "young", comparative: ["younger"], superlative: ["the", "youngest"], russianComparative: "моложе",
                  russianSuperlative: ("самый молодой", "самая молодая", "самые молодые"), wrong: ["more", "youngest"]),
        Adjective(base: "old", comparative: ["older"], superlative: ["the", "oldest"], russianComparative: "старше",
                  russianSuperlative: ("самый старший", "самая старшая", "самые старшие"), wrong: ["more", "oldest"]),
        Adjective(base: "tall", comparative: ["taller"], superlative: ["the", "tallest"], russianComparative: "выше",
                  russianSuperlative: ("самый высокий", "самая высокая", "самые высокие"), wrong: ["more", "tallest"]),
        Adjective(base: "strong", comparative: ["stronger"], superlative: ["the", "strongest"], russianComparative: "сильнее",
                  russianSuperlative: ("самый сильный", "самая сильная", "самые сильные"), wrong: ["more", "strongest"]),
        Adjective(base: "fast", comparative: ["faster"], superlative: ["the", "fastest"], russianComparative: "быстрее",
                  russianSuperlative: ("самый быстрый", "самая быстрая", "самые быстрые"), wrong: ["more", "fastest"]),
        Adjective(base: "happy", comparative: ["happier"], superlative: ["the", "happiest"], russianComparative: "счастливее",
                  russianSuperlative: ("самый счастливый", "самая счастливая", "самые счастливые"), wrong: ["more", "happyer"]),
        Adjective(base: "beautiful", comparative: ["more", "beautiful"], superlative: ["the", "most", "beautiful"], russianComparative: "красивее",
                  russianSuperlative: ("самый красивый", "самая красивая", "самые красивые"), wrong: ["beautifuller", "most"]),
        Adjective(base: "famous", comparative: ["more", "famous"], superlative: ["the", "most", "famous"], russianComparative: "известнее",
                  russianSuperlative: ("самый известный", "самая известная", "самые известные"), wrong: ["famouser", "most"]),
        Adjective(base: "interesting", comparative: ["more", "interesting"], superlative: ["the", "most", "interesting"], russianComparative: "интереснее",
                  russianSuperlative: ("самый интересный", "самая интересная", "самые интересные"), wrong: ["interestinger", "most"]),
        Adjective(base: "good", comparative: ["better"], superlative: ["the", "best"], russianComparative: "лучше",
                  russianSuperlative: ("самый лучший", "самая лучшая", "самые лучшие"), wrong: ["gooder", "more"]),
        Adjective(base: "bad", comparative: ["worse"], superlative: ["the", "worst"], russianComparative: "хуже",
                  russianSuperlative: ("самый плохой", "самая плохая", "самые плохие"), wrong: ["badder", "more"]),
    ]

    /// Вторая форма местоимения после than: than me, than him
    private static let objectForm = ["I": "me", "you": "you", "he": "him", "she": "her", "we": "us", "they": "them"]

    /// «Она моложе, чем они» → She is younger than them. Ловушка — then вместо than и more у короткого слова
    static func comparativeTask() -> PolyglotTask? {
        let adjective = adjectives.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let other = PolyglotLesson1.pronouns.randomElement()!
        // Себя с собой не сравнивают: «я старше, чем мы», «ты выше, чем вы»
        let groups: [Set<Int>] = [[0, 3], [1, 4]]
        guard subject.person != other.person, !groups.contains(where: { $0.contains(subject.person) && $0.contains(other.person) }),
              !(subject.english == "you" && other.english == "you") else { return nil }
        let tense = Tense.allCases.randomElement()!
        let answer = beCore(subject, tense) + adjective.comparative + ["than", objectForm[other.english]!]
        let russian = subject.russian.capitalizedFirst + " " + russianBe(subject, tense)
            + adjective.russianComparative + ", чем " + other.russian + "."
        let extra = ["then"] + adjective.wrong.filter { !answer.contains($0) }.prefix(1) + [other.english].filter { $0 != objectForm[other.english] }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    /// «Она самая молодая здесь» → She is the youngest here. Только настоящее: «был самым…» — уже творительный падеж
    static func superlativeTask() -> PolyglotTask? {
        let adjective = adjectives.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let place: (english: [String], russian: String) = [(["here"], "здесь"), (["in", "the", "team"], "в команде"),
                                                           (["in", "the", "family"], "в семье")].randomElement()!
        let feminine = Bool.random()
        let plural = subject.pastGender == .plural
        let isFeminine = subject.pastGender == .feminine || (subject.pastGender == nil && feminine)
        // Они — «самые лучшие»; we/you/they + the best
        let answer = beCore(subject, .present) + adjective.superlative + place.english
        let forms = adjective.russianSuperlative
        let russian = subject.russian.capitalizedFirst + " "
            + (plural ? forms.plural : isFeminine ? forms.feminine : forms.masculine) + " " + place.russian + "."
        let extra = adjective.comparative.filter { !answer.contains($0) }.prefix(1) + adjective.wrong.filter { !answer.contains($0) }.prefix(1) + ["a"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    /// I am / he was / they will be
    private static func beCore(_ subject: Pronoun, _ tense: Tense) -> [String] {
        tense == .future ? [subject.english, "will", "be"] : [subject.english, PolyglotLesson3.beForm(tense, subject)]
    }

    private static func russianBe(_ subject: Pronoun, _ tense: Tense) -> String {
        switch tense {
        case .present: return ""
        case .past:
            switch subject.pastGender {
            case .plural?: return "были "
            case .feminine?: return "была "
            default: return "был "
            }
        case .future: return ["буду", "будешь", "будет", "будем", "будете", "будут"][subject.person] + " "
        }
    }

    // MARK: - Время

    /// Выражение времени и с какими временами глагола оно сочетается
    struct TimePhrase {
        let english: [String]
        let russian: String
        let tenses: Set<Tense>
    }

    private static let numbers: [(english: String, days: String, weeks: String, months: String, years: String)] = [
        ("two", "два дня", "две недели", "два месяца", "два года"),
        ("three", "три дня", "три недели", "три месяца", "три года"),
        ("four", "четыре дня", "четыре недели", "четыре месяца", "четыре года"),
        ("five", "пять дней", "пять недель", "пять месяцев", "пять лет"),
    ]

    private static let days: [(String, String)] = [
        ("Monday", "в понедельник"), ("Tuesday", "во вторник"), ("Wednesday", "в среду"), ("Thursday", "в четверг"),
        ("Friday", "в пятницу"), ("Saturday", "в субботу"), ("Sunday", "в воскресенье"),
    ]

    private static let months: [(String, String)] = [
        ("January", "в январе"), ("February", "в феврале"), ("March", "в марте"), ("April", "в апреле"),
        ("May", "в мае"), ("June", "в июне"), ("July", "в июле"), ("August", "в августе"),
        ("September", "в сентябре"), ("October", "в октябре"), ("November", "в ноябре"), ("December", "в декабре"),
    ]

    private static let seasons: [(String, String)] = [("winter", "зимой"), ("spring", "весной"), ("summer", "летом"), ("autumn", "осенью")]

    private static let hours: [(String, String)] = [
        ("two", "в два часа"), ("three", "в три часа"), ("four", "в четыре часа"), ("five", "в пять часов"),
        ("six", "в шесть часов"), ("seven", "в семь часов"), ("nine", "в девять часов"),
    ]

    static func randomTimePhrase() -> TimePhrase {
        let number = numbers.randomElement()!
        let (unit, unitRu): (String, String) = [("days", number.days), ("weeks", number.weeks),
                                                 ("months", number.months), ("years", number.years)].randomElement()!
        let day = days.randomElement()!, month = months.randomElement()!, season = seasons.randomElement()!, hour = hours.randomElement()!
        let options: [TimePhrase] = [
            TimePhrase(english: ["in", number.english, unit], russian: "через " + unitRu, tenses: [.future]),
            TimePhrase(english: [number.english, unit, "ago"], russian: unitRu + " назад", tenses: [.past]),
            TimePhrase(english: ["in", "a", "week"], russian: "через неделю", tenses: [.future]),
            TimePhrase(english: ["a", "week", "ago"], russian: "неделю назад", tenses: [.past]),
            TimePhrase(english: ["on", day.0], russian: day.1, tenses: [.past, .present, .future]),
            TimePhrase(english: ["in", month.0], russian: month.1, tenses: [.past, .future]),
            TimePhrase(english: ["in", season.0], russian: season.1, tenses: [.past, .present, .future]),
            TimePhrase(english: ["at", hour.0, "o'clock"], russian: hour.1, tenses: [.past, .present, .future]),
            TimePhrase(english: ["tomorrow"], russian: "завтра", tenses: [.future]),
            TimePhrase(english: ["yesterday"], russian: "вчера", tenses: [.past]),
            TimePhrase(english: ["next", "week"], russian: "на следующей неделе", tenses: [.future]),
            TimePhrase(english: ["next", "year"], russian: "в следующем году", tenses: [.future]),
            TimePhrase(english: ["last", "month"], russian: "в прошлом месяце", tenses: [.past]),
            TimePhrase(english: ["last", "year"], russian: "в прошлом году", tenses: [.past]),
        ]
        return options.randomElement()!
    }

    /// «Я приду через две недели» → I will come in two weeks. Ловушки — не тот предлог и предлог перед next/last
    static func timeTask() -> PolyglotTask? {
        let time = randomTimePhrase()
        let tense = time.tenses.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let feminine = Bool.random()
        let core: [String]
        let russianVerb: String
        switch Int.random(in: 0..<3) {
        case 0:
            core = beCore(subject, tense) + ["here"]
            russianVerb = russianBe(subject, tense).trimmingCharacters(in: .whitespaces)
                + (tense == .present ? "здесь" : " здесь")
        case 1:
            let verb = PolyglotLesson2.come
            core = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular, tense: tense, form: .affirmative)
            russianVerb = verb.russian(tense, subject, feminine: feminine)
        default:
            let verb = PolyglotLesson2.work
            core = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular, tense: tense, form: .affirmative)
            russianVerb = verb.russian(tense, subject, feminine: feminine)
        }
        let answer = core + time.english
        let russian = subject.russian.capitalizedFirst + " " + russianVerb + " " + time.russian + "."
        let prepositions = ["in", "on", "at", "ago"].filter { !answer.contains($0) }.shuffled().prefix(2)
        let extra = Array(prepositions) + ["will", "did"].filter { !answer.contains($0) }.prefix(1)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Раунд: 5 сравнений, 3 превосходные, 7 про время

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
        add(5, comparativeTask)
        add(3, superlativeTask)
        add(7, timeTask)
        return tasks.shuffled()
    }
}
