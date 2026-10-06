import Foundation

/// «Полиглот», урок 6: much / many / a lot of, little / few, a little / a few и слова-параметры
/// (always, sometimes, never; everybody, something, nothing…). Главная ловушка — двойное отрицание:
/// по-русски «никогда не», по-английски одно never
enum PolyglotLesson6 {
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Сколько: much, many, a lot of, little, few

    /// Существительное: исчисляемое или нет и как по-русски после «много / мало» и «немного / несколько»
    struct Noun {
        let english: String
        let countable: Bool
        /// времени, книг
        let genitive: String
    }

    static let nouns: [Noun] = [
        Noun(english: "time", countable: false, genitive: "времени"),
        Noun(english: "money", countable: false, genitive: "денег"),
        Noun(english: "work", countable: false, genitive: "работы"),
        Noun(english: "water", countable: false, genitive: "воды"),
        Noun(english: "books", countable: true, genitive: "книг"),
        Noun(english: "friends", countable: true, genitive: "друзей"),
        Noun(english: "cars", countable: true, genitive: "машин"),
        Noun(english: "ideas", countable: true, genitive: "идей"),
    ]

    /// «У меня», «у тебя»… — по-русски «иметь» говорят так
    private static let haveRussian = ["У меня", "У тебя", "", "У нас", "У вас", "У них"]

    private static func russianOwner(_ subject: Pronoun) -> String {
        switch subject.russian {
        case "он": return "У него"
        case "она": return "У неё"
        default: return haveRussian[subject.person]
        }
    }

    /// «У них много книг» → They have a lot of books; «У тебя много времени?» → Do you have much time?;
    /// «У неё мало друзей» → She has few friends; «У нас есть немного денег» → We have a little money
    static func quantityTask() -> PolyglotTask? {
        let noun = nouns.randomElement()!
        let subject = PolyglotLesson1.pronouns.filter { $0.english != "I" || Bool.random() }.randomElement()!
        let has = subject.isThirdSingular ? "has" : "have"
        let owner = russianOwner(subject)
        let kind = Int.random(in: 0..<4)
        let answer: [String]
        let russian: String
        let isQuestion: Bool
        let extra: [String]
        switch kind {
        case 0:
            // В утверждении «много» — a lot of: подходит ко всему
            answer = [subject.english, has, "a", "lot", "of", noun.english]
            russian = "\(owner) много \(noun.genitive)."
            isQuestion = false
            extra = [noun.countable ? "much" : "many", has == "has" ? "have" : "has"]
        case 1:
            // В вопросе — much / many
            answer = [subject.isThirdSingular ? "does" : "do", subject.english, "have", noun.countable ? "many" : "much", noun.english]
            russian = "\(owner) много \(noun.genitive)?"
            isQuestion = true
            extra = [noun.countable ? "much" : "many", "has"]
        case 2:
            // Мало — little / few
            answer = [subject.english, has, noun.countable ? "few" : "little", noun.english]
            russian = "\(owner) мало \(noun.genitive)."
            isQuestion = false
            extra = [noun.countable ? "little" : "few", "a"]
        default:
            // Немного / несколько — a little / a few
            answer = [subject.english, has, "a", noun.countable ? "few" : "little", noun.english]
            russian = "\(owner) есть \(noun.countable ? "несколько" : "немного") \(noun.genitive)."
            isQuestion = false
            extra = [noun.countable ? "little" : "few", "many"]
        }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: isQuestion,
                            tiles: (answer + extra.filter { !answer.contains($0) }).shuffled())
    }

    /// «Сколько у тебя денег?» → How much money do you have?
    static func howManyTask() -> PolyglotTask? {
        let noun = nouns.randomElement()!
        let subject = PolyglotLesson1.pronouns.filter { $0.person != 0 }.randomElement()!
        let answer = ["how", noun.countable ? "many" : "much", noun.english, subject.isThirdSingular ? "does" : "do", subject.english, "have"]
        let owner = russianOwner(subject).dropFirst(2) // «меня», «него»
        let russian = "Сколько у \(owner) \(noun.genitive)?"
        let extra = [noun.countable ? "much" : "many", "has", "are"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true,
                            tiles: (answer + extra.filter { !answer.contains($0) }).shuffled())
    }

    // MARK: - Как часто: always, sometimes, never

    static let cook = Verb(base: "cook", third: "cooks", past: "cooked",
        present: ["готовлю", "готовишь", "готовит", "готовим", "готовите", "готовят"], pastRu: ("готовил", "готовила", "готовили"),
        future: ["буду готовить", "будешь готовить", "будет готовить", "будем готовить", "будете готовить", "будут готовить"], objectCase: .accusative)
    static let read = Verb(base: "read", third: "reads", past: "read",
        present: ["читаю", "читаешь", "читает", "читаем", "читаете", "читают"], pastRu: ("читал", "читала", "читали"),
        future: ["буду читать", "будешь читать", "будет читать", "будем читать", "будете читать", "будут читать"], objectCase: .accusative)
    static let forget = Verb(base: "forget", third: "forgets", past: "forgot",
        present: ["забываю", "забываешь", "забывает", "забываем", "забываете", "забывают"], pastRu: ("забыл", "забыла", "забыли"),
        future: ["забуду", "забудешь", "забудет", "забудем", "забудете", "забудут"], objectCase: .accusative)

    private static let frequencyVerbs: [Verb] = [PolyglotLesson2.help, PolyglotLesson2.work, PolyglotLesson2.speak,
                                                 PolyglotLesson2.travel, PolyglotLesson2.answer, cook, read, forget]

    private static let frequencies: [(english: String, russian: String, isNegative: Bool)] = [
        ("always", "всегда", false), ("sometimes", "иногда", false), ("never", "никогда", true),
    ]

    /// «Он никогда не помогает» → He never helps. Слово частоты — перед глаголом; never уже отрицание, doesn't не нужен
    static func frequencyTask() -> PolyglotTask? {
        let verb = frequencyVerbs.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let frequency = frequencies.randomElement()!
        let verbForm = subject.isThirdSingular ? verb.third : verb.base
        let answer = [subject.english, frequency.english, verbForm]
        let russian = subject.russian.capitalizedFirst + " " + frequency.russian + " " + (frequency.isNegative ? "не " : "")
            + verb.present[subject.person] + "."
        let otherForm = subject.isThirdSingular ? verb.base : verb.third
        let negation = subject.isThirdSingular ? "doesn't" : "don't"
        let otherFrequency = frequencies.map(\.english).filter { $0 != frequency.english }.randomElement()!
        let extra = frequency.isNegative ? [negation, "not", otherForm] : [otherFrequency, otherForm]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Кто и что: everybody, somebody, nobody, everything, something, nothing

    private static let find = Verb(base: "find", third: "finds", past: "found",
        present: ["нахожу", "находишь", "находит", "находим", "находите", "находят"], pastRu: ("нашёл", "нашла", "нашли"),
        future: ["найду", "найдёшь", "найдёт", "найдём", "найдёте", "найдут"], objectCase: .accusative)

    private static let parameterWords: [(english: String, russian: String, isNegative: Bool, isPerson: Bool)] = [
        ("everybody", "всех", false, true), ("somebody", "кого-то", false, true), ("nobody", "никого", true, true),
        ("everything", "всё", false, false), ("something", "что-то", false, false), ("nothing", "ничего", true, false),
    ]

    /// «Он никого не видел» → He saw nobody. «Мы ничего не нашли» → We found nothing
    static func parameterTask() -> PolyglotTask? {
        let word = parameterWords.randomElement()!
        // find — только в прошедшем: «я нахожу что-то» звучит странно
        let options: [(Verb, PolyglotLesson1.Tense)] = [
            (PolyglotLesson2.see, .present), (PolyglotLesson2.see, .past), (PolyglotLesson2.know, .present),
            (PolyglotLesson2.hear, .present), (PolyglotLesson2.hear, .past), (find, .past),
        ]
        let (verb, tense) = options.randomElement()!
        // «Знать что-то» и «знать кого-то» по-русски звучат натянуто — know только со всеми / никем / всем / ничем
        if verb.base == "know", word.english.hasPrefix("some") { return nil }
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let verbForm = tense == .past ? verb.past : (subject.isThirdSingular ? verb.third : verb.base)
        let answer = [subject.english, verbForm, word.english]
        let russianVerb = verb.russian(tense, subject, feminine: Bool.random())
        // По-русски отрицание двойное: «никого не вижу»
        let russian = subject.russian.capitalizedFirst + " "
            + (word.isNegative ? "\(word.russian) не \(russianVerb)" : "\(russianVerb) \(word.russian)") + "."
        var extra = [tense == .past ? "didn't" : (subject.isThirdSingular ? "doesn't" : "don't")]
        // Соседнее слово той же группы: somebody вместо nobody
        let sameGroup = parameterWords.filter { $0.isPerson == word.isPerson && $0.english != word.english }.map(\.english)
        extra.append(sameGroup.randomElement()!)
        if word.isNegative { extra.append(word.isPerson ? "anybody" : "anything") }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Раунд: 4 «сколько», 2 «how much», 4 «как часто», 5 «кто и что»

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
        add(4, quantityTask)
        add(2, howManyTask)
        add(4, frequencyTask)
        add(5, parameterTask)
        return tasks.shuffled()
    }
}
