import Foundation

/// «Грамматика», урок 16: страдательный залог — be + третья форма. The room is cleaned every day,
/// the house was built by my grandfather, the letter will be sent tomorrow. Важно не что сделал, а что с ним сделали
enum PolyglotLesson16 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form

    // MARK: - Раунд: 9 по схеме 3 × 3, 3 «кем» (by), 2 «сделал или сделано», 1 повторение

    static func round() -> [PolyglotTask] {
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        var index = 0
        return PolyglotRound.build([
            (9, {
                let (tense, form) = combos[index % combos.count]
                index += 1
                return task(tense: tense, form: form)
            }),
            (3, byTask), (2, activeOrPassiveTask),
            (1, { PolyglotLesson15.task(tense: PolyglotLesson1.Tense.allCases.randomElement()!, form: .affirmative) }),
        ])
    }

    /// Глагол: вторая и третья формы, русское «убирается / убираются» (нет — в настоящем не говорят) и «убран / убрана / убрано / убраны»
    private struct Verb {
        let base: String
        let past: String
        let participle: String
        let present: (one: String, many: String)?
        let russian: [String]
    }

    private static let verbs: [String: Verb] = [
        "clean": Verb(base: "clean", past: "cleaned", participle: "cleaned", present: ("убирается", "убираются"),
                      russian: ["убран", "убрана", "убрано", "убраны"]),
        "write": Verb(base: "write", past: "wrote", participle: "written", present: nil,
                      russian: ["написан", "написана", "написано", "написаны"]),
        "build": Verb(base: "build", past: "built", participle: "built", present: nil,
                      russian: ["построен", "построена", "построено", "построены"]),
        "open": Verb(base: "open", past: "opened", participle: "opened", present: ("открывается", "открываются"),
                     russian: ["открыт", "открыта", "открыто", "открыты"]),
        "close": Verb(base: "close", past: "closed", participle: "closed", present: ("закрывается", "закрываются"),
                      russian: ["закрыт", "закрыта", "закрыто", "закрыты"]),
        "send": Verb(base: "send", past: "sent", participle: "sent", present: ("отправляется", "отправляются"),
                     russian: ["отправлен", "отправлена", "отправлено", "отправлены"]),
        "wash": Verb(base: "wash", past: "washed", participle: "washed", present: ("моется", "моются"),
                     russian: ["вымыт", "вымыта", "вымыто", "вымыты"]),
        "steal": Verb(base: "steal", past: "stole", participle: "stolen", present: nil,
                      russian: ["украден", "украдена", "украдено", "украдены"]),
        "break": Verb(base: "break", past: "broke", participle: "broken", present: nil,
                      russian: ["разбит", "разбита", "разбито", "разбиты"]),
    ]

    /// Что: английское, много ли, русское, род (м 0, ж 1, ср 2, мн 3), что с ним делают
    private static let things: [(english: String, plural: Bool, russian: String, gender: Int, verbs: [String])] = [
        ("house", false, "Дом", 0, ["build"]),
        ("bridge", false, "Мост", 0, ["build"]),
        ("letter", false, "Письмо", 2, ["write", "send"]),
        ("letters", true, "Письма", 3, ["write", "send"]),
        ("book", false, "Книга", 1, ["write"]),
        ("window", false, "Окно", 2, ["open", "close", "wash", "break"]),
        ("windows", true, "Окна", 3, ["open", "close", "wash"]),
        ("car", false, "Машина", 1, ["wash", "steal"]),
        ("room", false, "Комната", 1, ["clean"]),
        ("door", false, "Дверь", 1, ["open", "close"]),
        ("cup", false, "Чашка", 1, ["break", "wash"]),
        ("phone", false, "Телефон", 0, ["steal"]),
    ]

    /// Когда: каждый день — для настоящего, вчера, завтра
    private static func time(_ tense: Tense) -> (english: [String], russian: String) {
        switch tense {
        case .present: return (["every", "day"], "каждый день")
        case .past: return (["yesterday"], "вчера")
        case .future: return (["tomorrow"], "завтра")
        }
    }

    static func task(tense: Tense, form: Form) -> PolyglotTask? {
        let thing = things.randomElement()!
        guard let verb = verbs[thing.verbs.randomElement()!] else { return nil }
        // «Каждый день» — только то, что правда делают каждый день; украсть и разбить — только в прошлом
        if tense == .present, verb.present == nil { return nil }
        if tense == .future, ["steal", "break"].contains(verb.base) { return nil }
        let be: String, beNot: String
        switch tense {
        case .present: (be, beNot) = thing.plural ? ("are", "aren't") : ("is", "isn't")
        case .past: (be, beNot) = thing.plural ? ("were", "weren't") : ("was", "wasn't")
        case .future: (be, beNot) = ("will", "won't")
        }
        let subject = ["the", thing.english]
        // Дом и книгу за день не делают
        let when = tense == .future && ["build", "write"].contains(verb.base) ? (english: ["next", "year"], russian: "в следующем году") : time(tense)
        var answer: [String]
        switch form {
        case .affirmative: answer = subject + (tense == .future ? ["will", "be"] : [be])
        case .negative: answer = subject + (tense == .future ? ["won't", "be"] : [beNot])
        case .question: answer = (tense == .future ? ["will"] + subject + ["be"] : [be] + subject)
        }
        answer += [verb.participle] + when.english

        let not = form == .negative ? "не " : ""
        let rest: String
        switch tense {
        case .present:
            rest = "\(not)\(thing.plural ? verb.present!.many : verb.present!.one)"
        case .past:
            rest = "\(not)\(["был", "была", "было", "были"][thing.gender]) \(verb.russian[thing.gender])"
        case .future:
            rest = "\(not)\(thing.plural ? "будут" : "будет") \(verb.russian[thing.gender])"
        }
        let russian = "\(thing.russian) \(rest) \(when.russian)" + (form == .question ? "?" : ".")
        // Ловушки: вторая форма вместо третьей, do / did из обычного вопроса, чужое be
        let extra = [verb.past != verb.participle ? verb.past : verb.base, tense == .past ? "did" : "does",
                     tense == .future ? "is" : (thing.plural ? "is" : "are")].filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question, tiles: (answer + extra).shuffled())
    }

    // MARK: - Кем: by

    /// Кем — уместно для действия: мост строил дедушка, письмо писал друг
    private static let agents: [String: [(english: [String], russian: String)]] = [
        "build": [(["my", "grandfather"], "моим дедушкой"), (["them"], "ими")],
        "write": [(["my", "friend"], "моим другом"), (["my", "mother"], "моей мамой"), (["him"], "им")],
        "send": [(["my", "friend"], "моим другом"), (["my", "mother"], "моей мамой"), (["them"], "ими")],
        "clean": [(["my", "mother"], "моей мамой"), (["him"], "им"), (["them"], "ими")],
        "wash": [(["my", "mother"], "моей мамой"), (["him"], "им")],
        "open": [(["him"], "им"), (["them"], "ими")],
        "close": [(["him"], "им"), (["them"], "ими")],
        "break": [(["our", "neighbors"], "нашими соседями"), (["him"], "им")],
    ]

    /// «Письмо было написано моим другом» → The letter was written by my friend
    static func byTask() -> PolyglotTask? {
        let thing = things.filter { !$0.verbs.contains("steal") }.randomElement()!
        guard let verb = verbs[thing.verbs.randomElement()!], let agent = agents[verb.base]?.randomElement() else { return nil }
        let answer = ["the", thing.english, thing.plural ? "were" : "was", verb.participle, "by"] + agent.english
        let russian = "\(thing.russian) \(["был", "была", "было", "были"][thing.gender]) \(verb.russian[thing.gender]) \(agent.russian)."
        let extra = ["with", verb.past != verb.participle ? verb.past : "from", agent.english == ["him"] ? "he" : agent.english == ["them"] ? "they" : "of"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Сделал или сделано: активный и страдательный рядом

    /// «Он разбил окно» → He broke the window · «Окно было разбито» → The window was broken
    static func activeOrPassiveTask() -> PolyglotTask? {
        let thing = things.randomElement()!
        guard let verb = verbs[thing.verbs.randomElement()!] else { return nil }
        if Bool.random() {
            let who = [("he", "Он", 0), ("she", "Она", 1), ("they", "Они", 3)].randomElement()!
            let verbRu = verb.russian[thing.gender]
            // «Он разбил» — прошедшее из причастия: разбит → разбил, написан → написал, вымыт → вымыл
            let pastRu = activePast(verb.base, who.2)
            guard !pastRu.isEmpty else { return nil }
            _ = verbRu
            let answer = [who.0, verb.past, "the", thing.english]
            let russian = "\(who.1) \(pastRu) \(accusative(thing.russian, thing.gender))."
            let extra = ["was", verb.participle != verb.past ? verb.participle : "by"]
            return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
        }
        let answer = ["the", thing.english, thing.plural ? "were" : "was", verb.participle]
        let russian = "\(thing.russian) \(["был", "была", "было", "были"][thing.gender]) \(verb.russian[thing.gender])."
        let extra = ["did", verb.past != verb.participle ? verb.past : "by"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    /// «Он построил», «она вымыла», «они отправили»
    private static func activePast(_ verb: String, _ who: Int) -> String {
        let forms: [String: [String]] = [
            "clean": ["убрал", "убрала", "", "убрали"], "write": ["написал", "написала", "", "написали"],
            "build": ["построил", "построила", "", "построили"], "open": ["открыл", "открыла", "", "открыли"],
            "close": ["закрыл", "закрыла", "", "закрыли"], "send": ["отправил", "отправила", "", "отправили"],
            "wash": ["вымыл", "вымыла", "", "вымыли"], "steal": ["украл", "украла", "", "украли"],
            "break": ["разбил", "разбила", "", "разбили"],
        ]
        return forms[verb]?[who] ?? ""
    }

    /// Кого / что: книга → книгу, машина → машину; остальные не меняются
    private static func accusative(_ noun: String, _ gender: Int) -> String {
        let lower = noun.lowercased()
        guard gender == 1, lower.hasSuffix("а") else { return lower }
        return String(lower.dropLast()) + "у"
    }
}
