import Foundation

/// «Грамматика», урок 13: модальные глаголы — can / could, should, must / mustn't — и let's, let him.
/// После них глагол без to и без -s: she can swim, а не she can to swim / she cans
enum PolyglotLesson13 {
    typealias Form = PolyglotLesson1.Form
    typealias Pronoun = PolyglotLesson1.Pronoun
    typealias Verb = PolyglotLesson2.Verb

    // MARK: - Раунд: 8 модальных по схеме, 3 вежливые просьбы, 3 let, 1 повторение

    static func round() -> [PolyglotTask] {
        PolyglotRound.build([
            (8, modalTask), (3, politeTask), (3, letTask),
            (1, { Bool.random() ? PolyglotLesson12.ordinalTask() : PolyglotLesson12.dateTask() }),
        ])
    }

    /// Глаголы с русским «плавать», «петь» — неопределённая форма берётся из «буду плавать»
    private static var verbs: [Verb] {
        PolyglotWords.verbs(upTo: 13).filter { $0.future[0].hasPrefix("буду ") && !["want", "know", "love", "live", "teach", "remember"].contains($0.base) }
    }

    private static func infinitive(_ verb: Verb) -> String { String(verb.future[0].dropFirst("буду ".count)) }

    private enum Modal: CaseIterable { case can, could, should, must }

    private static let dative = ["мне", "тебе", "ему", "нам", "вам", "им"]

    /// «Ты можешь плавать?» → Can you swim? · «Ей не стоит ждать» → She shouldn't wait · «Нам нельзя спать» → We mustn't sleep
    static func modalTask() -> PolyglotTask? {
        let modal = Modal.allCases.randomElement()!
        let form = Form.allCases.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let verb = verbs.randomElement()!
        if form == .question, subject.person == 0, modal != .should { return nil }
        // «Стоит ли» спрашивают о себе: «Мне стоит подождать?» → Should I wait?
        if form == .question, modal == .should, subject.person != 0, subject.person != 3 { return nil }
        let word = "\(modal)"
        let negative = ["can": "can't", "could": "couldn't", "should": "shouldn't", "must": "mustn't"][word]!
        let answer: [String]
        switch form {
        case .affirmative: answer = [subject.english, word, verb.base]
        case .negative: answer = [subject.english, negative, verb.base]
        case .question: answer = [word, subject.english, verb.base]
        }

        let inf = infinitive(verb)
        let feminine = subject.pastGender == .feminine || (subject.pastGender == nil && Bool.random())
        let plural = subject.pastGender == .plural
        let toWhom = subject.person == 2 ? (subject.english == "she" ? "ей" : "ему") : dative[subject.person]
        var russian: String
        switch modal {
        case .can:
            let can = ["могу", "можешь", "может", "можем", "можете", "могут"][subject.person]
            russian = "\(subject.russian.capitalizedFirst) \(form == .negative ? "не " : "")\(can) \(inf)"
        case .could:
            let could = plural ? "могли" : feminine ? "могла" : "мог"
            russian = "\(subject.russian.capitalizedFirst) \(form == .negative ? "не " : "")\(could) \(inf)"
        case .should:
            russian = "\(toWhom.capitalizedFirst) \(form == .negative ? "не " : "")стоит \(inf)"
        case .must:
            if form == .negative {
                russian = "\(toWhom.capitalizedFirst) нельзя \(inf)"
            } else {
                let must = plural ? "должны" : feminine ? "должна" : "должен"
                russian = "\(subject.russian.capitalizedFirst) \(must) \(inf)"
            }
        }
        russian += form == .question ? "?" : "."
        // Ловушки: to после модального, -s у глагола, do / does для вопроса
        let extra = ["to", verb.third, form == .question ? "does" : Modal.allCases.map { "\($0)" }.filter { $0 != word }.randomElement()!]
            .filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question, tiles: (answer + extra).shuffled())
    }

    // MARK: - Вежливые просьбы: could you…, can I…

    private static let polite: [(russian: String, answer: [String], extra: [String])] = [
        ("Не могли бы вы мне помочь?", ["could", "you", "help", "me"], ["to", "I", "can't"]),
        ("Не могли бы вы позвонить мне завтра?", ["could", "you", "call", "me", "tomorrow"], ["to", "calls", "my"]),
        ("Можно вас спросить?", ["can", "I", "ask", "you"], ["to", "me", "do"]),
        ("Ты можешь меня подождать?", ["can", "you", "wait", "for", "me"], ["to", "I", "does"]),
        ("Не могли бы вы говорить медленнее?", ["could", "you", "speak", "more", "slowly"], ["to", "speaks", "most"]),
        ("Можно мне взять это?", ["can", "I", "take", "this"], ["to", "me", "takes"]),
        ("Не могли бы вы повторить?", ["could", "you", "repeat", "it"], ["to", "repeats", "do"]),
        ("Ты не мог бы открыть окно?", ["could", "you", "open", "the", "window"], ["to", "opens", "a"]),
    ]

    static func politeTask() -> PolyglotTask? {
        let phrase = polite.randomElement()!
        return PolyglotTask(russian: phrase.russian, answer: phrase.answer, isQuestion: true,
                            tiles: (phrase.answer + phrase.extra).shuffled())
    }

    // MARK: - Let: давай, пусть

    /// «Давайте гулять» → Let's walk · «Давай не будем ждать» → Let's not wait · «Пусть они поют» → Let them sing
    static func letTask() -> PolyglotTask? {
        let verb = verbs.randomElement()!
        switch Int.random(in: 0..<3) {
        case 0:
            let answer = ["let's", verb.base]
            return PolyglotTask(russian: "\(Bool.random() ? "Давай" : "Давайте") \(infinitive(verb)).", answer: answer, isQuestion: false,
                                tiles: (answer + ["to", verb.third, "let"]).shuffled())
        case 1:
            let answer = ["let's", "not", verb.base]
            return PolyglotTask(russian: "Давай не будем \(infinitive(verb)).", answer: answer, isQuestion: false,
                                tiles: (answer + ["don't", "to", verb.third]).shuffled())
        default:
            let who = [("him", "он", 2), ("her", "она", 2), ("them", "они", 5)].randomElement()!
            let answer = ["let", who.0, verb.base]
            let russian = "Пусть \(who.1) \(verb.present[who.2])."
            let extra = [who.0 == "him" ? "he" : who.0 == "her" ? "she" : "they", verb.third, "to"].filter { !answer.contains($0) }
            return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
        }
    }
}
