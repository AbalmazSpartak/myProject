import Foundation

/// «Полиглот», урок 7: повторение схемы глаголов на материале всех уроков и повелительное наклонение —
/// просьба (Help me), запрет (Don't call him), вежливо (Please wait) и предложение (Let's talk)
enum PolyglotLesson7 {
    /// Глагол в повелительном: «помоги» — «не помогай» — «давай поможем»
    struct Command {
        let english: String
        let affirmative: String
        let negative: String
        /// «давай поможем»; nil — с let's по-русски звучит неестественно
        let lets: String?
        /// Кому / кого: помоги ему (дат.), позвони мне (дат.); nil — без дополнения
        let objectCase: PolyglotLesson2.Case?
    }

    static let commands: [Command] = [
        Command(english: "help", affirmative: "помоги", negative: "не помогай", lets: "давай поможем", objectCase: .dative),
        Command(english: "call", affirmative: "позвони", negative: "не звони", lets: "давай позвоним", objectCase: .dative),
        Command(english: "ask", affirmative: "спроси", negative: "не спрашивай", lets: "давай спросим", objectCase: .accusative),
        Command(english: "wait", affirmative: "подожди", negative: "не жди", lets: "давай подождём", objectCase: nil),
        Command(english: "talk", affirmative: "поговори", negative: "не говори", lets: "давай поговорим", objectCase: nil),
        Command(english: "work", affirmative: "работай", negative: "не работай", lets: "давай работать", objectCase: nil),
        Command(english: "come", affirmative: "приходи", negative: "не приходи", lets: nil, objectCase: nil),
    ]

    /// Когда — для «приходи в пять», «позвони мне завтра»
    private static let times: [(english: [String], russian: String)] = [
        (["tomorrow"], "завтра"), (["now"], "сейчас"), (["at", "five", "o'clock"], "в пять часов"),
        (["on", "Monday"], "в понедельник"), (["in", "a", "week"], "через неделю"), (["next", "week"], "на следующей неделе"),
    ]

    static func commandTask() -> PolyglotTask? {
        let command = commands.randomElement()!
        // Кого / кому: местоимения урока 2, кроме «тебя» — просьба и так обращена к тебе
        let object = PolyglotLesson2.objects.filter { $0.person != 1 && $0.person != 4 }.randomElement()!
        let withObject = command.objectCase != nil && Bool.random()
        let objectEnglish = withObject ? [object.english] : []
        let objectRussian = withObject ? " " + (command.objectCase == .dative ? object.dative : object.accusative) : ""
        // «Подожди через неделю», «работай в пять» — не говорят: время только там, где оно к месту
        let takesTime = ["come", "call", "help", "ask", "talk"].contains(command.english)
        let time = takesTime && (command.english == "come" || Bool.random()) ? times.randomElement()! : nil

        switch Int.random(in: 0..<4) {
        case 0:
            // Просьба: глагол в начале, без you
            let answer = [command.english] + objectEnglish + (time?.english ?? [])
            let russian = command.affirmative.capitalizedFirst + objectRussian + (time.map { " " + $0.russian } ?? "") + "."
            return task(russian, answer, extra: ["you", "do", "to"])
        case 1:
            // Запрет: don't + глагол
            let answer = ["don't", command.english] + objectEnglish
            let russian = command.negative.capitalizedFirst + objectRussian + "."
            return task(russian, answer, extra: ["not", "you", "doesn't"])
        case 2:
            // Вежливо: please в начале. «Пожалуйста, поговори», «пожалуйста, работай» — так не просят
            guard !["talk", "work"].contains(command.english) else { return nil }
            let answer = ["please", command.english] + objectEnglish
            let russian = "Пожалуйста, " + command.affirmative + objectRussian + "."
            return task(russian, answer, extra: ["you", "do"])
        default:
            // Let's — «давай(те)»
            guard let lets = command.lets else { return nil }
            let answer = ["let's", command.english] + objectEnglish + (time?.english ?? [])
            let russian = lets.capitalizedFirst + objectRussian + (time.map { " " + $0.russian } ?? "") + "."
            return task(russian, answer, extra: ["we", "to", "us"])
        }
    }

    /// «Давай поедем в Лондон» → Let's go to London
    static func letsGoTask() -> PolyglotTask {
        let city = PolyglotLesson2.cities.randomElement()!
        return task("Давай поедем \(city.to).", ["let's", "go", "to", city.english], extra: ["in", "we", "from"])
    }

    private static func task(_ russian: String, _ answer: [String], extra: [String]) -> PolyglotTask {
        PolyglotTask(russian: russian, answer: answer, isQuestion: false,
                     tiles: (answer + extra.filter { !answer.contains($0) }).shuffled())
    }

    // MARK: - Раунд: повторение уроков 2 и 5 и новое — повелительное

    static func round() -> [PolyglotTask] {
        var tasks: [PolyglotTask] = []
        func add(_ count: Int, _ make: () -> PolyglotTask?) {
            var added = 0, attempts = 0
            while added < count, attempts < 60 {
                attempts += 1
                if let task = make(), !tasks.contains(where: { $0.russian == task.russian }) {
                    tasks.append(task)
                    added += 1
                }
            }
        }
        add(3, PolyglotLesson2.withObject)
        add(3, PolyglotLesson2.withQuestionWord)
        add(3, PolyglotLesson5.timeTask)
        add(5, commandTask)
        add(1, { letsGoTask() })
        return tasks.shuffled()
    }
}
