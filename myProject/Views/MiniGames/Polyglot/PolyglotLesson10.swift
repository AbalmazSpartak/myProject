import Foundation

/// «Грамматика», урок 10: «я думаю, что…» (I think that…), когда / если / после того как — без will
/// (When he comes, I will call) и неправильное множественное с my / your / their (your children, their people)
enum PolyglotLesson10 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Раунд: 5 «думаю, что», 4 «когда / если», 4 множественное, 2 повторения

    static func round() -> [PolyglotTask] {
        PolyglotRound.build([
            (5, thinkTask), (4, whenTask), (4, pluralTask),
            (2, { Bool.random() ? PolyglotLesson9.indirectQuestionTask() : PolyglotLesson9.reflexiveObjectTask() }),
        ])
    }

    private static func statement(_ verb: Verb, _ subject: Pronoun, _ tense: Tense) -> [String] {
        switch tense {
        case .present: return [subject.english, subject.isThirdSingular ? verb.third : verb.base]
        case .past: return [subject.english, verb.past]
        case .future: return [subject.english, "will", verb.base]
        }
    }

    // MARK: - Я думаю, что… → I think that…

    private static let intros: [(english: [String], russian: String)] = [
        (["I", "think", "that"], "Я думаю, что"),
        (["I", "don't", "think", "that"], "Я не думаю, что"),
        (["I", "hope", "that"], "Я надеюсь, что"),
        (["I", "know", "that"], "Я знаю, что"),
        (["we", "think", "that"], "Мы думаем, что"),
    ]

    /// «Я не думаю, что он придёт» → I don't think that he will come
    static func thinkTask() -> PolyglotTask? {
        let intro = intros.randomElement()!
        let verb = PolyglotWords.verbs(upTo: 10).filter { $0.base != "want" }.randomElement()!
        let subject = PolyglotLesson1.pronouns.filter { $0.person != 0 && $0.person != 3 }.randomElement()!
        let tense = PolyglotLesson1.Tense.allCases.randomElement()!
        let answer = intro.english + statement(verb, subject, tense)
        let russian = "\(intro.russian) \(subject.russian) \(verb.russian(tense, subject, feminine: Bool.random()))."
        let extra = ["what", "does", tense == .future ? "is" : "will"].filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Когда он придёт, я позвоню → When he comes, I will call: после when / if — без will

    private static let conjunctions: [(english: [String], russian: String)] = [
        (["when"], "Когда"),
        (["if"], "Если"),
        (["after"], "После того как"),
        (["before"], "Перед тем как"),
    ]

    /// Что случится сначала — глаголы с живым будущим: «придёт», «позвонит», «поможет»
    static let firstVerbs: [Verb] = [PolyglotLesson2.come, PolyglotWords.call, PolyglotLesson2.help, PolyglotLesson2.answer,
                                             PolyglotWords.understand]

    /// Что будет потом — осмысленные действия, а не случайный глагол: «Когда он придёт, мы будем есть»
    static let results: [(english: [String], russian: String)] = [
        (["I", "will", "call", "you"], "я позвоню тебе"),
        (["we", "will", "eat"], "мы будем есть"),
        (["I", "will", "help", "him"], "я помогу ему"),
        (["they", "will", "be", "happy"], "они будут счастливы"),
        (["we", "will", "be", "ready"], "мы будем готовы"),
        (["she", "will", "answer", "you"], "она ответит тебе"),
        (["we", "will", "travel"], "мы будем путешествовать"),
        (["I", "will", "be", "at", "home"], "я буду дома"),
    ]

    static func whenTask() -> PolyglotTask? {
        let conjunction = conjunctions.randomElement()!
        let first = firstVerbs.randomElement()!
        let result = results.randomElement()!
        // Сначала кто-то другой, потом «я / мы»: «Когда он придёт, я позвоню»
        let a = PolyglotLesson1.pronouns.filter { $0.person == 2 || $0.person == 5 || $0.person == 1 }.randomElement()!
        guard !result.english.contains(first.base) else { return nil }
        let answer = conjunction.english + statement(first, a, .present) + result.english
        let russian = "\(conjunction.russian) \(a.russian) \(first.future[a.person]), \(result.russian)."
        // Ловушка урока — второй will после when / if и форма прошлого
        let extra = ["will", first.past].filter { $0 == "will" || !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Неправильное множественное: children, people, men, women

    private struct Plural {
        let english: String
        let wrong: String
        let accusative: String
        let dative: String
    }

    private static let plurals: [Plural] = [
        Plural(english: "children", wrong: "childs", accusative: "детей", dative: "детям"),
    ]

    /// Чей: английское, «моих / моим» и номер лица; совпал с подлежащим — по-русски «своих»
    private static let owners: [(english: String, accusative: String, dative: String, person: Int)] = [
        ("my", "моих", "моим", 0), ("your", "твоих", "твоим", 1), ("your", "ваших", "вашим", 4),
        ("his", "его", "его", 2), ("her", "её", "её", 2), ("our", "наших", "нашим", 3), ("their", "их", "их", 5),
    ]

    /// Мужчины, женщины, люди, дети — с числом: «Я видел двух мужчин» → I saw two men
    private static let counted: [(english: String, wrong: String, two: String, three: String)] = [
        ("men", "mans", "двух мужчин", "трёх мужчин"),
        ("women", "womans", "двух женщин", "трёх женщин"),
        ("people", "peoples", "двух человек", "трёх человек"),
        ("children", "childs", "двух детей", "трёх детей"),
    ]

    static func pluralTask() -> PolyglotTask? {
        Bool.random() ? childrenTask() : countedTask()
    }

    static func countedTask() -> PolyglotTask? {
        let verb = [PolyglotLesson2.see, PolyglotWords.meet, PolyglotLesson2.know, PolyglotWords.invite].randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let noun = counted.randomElement()!
        let two = Bool.random()
        let tense = Tense.allCases.randomElement()!
        let answer = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                                 tense: tense, form: .affirmative) + [two ? "two" : "three", noun.english]
        let russian = "\(subject.russian.capitalizedFirst) \(verb.russian(tense, subject, feminine: Bool.random())) \(two ? noun.two : noun.three)."
        let extra = [noun.wrong, two ? "three" : "two"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    /// «Я знаю ваших детей» → I know your children
    static func childrenTask() -> PolyglotTask? {
        let verb = [PolyglotLesson2.know, PolyglotLesson2.see, PolyglotWords.meet, PolyglotLesson2.help,
                    PolyglotWords.remember, PolyglotWords.teach].randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let owner = owners.randomElement()!
        let plural = plurals[0]
        let tense = Tense.allCases.randomElement()!
        let dative = verb.objectCase == .dative
        // Своих — когда чьи и кто совпадают (он — его — только если это тот же «он»: по-русски тогда тоже «своих»)
        let sameOwner = owner.person == subject.person && (subject.person != 2 || (owner.english == "his") == (subject.english == "he"))
        let ownerRu = sameOwner ? (dative ? "своим" : "своих") : (dative ? owner.dative : owner.accusative)
        let answer = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                                 tense: tense, form: .affirmative) + [owner.english, plural.english]
        let russian = "\(subject.russian.capitalizedFirst) \(verb.russian(tense, subject, feminine: Bool.random())) \(ownerRu) \(dative ? plural.dative : plural.accusative)."
        let extra = [plural.wrong, owners.map(\.english).filter { !answer.contains($0) }.randomElement()!]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }
}
