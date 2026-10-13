import Foundation

/// «Грамматика», урок 11: длительные времена — am/is/are + -ing, was/were + -ing, will be + -ing.
/// Та же схема 3 × 3, что в уроке 1, но о процессе: «сейчас», «вчера в пять», «завтра в это время»
enum PolyglotLesson11 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Раунд: 9 по схеме 3 × 3, 3 «обычно или сейчас», 2 с вопросительным словом, 1 повторение

    static func round() -> [PolyglotTask] {
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        var index = 0
        return PolyglotRound.build([
            (9, {
                let (tense, form) = combos[index % combos.count]
                index += 1
                return task(tense: tense, form: form)
            }),
            (3, contrastTask), (2, questionWordTask),
            (1, { Bool.random() ? PolyglotLesson10.whenTask() : PolyglotLesson10.thinkTask() }),
        ])
    }

    /// Глаголы процесса: у «помог», «возьму» нет длительного значения — только «помогал», «буду помогать»
    private static var verbs: [Verb] {
        PolyglotWords.verbs(upTo: 11).filter { $0.future[0].hasPrefix("буду ") && !["know", "want", "love", "remember", "live", "teach", "drive", "drink"].contains($0.base) }
    }

    /// -ing: dance → dancing, swim → swimming, study → studying
    static func ing(_ verb: Verb) -> String {
        let special = ["swim": "swimming", "run": "running", "travel": "traveling", "sit": "sitting", "get": "getting"]
        if let form = special[verb.base] { return form }
        if verb.base.hasSuffix("e"), !verb.base.hasSuffix("ee") { return String(verb.base.dropLast()) + "ing" }
        return verb.base + "ing"
    }

    static func be(_ tense: Tense, _ subject: Pronoun) -> String { PolyglotLesson3.beForm(tense, subject) }

    /// Подлежащее + be + -ing по схеме: «are you reading», «she was not sleeping», «they will be working»
    static func core(_ verb: Verb, _ subject: Pronoun, _ tense: Tense, _ form: Form) -> [String] {
        let s = subject.english, v = ing(verb)
        switch (tense, form) {
        case (.future, .question): return ["will", s, "be", v]
        case (.future, .affirmative): return [s, "will", "be", v]
        case (.future, .negative): return [s, "will", "not", "be", v]
        case (_, .question): return [be(tense, subject), s, v]
        case (_, .affirmative): return [s, be(tense, subject), v]
        case (_, .negative): return [s, be(tense, subject), "not", v]
        }
    }

    /// Когда идёт процесс: сейчас, вчера в пять, завтра в это время
    private static func moment(_ tense: Tense) -> (english: [String], russian: String) {
        switch tense {
        case .present:
            return [(["now"], "сейчас"), (["at", "the", "moment"], "в данный момент")].randomElement()!
        case .past:
            return [(["at", "five", "o'clock", "yesterday"], "вчера в пять часов"),
                    (["when", "I", "called"], Bool.random() ? ", когда я позвонил" : ", когда я позвонила")].randomElement()!
        case .future:
            return [(["at", "this", "time", "tomorrow"], "завтра в это время"),
                    (["at", "six", "o'clock", "tomorrow"], "завтра в шесть часов")].randomElement()!
        }
    }

    static func task(tense: Tense, form: Form) -> PolyglotTask? {
        let verb = verbs.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        // «Я спал, когда я позвонил» не бывает
        let time = moment(tense)
        if subject.person == 0, time.english.contains("called") { return nil }
        if subject.person == 0, form == .question { return nil }
        let answer = core(verb, subject, tense, form) + time.english
        let russian = subject.russian.capitalizedFirst + " " + (form == .negative ? "не " : "")
            + verb.russian(tense, subject, feminine: Bool.random()) + (time.russian.hasPrefix(",") ? "" : " ") + time.russian
            + (form == .question ? "?" : ".")
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question,
                            tiles: (answer + distractors(answer, verb, tense)).shuffled())
    }

    /// Лишние: другая форма be, do/does/did из простых времён и простая форма глагола вместо -ing
    private static func distractors(_ answer: [String], _ verb: Verb, _ tense: Tense) -> [String] {
        let beForms = (tense == .past ? ["is", "are", "were", "was"] : ["am", "is", "are", "was"]).filter { !answer.contains($0) }
        return Array(beForms.shuffled().prefix(1)) + ["do", "does", "did"].filter { !answer.contains($0) }.shuffled().prefix(1)
            + [tense == .present ? verb.third : verb.base].filter { !answer.contains($0) }
    }

    // MARK: - Обычно или сейчас: Simple — привычка, Continuous — процесс

    static func contrastTask() -> PolyglotTask? {
        let verb = verbs.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let russianVerb = verb.present[subject.person]
        if Bool.random() {
            // «Она обычно плавает» → She usually swims
            let habit = [(["usually"], "обычно", true), (["every", "day"], "каждый день", false)].randomElement()!
            let simple = subject.isThirdSingular ? verb.third : verb.base
            let answer = habit.2 ? [subject.english, "usually", simple] : [subject.english, simple, "every", "day"]
            let russian = "\(subject.russian.capitalizedFirst) \(habit.1) \(russianVerb)."
            let extra = [be(.present, subject), ing(verb)]
            return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
        }
        // «Она плавает сейчас» → She is swimming now
        let answer = [subject.english, be(.present, subject), ing(verb), "now"]
        let russian = "\(subject.russian.capitalizedFirst) \(russianVerb) сейчас."
        let extra = [subject.isThirdSingular ? verb.third : verb.base, "usually"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - «Что ты делаешь?» → What are you doing?

    static func questionWordTask() -> PolyglotTask? {
        let subject = PolyglotLesson1.pronouns.filter { $0.person != 0 }.randomElement()!
        let tense: Tense = [.present, .present, .past].randomElement()!
        if Bool.random() {
            let doing = tense == .present
                ? ["делаю", "делаешь", "делает", "делаем", "делаете", "делают"][subject.person]
                : (subject.pastGender == .plural ? "делали" : subject.pastGender == .feminine ? "делала" : "делал")
            let answer = ["what", be(tense, subject), subject.english, "doing"] + (tense == .past ? ["at", "five", "o'clock"] : [])
            let russian = "Что \(subject.russian) \(doing)\(tense == .past ? " в пять часов" : "")?"
            return PolyglotTask(russian: russian, answer: answer, isQuestion: true,
                                tiles: (answer + ["do", "does", "did"].filter { !answer.contains($0) }.prefix(2)).shuffled())
        }
        let (word, wordRu, list) = PolyglotLesson2.questionVerbs.filter { $0.english != "when" }.randomElement()!
        guard let verb = list.filter({ v in verbs.contains { $0.base == v.base } }).randomElement() else { return nil }
        let answer = [word, be(tense, subject), subject.english, ing(verb)] + (tense == .present ? ["now"] : [])
        let russian = "\(wordRu.capitalizedFirst) \(subject.russian) \(verb.russian(tense, subject, feminine: Bool.random()))\(tense == .present ? " сейчас" : "")?"
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true,
                            tiles: (answer + ["do", "does", "did"].filter { !answer.contains($0) }.prefix(2)).shuffled())
    }
}
