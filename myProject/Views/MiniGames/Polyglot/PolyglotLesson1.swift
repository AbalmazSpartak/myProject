import Foundation

/// «Полиглот», урок 1: Will / Do / Does / Did — вопрос, утверждение и отрицание в будущем, настоящем и прошедшем.
/// Задания собираются по правилам схемы: местоимение × время × форма × глагол
enum PolyglotLesson1 {
    enum Tense: CaseIterable { case future, present, past }
    enum Form: CaseIterable { case question, affirmative, negative }

    /// Глаголы — общий запас уроков (PolyglotWords): в уроке 1 около 25 глаголов уровня A1
    typealias Verb = PolyglotLesson2.Verb

    /// Местоимение: английское, русское и чьё спряжение у глагола
    struct Pronoun {
        let english: String
        let russian: String
        /// Номер формы в Verb.present: я 0, ты 1, он/она 2, мы 3, вы 4, они 5
        let person: Int
        /// Для прошедшего: nil — род любой (я, ты), иначе — как у этого местоимения
        let pastGender: PastGender?
        var isThirdSingular: Bool { person == 2 }
    }

    enum PastGender { case masculine, feminine, plural }

    static let pronouns: [Pronoun] = [
        Pronoun(english: "I", russian: "я", person: 0, pastGender: nil),
        Pronoun(english: "you", russian: "ты", person: 1, pastGender: nil),
        Pronoun(english: "you", russian: "вы", person: 4, pastGender: .plural),
        Pronoun(english: "we", russian: "мы", person: 3, pastGender: .plural),
        Pronoun(english: "they", russian: "они", person: 5, pastGender: .plural),
        Pronoun(english: "he", russian: "он", person: 2, pastGender: .masculine),
        Pronoun(english: "she", russian: "она", person: 2, pastGender: .feminine),
    ]

    typealias Task = PolyglotTask

    // MARK: - Сборка заданий

    static func round(count: Int = 15) -> [Task] {
        // Все сочетания времени и формы — поровну, остальное случайно
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        let verbs = PolyglotWords.verbs(upTo: 1)
        var index = 0
        return PolyglotRound.build([(count, {
            let (tense, form) = combos[index % combos.count]
            index += 1
            return task(tense: tense, form: form, verb: verbs.randomElement()!, pronoun: pronouns.randomElement()!)
        })])
    }

    /// Задание по схеме урока 1 с глаголами уроков 1…lesson — повторение в следующих уроках
    static func randomTask(upTo lesson: Int) -> Task? {
        task(tense: Tense.allCases.randomElement()!, form: Form.allCases.randomElement()!,
             verb: PolyglotWords.verbs(upTo: lesson).randomElement()!, pronoun: pronouns.randomElement()!)
    }

    static func task(tense: Tense, form: Form, verb: Verb, pronoun: Pronoun) -> Task {
        let subject = pronoun.english
        let answer: [String]
        var russian: String
        let pronounRu = pronoun.russian.capitalizedFirst

        switch (tense, form) {
        case (.future, .question): answer = ["will", subject, verb.base]
        case (.future, .affirmative): answer = [subject, "will", verb.base]
        case (.future, .negative): answer = [subject, "will", "not", verb.base]
        case (.present, .question): answer = [pronoun.isThirdSingular ? "does" : "do", subject, verb.base]
        case (.present, .affirmative): answer = [subject, pronoun.isThirdSingular ? verb.third : verb.base]
        case (.present, .negative): answer = [subject, pronoun.isThirdSingular ? "doesn't" : "don't", verb.base]
        case (.past, .question): answer = ["did", subject, verb.base]
        case (.past, .affirmative): answer = [subject, verb.past]
        case (.past, .negative): answer = [subject, "did", "not", verb.base]
        }

        let ruVerb: String
        switch tense {
        case .future: ruVerb = verb.future[pronoun.person]
        case .present: ruVerb = verb.present[pronoun.person]
        case .past: ruVerb = verb.russian(.past, pronoun, feminine: Bool.random())
        }
        russian = "\(pronounRu) \(form == .negative ? "не " : "")\(ruVerb)"
        russian += form == .question ? "?" : "."

        return Task(russian: russian, answer: answer, isQuestion: form == .question,
                    tiles: (answer + distractors(for: answer, verb: verb, pronoun: pronoun)).shuffled())
    }

    /// Лишние карточки — то, что по схеме легко перепутать: другие вспомогательные слова и формы того же глагола
    private static func distractors(for answer: [String], verb: Verb, pronoun: Pronoun) -> [String] {
        let auxiliaries = ["will", "do", "does", "did", "don't", "doesn't", "not"].filter { !answer.contains($0) }
        let forms = Array(Set([verb.base, verb.third, verb.past])).filter { !answer.contains($0) }
        return Array(auxiliaries.shuffled().prefix(3)) + Array(forms.shuffled().prefix(1))
    }
}
