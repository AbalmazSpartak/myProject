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
    ]

    fileprivate enum Number { case masculine, feminine, plural }

    // MARK: - Раунд

    static func round(count: Int = 15) -> [PolyglotTask] {
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        var tasks: [PolyglotTask] = []
        var index = 0
        while tasks.count < count, index < count * 20 {
            let (tense, form) = combos[index % combos.count]
            index += 1
            let task = task(tense: tense, form: form, subject: PolyglotLesson1.pronouns.randomElement()!,
                            complement: complements.randomElement()!, feminine: Bool.random())
            if !tasks.contains(where: { $0.russian == task.russian }) { tasks.append(task) }
        }
        return tasks.shuffled()
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

    private static func english(_ complement: Complement, number: Number) -> [String] {
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

    private static func russian(_ complement: Complement, number: Number, tense: Tense) -> String {
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
