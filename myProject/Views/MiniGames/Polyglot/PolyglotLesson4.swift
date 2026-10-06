import Foundation

/// «Полиглот», урок 4: рассказ о себе — профессии, артикли a/an/the, предлоги in, as, at.
/// Фразы четырёх видов: кем кто является (He is an engineer), кем работает (I work as a teacher),
/// где находится с целью (They are at school) и готовые фразы про артикли
enum PolyglotLesson4 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form
    typealias Complement = PolyglotLesson3.Complement

    /// Профессия: английское слово, множественное, по-русски «кто?» и «кем?» (ед. и мн.)
    struct Profession {
        let english: String
        let plural: String
        let russian: String
        let russianPlural: String
        let instrumental: String
        let instrumentalPlural: String

        var complement: Complement {
            .noun(singular: english, plural: plural,
                  russian: (russian, russian, russianPlural), instrumental: (instrumental, instrumental, instrumentalPlural))
        }
    }

    /// Только профессии, которые по-русски одинаковы для мужчин и женщин: «она инженер», «она была инженером»
    static let professions: [Profession] = [
        Profession(english: "teacher", plural: "teachers", russian: "учитель", russianPlural: "учителя", instrumental: "учителем", instrumentalPlural: "учителями"),
        Profession(english: "doctor", plural: "doctors", russian: "врач", russianPlural: "врачи", instrumental: "врачом", instrumentalPlural: "врачами"),
        Profession(english: "writer", plural: "writers", russian: "писатель", russianPlural: "писатели", instrumental: "писателем", instrumentalPlural: "писателями"),
        Profession(english: "builder", plural: "builders", russian: "строитель", russianPlural: "строители", instrumental: "строителем", instrumentalPlural: "строителями"),
        Profession(english: "journalist", plural: "journalists", russian: "журналист", russianPlural: "журналисты", instrumental: "журналистом", instrumentalPlural: "журналистами"),
        Profession(english: "musician", plural: "musicians", russian: "музыкант", russianPlural: "музыканты", instrumental: "музыкантом", instrumentalPlural: "музыкантами"),
        Profession(english: "manager", plural: "managers", russian: "менеджер", russianPlural: "менеджеры", instrumental: "менеджером", instrumentalPlural: "менеджерами"),
        Profession(english: "physicist", plural: "physicists", russian: "физик", russianPlural: "физики", instrumental: "физиком", instrumentalPlural: "физиками"),
        Profession(english: "engineer", plural: "engineers", russian: "инженер", russianPlural: "инженеры", instrumental: "инженером", instrumentalPlural: "инженерами"),
        Profession(english: "editor", plural: "editors", russian: "редактор", russianPlural: "редакторы", instrumental: "редактором", instrumentalPlural: "редакторами"),
        Profession(english: "inventor", plural: "inventors", russian: "изобретатель", russianPlural: "изобретатели", instrumental: "изобретателем", instrumentalPlural: "изобретателями"),
        Profession(english: "electrician", plural: "electricians", russian: "электрик", russianPlural: "электрики", instrumental: "электриком", instrumentalPlural: "электриками"),
        Profession(english: "artist", plural: "artists", russian: "художник", russianPlural: "художники", instrumental: "художником", instrumentalPlural: "художниками"),
    ]

    /// Где с целью — at: на работе, в школе (учатся), в аэропорту (летят)
    static let atPlaces: [Complement] = [
        .place(english: ["at", "work"], russian: "на работе"),
        .place(english: ["at", "school"], russian: "в школе"),
        .place(english: ["at", "home"], russian: "дома"),
        .place(english: ["at", "the", "airport"], russian: "в аэропорту"),
        .place(english: ["at", "the", "cinema"], russian: "в кино"),
    ]

    /// Готовые фразы урока: про артикли и знакомство
    static let phrases: [(russian: String, answer: [String], isQuestion: Bool, extra: [String])] = [
        ("Чем вы занимаетесь?", ["what", "do", "you", "do"], true, ["does", "where", "are"]),
        ("Где вы работаете?", ["where", "do", "you", "work"], true, ["what", "are", "works"]),
        ("Какая у вас профессия?", ["what", "is", "your", "profession"], true, ["are", "do", "a"]),
        ("Я хочу яблоки.", ["I", "want", "apples"], false, ["the", "an", "a"]),
        ("Я хочу эти яблоки.", ["I", "want", "the", "apples"], false, ["an", "a", "wants"]),
        ("Где этот писатель?", ["where", "is", "the", "writer"], true, ["a", "are", "does"]),
        ("Тебе нужен врач (какой-нибудь).", ["you", "need", "a", "doctor"], false, ["the", "an", "needs"]),
        ("Тебе нужен этот врач.", ["you", "need", "the", "doctor"], false, ["a", "an", "needs"]),
        ("Я работаю в школе учителем.", ["I", "work", "in", "a", "school", "as", "a", "teacher"], false, ["at", "an", "the"]),
        ("Он работает в большой компании.", ["he", "works", "in", "a", "big", "company"], false, ["at", "as", "work"]),
        ("Я работаю на заводе.", ["I", "work", "in", "a", "factory"], false, ["at", "an", "as"]),
    ]

    // MARK: - Раунд: 5 «кем является», 4 «кем работает», 4 «где», 2 готовые фразы

    static func round() -> [PolyglotTask] {
        var tasks: [PolyglotTask] = []
        func add(_ count: Int, _ make: () -> PolyglotTask?) {
            var added = 0, attempts = 0
            while added < count, attempts < 50 {
                attempts += 1
                if let task = make(), !tasks.contains(where: { $0.russian == task.russian }) {
                    tasks.append(task)
                    added += 1
                }
            }
        }
        add(5, professionTask)
        add(4, workAsTask)
        add(4, placeTask)
        add(2, phraseTask)
        return tasks.shuffled()
    }

    /// «Она инженер» → She is an engineer. Ловушка — a вместо an и артикль у множественного
    static func professionTask() -> PolyglotTask? {
        let profession = professions.randomElement()!
        let task = PolyglotLesson3.task(tense: Tense.allCases.randomElement()!, form: Form.allCases.randomElement()!,
                                        subject: PolyglotLesson1.pronouns.randomElement()!,
                                        complement: profession.complement, feminine: Bool.random())
        return withArticleTrap(task, noun: profession.english)
    }

    /// «Я работаю учителем» → I work as a teacher. Кем — as, не in и не at
    static func workAsTask() -> PolyglotTask? {
        let profession = professions.randomElement()!
        let subject = PolyglotLesson1.pronouns.randomElement()!
        let tense = Tense.allCases.randomElement()!
        let form = Form.allCases.randomElement()!
        let plural = subject.pastGender == .plural
        let verb = PolyglotLesson2.work
        let answer = PolyglotLesson2.englishCore(verb: verb, subject: subject.english, thirdPerson: subject.isThirdSingular,
                                                 tense: tense, form: form)
            + ["as"] + (plural ? [profession.plural] : [PolyglotLesson3.article(profession.english), profession.english])
        let russian = subject.russian.capitalizedFirst + " " + (form == .negative ? "не " : "")
            + verb.russian(tense, subject, feminine: Bool.random()) + " "
            + (plural ? profession.instrumentalPlural : profession.instrumental) + (form == .question ? "?" : ".")
        let extra = ["in", "at"] + articleDistractor(answer: answer, noun: profession.english)
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question, tiles: (answer + extra).shuffled())
    }

    /// «Они в школе» → They are at school. С целью — at, не in
    static func placeTask() -> PolyglotTask? {
        let task = PolyglotLesson3.task(tense: Tense.allCases.randomElement()!, form: Form.allCases.randomElement()!,
                                        subject: PolyglotLesson1.pronouns.randomElement()!,
                                        complement: atPlaces.randomElement()!, feminine: Bool.random())
        // Лишние: in вместо at и пара форм to be из урока 3 — без do/does, чтобы карточек не было слишком много
        let extra = ["in"] + task.tiles.filter { !task.answer.contains($0) }.prefix(2)
        return PolyglotTask(russian: task.russian, answer: task.answer, isQuestion: task.isQuestion,
                            tiles: (task.answer + extra).shuffled())
    }

    static func phraseTask() -> PolyglotTask? {
        let phrase = phrases.randomElement()!
        return PolyglotTask(russian: phrase.russian, answer: phrase.answer, isQuestion: phrase.isQuestion,
                            tiles: (phrase.answer + phrase.extra.filter { !phrase.answer.contains($0) }).shuffled())
    }

    /// Карточки урока 3 + ловушка с артиклем: a ↔ an, а у множественного — лишний a
    private static func withArticleTrap(_ task: PolyglotTask, noun: String) -> PolyglotTask {
        let extra = task.tiles.filter { !task.answer.contains($0) }.prefix(2) + articleDistractor(answer: task.answer, noun: noun)
        return PolyglotTask(russian: task.russian, answer: task.answer, isQuestion: task.isQuestion,
                            tiles: (task.answer + extra).shuffled())
    }

    private static func articleDistractor(answer: [String], noun: String) -> [String] {
        let right = PolyglotLesson3.article(noun)
        let wrong = right == "an" ? "a" : "an"
        return [answer.contains(right) ? wrong : right].filter { !answer.contains($0) }
    }
}
