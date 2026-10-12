import Foundation

/// «Полиглот», урок 3: глагол to be — am, is, are / was, were / will be. В русском в настоящем он пропускается
/// («Он здесь»), в английском — нужен всегда (He is here). Вопрос — to be в начале, без do/does/did
enum PolyglotLesson3 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form
    typealias Pronoun = PolyglotLesson1.Pronoun

    /// Чем подлежащее «является» или где находится
    enum Complement {
        /// Где: здесь, там, в Москве — по-русски одинаково во всех временах
        case place(english: [String], russian: String)
        /// Кто: учитель — в настоящем «учитель», в прошедшем и будущем «учителем»; для мы/вы/они — множественное
        case noun(singular: String, plural: String,
                  russian: (masculine: String, feminine: String, plural: String),
                  instrumental: (masculine: String, feminine: String, plural: String))
        /// Какой: готов, готова, готовы
        case adjective(english: String, russian: (masculine: String, feminine: String, plural: String))
    }

    static let complements: [Complement] = [
        .place(english: ["here"], russian: "здесь"),
        .place(english: ["there"], russian: "там"),
        .place(english: ["in", "Moscow"], russian: "в Москве"),
        .place(english: ["in", "London"], russian: "в Лондоне"),
        .noun(singular: "teacher", plural: "teachers",
              russian: ("учитель", "учитель", "учителя"), instrumental: ("учителем", "учителем", "учителями")),
        .noun(singular: "doctor", plural: "doctors",
              russian: ("врач", "врач", "врачи"), instrumental: ("врачом", "врачом", "врачами")),
        .noun(singular: "student", plural: "students",
              russian: ("студент", "студентка", "студенты"), instrumental: ("студентом", "студенткой", "студентами")),
        .adjective(english: "ready", russian: ("готов", "готова", "готовы")),
        .adjective(english: "happy", russian: ("счастлив", "счастлива", "счастливы")),
        .adjective(english: "right", russian: ("прав", "права", "правы")),
        .adjective(english: "busy", russian: ("занят", "занята", "заняты")),
        // Слова A1 из базы приложения
        .place(english: ["in", "Paris"], russian: "в Париже"),
        .place(english: ["in", "Rome"], russian: "в Риме"),
        .noun(singular: "friend", plural: "friends",
              russian: ("друг", "подруга", "друзья"), instrumental: ("другом", "подругой", "друзьями")),
        .noun(singular: "neighbor", plural: "neighbors",
              russian: ("сосед", "соседка", "соседи"), instrumental: ("соседом", "соседкой", "соседями")),
        .adjective(english: "hungry", russian: ("голоден", "голодна", "голодны")),
        .adjective(english: "sick", russian: ("болен", "больна", "больны")),
        .adjective(english: "angry", russian: ("зол", "зла", "злы")),
        .adjective(english: "free", russian: ("свободен", "свободна", "свободны")),
        .adjective(english: "sure", russian: ("уверен", "уверена", "уверены")),
    ]

    /// Какой — для вопросов «Почему ты занят?», «Когда она будет готова?»
    static var adjectives: [Complement] {
        complements.filter { if case .adjective = $0 { return true } else { return false } }
    }

    fileprivate enum Number { case masculine, feminine, plural }

    // MARK: - Раунд

    /// 10 заданий на to be, 3 — to be с вопросительным словом урока 2 («Где ты был?»), 2 — повторение урока 2
    static func round() -> [PolyglotTask] {
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        var index = 0
        return PolyglotRound.build([
            (10, {
                let (tense, form) = combos[index % combos.count]
                index += 1
                return task(tense: tense, form: form, subject: PolyglotLesson1.pronouns.randomElement()!,
                            complement: complements.randomElement()!, feminine: Bool.random())
            }),
            (3, { questionTask() }),
            (2, { Bool.random() ? PolyglotLesson2.withObject() : PolyglotLesson2.withQuestionWord() }),
        ])
    }

    // MARK: - To be с вопросительным словом: «Где ты был?» → Where were you?

    /// Где — без дополнения; почему / когда — с «какой»: «Почему она занята?», «Когда вы будете готовы?»
    static func questionTask(complement: Complement? = nil) -> PolyglotTask? {
        let subject = PolyglotLesson1.pronouns.filter { $0.person != 0 }.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let feminine = Bool.random()
        let number: Number = switch subject.pastGender {
        case .plural?: .plural
        case .masculine?: .masculine
        case .feminine?: .feminine
        case nil: feminine ? .feminine : .masculine
        }
        let (word, wordRu) = [("where", "где"), ("why", "почему"), ("when", "когда")].randomElement()!
        // «Где ты?» — без слова «какой»; «Почему ты?» и «Когда ты?» без него не бывает
        let adjective: Complement? = word == "where" ? complement : (complement ?? adjectives.randomElement()!)
        // «Когда ты готов?» в настоящем звучит странно — когда спрашивают о прошлом или будущем
        if word == "when", tense == .present { return nil }

        let be = beForm(tense, subject)
        var answer = [word] + (tense == .future ? ["will", subject.english, "be"] : [be, subject.english])
        var parts = [wordRu.capitalizedFirst, subject.russian]
        switch tense {
        case .present: break
        case .past: parts.append(["был", "была", "были"][number.index])
        case .future: parts.append(["буду", "будешь", "будет", "будем", "будете", "будут"][subject.person])
        }
        if let adjective {
            answer += english(adjective, number: number)
            parts.append(russian(adjective, number: number, tense: tense))
        }
        let russian = parts.joined(separator: " ") + "?"
        // Ловушка — do/does/did после вопросительного слова, как в уроке 2
        let extra = ["do", "does", "did"].shuffled().prefix(2)
            + (tense == .future ? ["is", "are"] : ["am", "is", "are", "was", "were"].filter { !answer.contains($0) }).shuffled().prefix(1)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: true, tiles: (answer + extra).shuffled())
    }

    static func task(tense: Tense, form: Form, subject: Pronoun, complement: Complement, feminine: Bool) -> PolyglotTask {
        // Род и число — для «был/была/были», «готов/готова/готовы», «студент/студентка»
        let number: Number = switch subject.pastGender {
        case .plural?: .plural
        case .masculine?: .masculine
        case .feminine?: .feminine
        case nil: feminine ? .feminine : .masculine
        }

        // Английский: подлежащее + to be + not + что/где/какой
        let be = beForm(tense, subject)
        var core: [String]
        switch (tense, form) {
        case (.future, .question): core = ["will", subject.english, "be"]
        case (.future, .affirmative): core = [subject.english, "will", "be"]
        case (.future, .negative): core = [subject.english, "will", "not", "be"]
        case (_, .question): core = [be, subject.english]
        case (_, .affirmative): core = [subject.english, be]
        case (_, .negative): core = [subject.english, be, "not"]
        }
        let answer = core + english(complement, number: number)

        // Русский: в настоящем глагола нет, в прошедшем — был, в будущем — буду…
        var parts = [subject.russian.capitalizedFirst]
        if form == .negative { parts.append("не") }
        switch tense {
        case .present: break
        case .past: parts.append(["был", "была", "были"][number.index])
        case .future: parts.append(["буду", "будешь", "будет", "будем", "будете", "будут"][subject.person])
        }
        parts.append(russian(complement, number: number, tense: tense))
        let russian = parts.joined(separator: " ") + (form == .question ? "?" : ".")

        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question,
                            tiles: (answer + distractors(for: answer, tense: tense)).shuffled())
    }

    /// am — I, is — he/she, are — остальные; was — I/he/she, were — остальные
    static func beForm(_ tense: Tense, _ subject: Pronoun) -> String {
        switch tense {
        case .present: return subject.person == 0 ? "am" : subject.isThirdSingular ? "is" : "are"
        case .past: return subject.person == 0 || subject.isThirdSingular ? "was" : "were"
        case .future: return "be"
        }
    }

    fileprivate static func english(_ complement: Complement, number: Number) -> [String] {
        switch complement {
        case .place(let english, _): return english
        case .noun(let singular, let plural, _, _): return number == .plural ? [plural] : [article(singular), singular]
        case .adjective(let english, _): return [english]
        }
    }

    /// an — перед гласным звуком: an engineer, an editor. Профессии урока начинаются с гласной буквы — и звука
    static func article(_ noun: String) -> String {
        "aeiou".contains(noun.prefix(1).lowercased()) ? "an" : "a"
    }

    fileprivate static func russian(_ complement: Complement, number: Number, tense: Tense) -> String {
        switch complement {
        case .place(_, let russian): return russian
        case .noun(_, _, let nominative, let instrumental):
            let forms = tense == .present ? nominative : instrumental
            return [forms.masculine, forms.feminine, forms.plural][number.index]
        case .adjective(_, let forms): return [forms.masculine, forms.feminine, forms.plural][number.index]
        }
    }

    /// Лишние карточки: другие формы to be и привычные по уроку 1 do/does/did — с to be они не нужны
    private static func distractors(for answer: [String], tense: Tense) -> [String] {
        let beForms = (tense == .future ? ["is", "are", "am"] : ["am", "is", "are", "was", "were"]).filter { !answer.contains($0) }
        let auxiliaries = ["do", "does", "did", "will", "be", "not"].filter { !answer.contains($0) }
        return Array(beForms.shuffled().prefix(2)) + Array(auxiliaries.shuffled().prefix(2))
    }
}

private extension PolyglotLesson3.Number {
    var index: Int {
        switch self {
        case .masculine: return 0
        case .feminine: return 1
        case .plural: return 2
        }
    }
}
