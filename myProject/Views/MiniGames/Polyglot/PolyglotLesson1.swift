import Foundation

/// «Полиглот», урок 1: Will / Do / Does / Did — вопрос, утверждение и отрицание в будущем, настоящем и прошедшем.
/// Задания собираются по правилам схемы: местоимение × время × форма × глагол
enum PolyglotLesson1 {
    enum Tense: CaseIterable { case future, present, past }
    enum Form: CaseIterable { case question, affirmative, negative }

    /// Глагол: английские формы и русское спряжение (я, ты, он/она, мы, вы, они), прошедшее — м., ж., мн.
    struct Verb {
        let base: String
        let third: String
        let past: String
        let infinitive: String
        let present: [String]
        let pastRu: (masculine: String, feminine: String, plural: String)
    }

    static let verbs: [Verb] = [
        Verb(base: "love", third: "loves", past: "loved", infinitive: "любить",
             present: ["люблю", "любишь", "любит", "любим", "любите", "любят"], pastRu: ("любил", "любила", "любили")),
        Verb(base: "want", third: "wants", past: "wanted", infinitive: "хотеть",
             present: ["хочу", "хочешь", "хочет", "хотим", "хотите", "хотят"], pastRu: ("хотел", "хотела", "хотели")),
        Verb(base: "work", third: "works", past: "worked", infinitive: "работать",
             present: ["работаю", "работаешь", "работает", "работаем", "работаете", "работают"], pastRu: ("работал", "работала", "работали")),
        Verb(base: "live", third: "lives", past: "lived", infinitive: "жить",
             present: ["живу", "живёшь", "живёт", "живём", "живёте", "живут"], pastRu: ("жил", "жила", "жили")),
        Verb(base: "play", third: "plays", past: "played", infinitive: "играть",
             present: ["играю", "играешь", "играет", "играем", "играете", "играют"], pastRu: ("играл", "играла", "играли")),
        Verb(base: "know", third: "knows", past: "knew", infinitive: "знать",
             present: ["знаю", "знаешь", "знает", "знаем", "знаете", "знают"], pastRu: ("знал", "знала", "знали")),
        Verb(base: "speak", third: "speaks", past: "spoke", infinitive: "говорить",
             present: ["говорю", "говоришь", "говорит", "говорим", "говорите", "говорят"], pastRu: ("говорил", "говорила", "говорили")),
        Verb(base: "help", third: "helps", past: "helped", infinitive: "помогать",
             present: ["помогаю", "помогаешь", "помогает", "помогаем", "помогаете", "помогают"], pastRu: ("помогал", "помогала", "помогали")),
        Verb(base: "cook", third: "cooks", past: "cooked", infinitive: "готовить",
             present: ["готовлю", "готовишь", "готовит", "готовим", "готовите", "готовят"], pastRu: ("готовил", "готовила", "готовили")),
        Verb(base: "read", third: "reads", past: "read", infinitive: "читать",
             present: ["читаю", "читаешь", "читает", "читаем", "читаете", "читают"], pastRu: ("читал", "читала", "читали")),
    ]

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

    private static let futureRu = ["буду", "будешь", "будет", "будем", "будете", "будут"]

    /// Задание: фраза на русском, правильный порядок карточек и все карточки вперемешку (с лишними)
    struct Task: Identifiable {
        let id = UUID()
        let russian: String
        let answer: [String]
        let isQuestion: Bool
        let tiles: [String]

        /// Правильный ответ целиком: «Does she love?»
        var answerText: String {
            PolyglotLesson1.sentence(answer, isQuestion: isQuestion)
        }
    }

    // MARK: - Сборка заданий

    static func round(count: Int = 15) -> [Task] {
        // Все сочетания времени и формы — поровну, остальное случайно
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        return (0..<count).map { index in
            let (tense, form) = combos[index % combos.count]
            return task(tense: tense, form: form, verb: verbs.randomElement()!, pronoun: pronouns.randomElement()!)
        }
        .shuffled()
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
        case .future: ruVerb = "\(futureRu[pronoun.person]) \(verb.infinitive)"
        case .present: ruVerb = verb.present[pronoun.person]
        case .past:
            switch pronoun.pastGender ?? (Bool.random() ? .masculine : .feminine) {
            case .masculine: ruVerb = verb.pastRu.masculine
            case .feminine: ruVerb = verb.pastRu.feminine
            case .plural: ruVerb = verb.pastRu.plural
            }
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

    // MARK: - Проверка

    /// Сокращения считаются как полные формы: didn't = did not, won't = will not
    static func isCorrect(_ tiles: [String], for task: Task) -> Bool {
        normalized(tiles) == normalized(task.answer)
    }

    private static func normalized(_ words: [String]) -> String {
        words.joined(separator: " ").lowercased()
            .replacingOccurrences(of: "won't", with: "will not")
            .replacingOccurrences(of: "didn't", with: "did not")
            .replacingOccurrences(of: "doesn't", with: "does not")
            .replacingOccurrences(of: "don't", with: "do not")
    }

    /// Карточки → предложение: с заглавной буквы и знаком в конце
    static func sentence(_ words: [String], isQuestion: Bool) -> String {
        guard !words.isEmpty else { return "" }
        return words.joined(separator: " ").capitalizedFirst + (isQuestion ? "?" : ".")
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
