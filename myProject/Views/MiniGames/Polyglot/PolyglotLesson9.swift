import Foundation

/// «Грамматика», урок 9: косвенные вопросы (Do you know where he lives?), «сам / себя» (myself, herself…)
/// и «к счастью / к сожалению». Фразы — на глаголах и схемах прошлых уроков
enum PolyglotLesson9 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Раунд: 6 косвенных вопросов, 5 «сам / себя», 2 «к счастью», 2 повторения

    static func round() -> [PolyglotTask] {
        PolyglotRound.build([
            (4, indirectQuestionTask), (2, indirectIfTask),
            (3, reflexiveObjectTask), (1, doItYourselfTask), (1, byYourselfTask),
            (2, luckTask),
            (2, {
                switch Int.random(in: 0..<3) {
                case 0: return PolyglotLesson4.verbAtPlaceTask()
                case 1: return PolyglotLesson3.questionTask()
                default: return PolyglotLesson2.withObject()
                }
            }),
        ])
    }

    // MARK: - Косвенный вопрос: вопрос внутри фразы — порядок слов как в утверждении

    /// Начало фразы: английские слова, русские, вопрос ли вся фраза
    private static let intros: [(english: [String], russian: String, isQuestion: Bool)] = [
        (["do", "you", "know"], "Ты знаешь", true),
        (["do", "you", "know"], "Вы знаете", true),
        (["I", "don't", "know"], "Я не знаю", false),
        (["tell", "me"], "Скажи мне", false),
        (["I", "wonder"], "Интересно", false),
        (["I", "remember"], "Я помню", false),
    ]

    /// Вопросы — о других: «Я не знаю, где я живу» не бывает
    private static var subjects: [Pronoun] { PolyglotLesson1.pronouns.filter { $0.person != 0 } }

    /// Глагол после вопросительного слова — как в утверждении: he lives, they worked, she will come
    private static func statement(_ verb: Verb, _ subject: Pronoun, _ tense: Tense) -> [String] {
        switch tense {
        case .present: return [subject.english, subject.isThirdSingular ? verb.third : verb.base]
        case .past: return [subject.english, verb.past]
        case .future: return [subject.english, "will", verb.base]
        }
    }

    /// «Ты знаешь, где он живёт?» → Do you know where he lives? Ловушка — привычное does/did из прямого вопроса
    static func indirectQuestionTask() -> PolyglotTask? {
        let intro = intros.randomElement()!
        let (word, wordRu, verbs) = PolyglotLesson2.questionVerbs.randomElement()!
        let verb = verbs.randomElement()!
        let subject = subjects.randomElement()!
        // «Ты знаешь, где ты живёшь?» — странно
        if intro.english.contains("you"), subject.english == "you" { return nil }
        // «Я помню, где он живёт» — о прошлом; «Я помню, когда он придёт» звучит странно
        let tense = intro.english == ["I", "remember"] ? .past : Tense.allCases.randomElement()!
        let answer = intro.english + [word] + statement(verb, subject, tense)
        let russian = "\(intro.russian), \(wordRu) \(subject.russian) \(verb.russian(tense, subject, feminine: Bool.random()))"
            + (intro.isQuestion ? "?" : ".")
        let extra = ["does", "did", "do"].filter { !answer.contains($0) }.shuffled().prefix(2)
            + [tense == .present ? verb.base : verb.third].filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: intro.isQuestion, tiles: (answer + extra).shuffled())
    }

    /// «Я не знаю, работает ли он» → I don't know if he works: «ли» — это if
    static func indirectIfTask() -> PolyglotTask? {
        let intro = intros.filter { $0.english != ["I", "remember"] }.randomElement()!
        let verb = PolyglotWords.verbs(upTo: 9).randomElement()!
        let subject = subjects.randomElement()!
        if intro.english.contains("you"), subject.english == "you" { return nil }
        let tense = Tense.allCases.randomElement()!
        let answer = intro.english + ["if"] + statement(verb, subject, tense)
        // «ли» — после первого слова глагола: «работает ли он», «будет ли он плавать»
        let words = verb.russian(tense, subject, feminine: Bool.random()).split(separator: " ").map(String.init)
        let russian = "\(intro.russian), \(words[0]) ли \(subject.russian)\(words.dropFirst().map { " \($0)" }.joined())"
            + (intro.isQuestion ? "?" : ".")
        let extra = ["does", "did", "where", "when"].filter { !answer.contains($0) }.shuffled().prefix(2)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: intro.isQuestion, tiles: (answer + extra).shuffled())
    }

    // MARK: - Сам / себя

    /// myself — я, yourself — ты, yourselves — вы, himself, herself, ourselves, themselves
    static func reflexive(_ subject: Pronoun) -> String {
        switch subject.person {
        case 0: return "myself"
        case 1: return "yourself"
        case 4: return "yourselves"
        case 3: return "ourselves"
        case 5: return "themselves"
        default: return subject.pastGender == .feminine ? "herself" : "himself"
        }
    }

    private static let allReflexive = ["myself", "yourself", "himself", "herself", "ourselves", "yourselves", "themselves"]

    /// «Она понимает себя» → She understands herself; помогаю — себе
    static func reflexiveObjectTask() -> PolyglotTask? {
        let verb = [PolyglotLesson2.love, PolyglotLesson2.help, PolyglotLesson2.ask,
                    PolyglotWords.understand, PolyglotWords.remember].randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let form = Form.allCases.randomElement()!
        // «Я понимаю себя?» — о себе так не спрашивают
        if form == .question, subject.person == 0 { return nil }
        let own = reflexive(subject)
        let answer = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                                 tense: tense, form: form) + [own]
        let russian = subject.russian.capitalizedFirst + " " + (form == .negative ? "не " : "")
            + verb.russian(tense, subject, feminine: Bool.random()) + " " + (verb.objectCase == .dative ? "себе" : "себя")
            + (form == .question ? "?" : ".")
        let extra = allReflexive.filter { $0 != own }.shuffled().prefix(2) + PolyglotLesson2.objects.map(\.english)
            .filter { !answer.contains($0) }.shuffled().prefix(1)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question, tiles: (answer + extra).shuffled())
    }

    /// «Я сделаю это сам» → I will do it myself. Сам / сама / сами — тоже myself, herself…
    static func doItYourselfTask() -> PolyglotTask? {
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let feminine = subject.pastGender == .feminine || (subject.pastGender == nil && Bool.random())
        let plural = subject.pastGender == .plural
        let tense: Tense = Bool.random() ? .past : .future
        let done = tense == .past
            ? (plural ? "сделали" : feminine ? "сделала" : "сделал")
            : ["сделаю", "сделаешь", "сделает", "сделаем", "сделаете", "сделают"][subject.person]
        let alone = plural ? "сами" : feminine ? "сама" : "сам"
        let answer = [subject.english] + (tense == .past ? ["did"] : ["will", "do"]) + ["it", reflexive(subject)]
        let russian = "\(subject.russian.capitalizedFirst) \(done) это \(alone)."
        let extra = ["does", "done", allReflexive.filter { $0 != reflexive(subject) }.randomElement()!]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    /// «Она живёт одна» → She lives by herself: by myself — «один, сам по себе»
    static func byYourselfTask() -> PolyglotTask? {
        let verb = [PolyglotLesson2.live, PolyglotLesson2.work, PolyglotLesson2.travel, PolyglotWords.study].randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let feminine = subject.pastGender == .feminine || (subject.pastGender == nil && Bool.random())
        let plural = subject.pastGender == .plural
        let answer = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                                 tense: tense, form: .affirmative) + ["by", reflexive(subject)]
        let russian = "\(subject.russian.capitalizedFirst) \(verb.russian(tense, subject, feminine: feminine)) \(plural ? "одни" : feminine ? "одна" : "один")."
        let extra = ["with", "alone", allReflexive.filter { $0 != reflexive(subject) }.randomElement()!]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - К счастью / к сожалению — в начале фразы из урока 1

    static func luckTask() -> PolyglotTask? {
        let lucky = Bool.random()
        let base = PolyglotLesson1.task(tense: Tense.allCases.randomElement()!, form: Bool.random() ? .affirmative : .negative,
                                        verb: PolyglotWords.verbs(upTo: 1).randomElement()!,
                                        pronoun: PolyglotLesson1.pronouns.randomElement()!)
        let word = lucky ? "fortunately" : "unfortunately"
        let lowered = base.russian.prefix(1).lowercased() + base.russian.dropFirst()
        let russian = (lucky ? "К счастью, " : "К сожалению, ") + lowered
        let answer = [word] + base.answer
        let extra = [lucky ? "unfortunately" : "fortunately"] + base.tiles.filter { !base.answer.contains($0) }.prefix(2)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }
}
