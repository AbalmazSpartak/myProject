import Foundation

/// «Грамматика», урок 12: числа — сколько (twenty-seven, three hundred and five), который (the third),
/// даты (on the fifth of May) и годы (nineteen ninety-nine, two thousand and five)
enum PolyglotLesson12 {
    // MARK: - Раунд: 4 числа, 4 порядковых, 4 даты, 2 года, 1 повторение

    static func round() -> [PolyglotTask] {
        PolyglotRound.build([
            (4, numberTask), (4, ordinalTask), (4, dateTask), (2, yearTask),
            (1, { PolyglotLesson11.task(tense: PolyglotLesson1.Tense.allCases.randomElement()!, form: .affirmative) }),
        ])
    }

    // MARK: - Числа словами

    private static let ones = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
                               "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
    private static let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

    /// До 99 — одним словом через дефис: forty-five
    static func word(_ n: Int) -> String {
        if n < 20 { return ones[n] }
        return n % 10 == 0 ? tens[n / 10] : "\(tens[n / 10])-\(ones[n % 10])"
    }

    /// До 999 — словами по карточкам: three hundred and forty-five
    static func words(_ n: Int) -> [String] {
        guard n >= 100 else { return [word(n)] }
        return [ones[n / 100], "hundred"] + (n % 100 == 0 ? [] : ["and", word(n % 100)])
    }

    /// «345» → three hundred and forty-five. Ловушки: fourty, hundreds, переставленные цифры
    static func numberTask() -> PolyglotTask? {
        let n = Bool.random() ? Int.random(in: 13...99) : Int.random(in: 101...999)
        let answer = words(n)
        let swapped = (n % 10) * 10 + (n / 10 % 10)
        var extra = ["hundreds"]
        if (n % 100) / 10 == 4 { extra.append(word(n % 100).replacingOccurrences(of: "forty", with: "fourty")) }
        else if swapped >= 13, swapped != n % 100 { extra.append(word(swapped)) }
        if n < 100 { extra.append("and") }
        return PolyglotTask(russian: "Число \(n)", answer: answer, isQuestion: false,
                            tiles: (answer + extra.filter { !answer.contains($0) }).shuffled())
    }

    // MARK: - Который по счёту

    /// first, second, third, а дальше -th; fifth, twelfth, twentieth — особые
    static func ordinal(_ n: Int) -> String {
        let special = [1: "first", 2: "second", 3: "third", 5: "fifth", 8: "eighth", 9: "ninth", 12: "twelfth"]
        if let word = special[n] { return word }
        if n < 20 { return ones[n] + "th" }
        if n % 10 == 0 { return String(tens[n / 10].dropLast()) + "ieth" }
        return "\(tens[n / 10])-\(ordinal(n % 10))"
    }

    /// Неправильная форма для ловушки: fiveth, twelveth, twentyth
    private static func wrongOrdinal(_ n: Int) -> String {
        n < 20 ? ones[n] + "th" : (n % 10 == 0 ? tens[n / 10] + "th" : "\(tens[n / 10])-\(ones[n % 10])th")
    }

    /// Русское «который»: третий / третья, по роду существительного
    private static let ordinalsRu: [Int: (masculine: String, feminine: String)] = [
        1: ("первый", "первая"), 2: ("второй", "вторая"), 3: ("третий", "третья"), 4: ("четвёртый", "четвёртая"),
        5: ("пятый", "пятая"), 6: ("шестой", "шестая"), 7: ("седьмой", "седьмая"), 8: ("восьмой", "восьмая"),
        9: ("девятый", "девятая"), 10: ("десятый", "десятая"), 11: ("одиннадцатый", "одиннадцатая"),
        12: ("двенадцатый", "двенадцатая"), 20: ("двадцатый", "двадцатая"),
    ]

    private static let nouns: [(english: String, russian: String, feminine: Bool)] = [
        ("lesson", "урок", false), ("day", "день", false), ("time", "раз", false),
        ("week", "неделя", true), ("book", "книга", true), ("car", "машина", true),
    ]

    /// «Это мой третий урок» → This is my third lesson; «Это первый раз» → This is the first time.
    /// С my, your — без the
    static func ordinalTask() -> PolyglotTask? {
        let n = ordinalsRu.keys.randomElement()!
        let noun = nouns.randomElement()!
        let ordinalRu = noun.feminine ? ordinalsRu[n]!.feminine : ordinalsRu[n]!.masculine
        let owner: (english: String, russian: String)? = noun.english == "time" ? nil
            : [nil, ("my", noun.feminine ? "моя" : "мой"), ("our", noun.feminine ? "наша" : "наш")].randomElement()!
        let answer = ["this", "is", owner?.english ?? "the", ordinal(n), noun.english]
        let russian = "Это \(owner.map { "\($0.russian) " } ?? "")\(ordinalRu) \(noun.russian)."
        let extra = [owner == nil ? "a" : "the", n < 4 ? word(n) : wrongOrdinal(n)].filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Даты: on the fifth of May

    private static let months = [("January", "января"), ("February", "февраля"), ("March", "марта"), ("April", "апреля"),
                                 ("May", "мая"), ("June", "июня"), ("July", "июля"), ("August", "августа"),
                                 ("September", "сентября"), ("October", "октября"), ("November", "ноября"), ("December", "декабря")]

    /// «пятого», «двадцать третьего»
    private static func dayRu(_ n: Int) -> String {
        let genitive = ["", "первого", "второго", "третьего", "четвёртого", "пятого", "шестого", "седьмого", "восьмого",
                        "девятого", "десятого", "одиннадцатого", "двенадцатого", "тринадцатого", "четырнадцатого",
                        "пятнадцатого", "шестнадцатого", "семнадцатого", "восемнадцатого", "девятнадцатого", "двадцатого"]
        if n <= 20 { return genitive[n] }
        if n == 30 { return "тридцатого" }
        return (n < 30 ? "двадцать " : "тридцать ") + genitive[n % 10]
    }

    private static let events: [(english: [String], russian: String)] = [
        (["my", "birthday", "is", "on"], "Мой день рождения"),
        (["the", "meeting", "will", "be", "on"], "Встреча будет"),
        (["we", "came", "on"], "Мы приехали"),
        (["the", "school", "year", "starts", "on"], "Учебный год начинается"),
    ]

    /// «Мой день рождения пятого мая» → My birthday is on the fifth of May
    static func dateTask() -> PolyglotTask? {
        let event = events.randomElement()!
        let monthIndex = Int.random(in: 0..<12)
        let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][monthIndex]
        var day = Int.random(in: 1...days)
        if event.russian == "Учебный год начинается" { day = 1 }
        let month = event.russian == "Учебный год начинается" ? months[8] : months[monthIndex]
        let answer = event.english + ["the", ordinal(day), "of", month.0]
        let russian = "\(event.russian) \(dayRu(day)) \(month.1)."
        let extra = ["in", day < 4 ? word(day) : wrongOrdinal(day), "at"].filter { !answer.contains($0) }
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }

    // MARK: - Годы: nineteen ninety-nine, two thousand and five

    /// Год — парами цифр: 1999 → nineteen ninety-nine, 1905 → nineteen oh five, 2005 → two thousand and five
    static func yearWords(_ year: Int) -> [String] {
        if (2000...2009).contains(year) { return ["two", "thousand"] + (year == 2000 ? [] : ["and", ones[year % 10]]) }
        let first = word(year / 100), last = year % 100
        if last == 0 { return [first, "hundred"] }
        if last < 10 { return [first, "oh", ones[last]] }
        return [first, word(last)]
    }

    private static let bornRu = ["Я родился", "Я родилась", "Она родилась", "Он родился"]

    /// «Я родился в 1999 году» → I was born in nineteen ninety-nine
    static func yearTask() -> PolyglotTask? {
        let year = [Int.random(in: 1950...1999), Int.random(in: 2000...2009), Int.random(in: 2010...2026), 1900, 1905].randomElement()!
        let who = bornRu.randomElement()!
        let subject = who.hasPrefix("Я") ? "I" : who.hasPrefix("Она") ? "she" : "he"
        let answer = [subject, "was", "born", "in"] + yearWords(year)
        let russian = "\(who) в \(year) году."
        let extra = ["on", "thousand", "hundred", "and"].filter { !answer.contains($0) }.shuffled().prefix(2) + (subject == "I" ? ["am"] : ["is"])
        return PolyglotTask(russian: russian, answer: answer, isQuestion: false, tiles: (answer + extra).shuffled())
    }
}
