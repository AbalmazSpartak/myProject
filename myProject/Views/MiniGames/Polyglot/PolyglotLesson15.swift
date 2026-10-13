import Foundation

/// «Грамматика», урок 15: there is / there are — «есть, находится» в трёх временах, с вопросом и отрицанием,
/// some / any, a / an и числа. По-русски место впереди («На столе есть книга»), по-английски — в конце
enum PolyglotLesson15 {
    typealias Tense = PolyglotLesson1.Tense
    typealias Form = PolyglotLesson1.Form

    // MARK: - Раунд: 9 по схеме 3 × 3, 3 с числом, 2 «есть = there is, а не have», 1 повторение

    static func round() -> [PolyglotTask] {
        let combos = Tense.allCases.flatMap { tense in Form.allCases.map { (tense, $0) } }
        var index = 0
        return PolyglotRound.build([
            (9, {
                let (tense, form) = combos[index % combos.count]
                index += 1
                return task(tense: tense, form: form)
            }),
            (3, numberTask), (2, { task(tense: .present, form: .affirmative) }),
            (1, { Bool.random() ? PolyglotLesson14.subjectQuestionTask() : PolyglotLesson14.objectQuestionTask() }),
        ])
    }

    private enum Kind { case one, many, mass }

    /// Что где есть: английское, вид (один / много / неисчисляемое), «что?», «чего нет?», род для «был / была», где бывает
    private struct Thing {
        let english: String
        let kind: Kind
        let russian: String
        let genitive: String
        /// был — 0, была — 1, было — 2, были — 3
        let gender: Int
        let places: [String]
    }

    private static let things: [Thing] = [
        Thing(english: "book", kind: .one, russian: "книга", genitive: "книги", gender: 1, places: ["table", "room", "box"]),
        Thing(english: "cat", kind: .one, russian: "кошка", genitive: "кошки", gender: 1, places: ["garden", "kitchen", "bed"]),
        Thing(english: "TV", kind: .one, russian: "телевизор", genitive: "телевизора", gender: 0, places: ["room", "kitchen"]),
        Thing(english: "picture", kind: .one, russian: "картина", genitive: "картины", gender: 1, places: ["wall", "room"]),
        Thing(english: "apple", kind: .one, russian: "яблоко", genitive: "яблока", gender: 2, places: ["table", "fridge", "box"]),
        Thing(english: "chairs", kind: .many, russian: "стулья", genitive: "стульев", gender: 3, places: ["kitchen", "room", "garden"]),
        Thing(english: "apples", kind: .many, russian: "яблоки", genitive: "яблок", gender: 3, places: ["table", "fridge", "box"]),
        Thing(english: "keys", kind: .many, russian: "ключи", genitive: "ключей", gender: 3, places: ["table", "box"]),
        Thing(english: "people", kind: .many, russian: "люди", genitive: "людей", gender: 3, places: ["garden", "room", "kitchen"]),
        Thing(english: "milk", kind: .mass, russian: "молоко", genitive: "молока", gender: 2, places: ["fridge", "kitchen"]),
        Thing(english: "water", kind: .mass, russian: "вода", genitive: "воды", gender: 1, places: ["fridge", "kitchen"]),
        Thing(english: "sugar", kind: .mass, russian: "сахар", genitive: "сахара", gender: 0, places: ["kitchen", "table", "box"]),
    ]

    private static let places: [String: (english: [String], russian: String)] = [
        "table": (["on", "the", "table"], "на столе"),
        "kitchen": (["in", "the", "kitchen"], "на кухне"),
        "fridge": (["in", "the", "fridge"], "в холодильнике"),
        "room": (["in", "the", "room"], "в комнате"),
        "wall": (["on", "the", "wall"], "на стене"),
        "garden": (["in", "the", "garden"], "в саду"),
        "bed": (["under", "the", "bed"], "под кроватью"),
        "box": (["in", "the", "box"], "в коробке"),
    ]

    /// a / an одному, some — многим и неисчисляемому в утверждении, any — в вопросе и отрицании
    private static func quantity(_ thing: Thing, _ form: Form) -> [String] {
        switch thing.kind {
        case .one: return [thing.english.first.map { "aeiou".contains($0) } == true ? "an" : "a"]
        case .many, .mass: return [form == .affirmative ? "some" : "any"]
        }
    }

    /// there is / there are — по тому, что после: один или неисчисляемое — is, много — are
    private static func core(_ thing: Thing, _ tense: Tense, _ form: Form) -> [String] {
        let plural = thing.kind == .many
        switch (tense, form) {
        case (.present, .affirmative): return ["there", plural ? "are" : "is"]
        case (.present, .negative): return ["there", plural ? "aren't" : "isn't"]
        case (.present, .question): return [plural ? "are" : "is", "there"]
        case (.past, .affirmative): return ["there", plural ? "were" : "was"]
        case (.past, .negative): return ["there", plural ? "weren't" : "wasn't"]
        case (.past, .question): return [plural ? "were" : "was", "there"]
        case (.future, .affirmative): return ["there", "will", "be"]
        case (.future, .negative): return ["there", "won't", "be"]
        case (.future, .question): return ["will", "there", "be"]
        }
    }

    static func task(tense: Tense, form: Form) -> PolyglotTask? {
        let thing = things.randomElement()!
        guard let place = places[thing.places.randomElement()!] else { return nil }
        let answer = core(thing, tense, form) + quantity(thing, form) + [thing.english] + place.english

        let where_ = place.russian.capitalizedFirst
        let was = ["был", "была", "было", "были"][thing.gender]
        let russian: String
        switch (tense, form) {
        case (.present, .negative): russian = "\(where_) нет \(thing.genitive)."
        case (.past, .negative): russian = "\(where_) не было \(thing.genitive)."
        case (.future, .negative): russian = "\(where_) не будет \(thing.genitive)."
        case (.present, _): russian = "\(where_) есть \(thing.russian)" + (form == .question ? "?" : ".")
        case (.past, _): russian = "\(where_) \(was) \(thing.russian)" + (form == .question ? "?" : ".")
        case (.future, _): russian = "\(where_) \(thing.gender == 3 ? "будут" : "будет") \(thing.russian)" + (form == .question ? "?" : ".")
        }
        // Ловушки: is ↔ are, some ↔ any, it вместо there и have — по-русски ведь «есть»
        let swapBe = ["is": "are", "are": "is", "was": "were", "were": "was", "isn't": "aren't", "aren't": "isn't",
                      "wasn't": "weren't", "weren't": "wasn't"]
        var extra = [answer.compactMap { swapBe[$0] }.first ?? "have", Bool.random() ? "it" : "have"]
        if thing.kind != .one { extra.append(form == .affirmative ? "any" : "some") }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: form == .question,
                            tiles: (answer + Array(Set(extra)).filter { !answer.contains($0) }).shuffled())
    }

    // MARK: - С числом: «На кухне три стула» → There are three chairs in the kitchen

    private static let counted: [(english: String, forms: [Int: String], places: [String])] = [
        ("chairs", [2: "два стула", 3: "три стула", 5: "пять стульев"], ["kitchen", "room", "garden"]),
        ("apples", [2: "два яблока", 3: "три яблока", 5: "пять яблок"], ["table", "fridge", "box"]),
        ("keys", [2: "два ключа", 3: "три ключа", 5: "пять ключей"], ["table", "box"]),
        ("cats", [2: "две кошки", 3: "три кошки", 5: "пять кошек"], ["garden", "kitchen", "room"]),
        ("pictures", [2: "две картины", 3: "три картины", 5: "пять картин"], ["wall", "room"]),
    ]

    static func numberTask() -> PolyglotTask? {
        let item = counted.randomElement()!
        let n = [2, 3, 5].randomElement()!
        guard let place = places[item.places.randomElement()!] else { return nil }
        let past = Bool.random()
        let answer = ["there", past ? "were" : "are", PolyglotLesson12.word(n), item.english] + place.english
        let russian = "\(place.russian.capitalizedFirst) \(past ? "было" : "—") \(item.forms[n]!)."
            .replacingOccurrences(of: " — ", with: " ")
        let extra = [past ? "was" : "is", "some", "have"]
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }
}
