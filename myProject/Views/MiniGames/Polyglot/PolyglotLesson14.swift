import Foundation

/// «Грамматика», урок 14: вопрос к подлежащему без do (Who helped you?) и к дополнению с do (Who did you help?),
/// условие в конце фразы (I will call you if he comes) и погода (If it rains, we will stay at home)
enum PolyglotLesson14 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Раунд: 5 «кто сделал», 5 «кого / кому сделал», 4 условия, 1 повторение

    static func round() -> [PolyglotTask] {
        PolyglotRound.build([
            (5, subjectQuestionTask), (5, objectQuestionTask), (4, conditionTask),
            (1, { PolyglotLesson13.modalTask() }),
        ])
    }

    /// «Кому он дал?», «Кто взял тебя?» — без того, что дали, обрублено; эти не берём
    private static var objectVerbs: [Verb] {
        PolyglotWords.verbs(upTo: 14, takingObject: true).filter { !["give", "take"].contains($0.base) }
    }

    /// «Кто помог тебе?» → Who helped you? Кто — подлежащее: do / does / did не нужны, глагол — как у he
    static func subjectQuestionTask() -> PolyglotTask? {
        let verb = objectVerbs.randomElement()!
        let object = PolyglotLesson2.objects.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let he = PolyglotLesson1.pronouns.first { $0.english == "he" }!
        let verbEnglish: [String]
        switch tense {
        case .present: verbEnglish = [verb.third]
        case .past: verbEnglish = [verb.past]
        case .future: verbEnglish = ["will", verb.base]
        }
        let answer = ["who"] + verbEnglish + [object.english]
        let objectRu = verb.objectCase == .dative ? object.dative : object.accusative
        let russian = "Кто \(verb.russian(tense, he, feminine: false)) \(objectRu)?"
        // Ловушка урока — did / does, как в обычном вопросе, и форма без -s
        let extra = [tense == .future ? "does" : tense == .past ? "did" : "does", tense == .present ? verb.base : verb.third]
            .filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true, tiles: (answer + extra).shuffled())
    }

    /// «Кому ты помог?» → Who did you help? Кто-то другой — подлежащее, вопрос о дополнении: do / does / did нужны
    static func objectQuestionTask() -> PolyglotTask? {
        let subject = PolyglotLesson1.pronouns.filter { $0.person != 0 }.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let useWhat = Bool.random()
        let verb: Verb
        let word: String, wordRu: String
        if useWhat {
            guard let found = PolyglotLesson2.questionVerbs.first(where: { $0.english == "what" })?.verbs.randomElement() else { return nil }
            verb = found
            (word, wordRu) = ("what", "Что")
        } else {
            verb = objectVerbs.filter { $0.base != "know" || tense != .future }.randomElement()!
            (word, wordRu) = ("who", verb.objectCase == .dative ? "Кому" : "Кого")
        }
        let core = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                               tense: tense, form: .question)
        let answer = [word] + core
        let russian = "\(wordRu) \(subject.russian) \(verb.russian(tense, subject, feminine: Bool.random()))?"
        // Ловушка — форма прошедшего после did: who did you saw
        let extra = [tense == .past ? verb.past : verb.third, word == "who" ? "whom" : "which"].filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true, tiles: (answer + extra).shuffled())
    }

    // MARK: - Условие: в начале или в конце фразы, погода

    /// Погода и что из неё следует
    private static let weather: [(english: [String], russian: String, results: [(english: [String], russian: String)])] = [
        (["it", "rains"], "пойдёт дождь", [(["we", "will", "stay", "at", "home"], "мы останемся дома"),
                                          (["I", "will", "take", "an", "umbrella"], "я возьму зонт")]),
        (["it", "snows"], "пойдёт снег", [(["we", "will", "stay", "at", "home"], "мы останемся дома"),
                                          (["the", "children", "will", "be", "happy"], "дети будут рады")]),
        (["it", "is", "cold"], "будет холодно", [(["we", "will", "stay", "at", "home"], "мы останемся дома"),
                                                 (["I", "will", "not", "swim"], "я не буду плавать")]),
        (["it", "is", "sunny"], "будет солнечно", [(["we", "will", "swim"], "мы будем плавать"),
                                                   (["we", "will", "walk", "in", "the", "park"], "мы будем гулять в парке")]),
    ]

    /// «Если пойдёт дождь, я буду дома» → If it rains, I will be at home · «Я позвоню тебе, если он придёт» → I will call you if he comes
    static func conditionTask() -> PolyglotTask? {
        var result = PolyglotLesson10.results.randomElement()!
        let conjunction = Bool.random() ? ("if", "если") : ("when", "когда")
        let condition: (english: [String], russian: String)
        if Bool.random() {
            let item = weather.randomElement()!
            condition = (item.english, item.russian)
            result = item.results.randomElement()!
        } else {
            let verb = PolyglotLesson10.firstVerbs.randomElement()!
            guard !result.english.contains(verb.base) else { return nil }
            let who = PolyglotLesson1.pronouns.filter { $0.person == 2 || $0.person == 5 }.randomElement()!
            condition = ([who.english, who.isThirdSingular ? verb.third : verb.base], "\(who.russian) \(verb.future[who.person])")
        }
        let conditionFirst = Bool.random()
        let answer = conditionFirst
            ? [conjunction.0] + condition.english + result.english
            : result.english + [conjunction.0] + condition.english
        let russian = conditionFirst
            ? "\(conjunction.1.capitalizedFirst) \(condition.russian), \(result.russian)."
            : "\(result.russian.capitalizedFirst), \(conjunction.1) \(condition.russian)."
        let extra = ["will", conjunction.0 == "if" ? "when" : "if"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }
}
