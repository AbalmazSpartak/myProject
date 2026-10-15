import Foundation

/// Правила чтения: слово делится на сочетания букв, каждому — звук из словаря произношения,
/// правило, которое его объясняет, и признак «читается не по правилу».
/// Звуки — ARPAbet (как в CMU Pronouncing Dictionary), без знаков ударения при сравнении

/// Вид сочетания — от него цвет подсветки в читалке
nonisolated enum PhonicsKind: String, Sendable, CaseIterable {
    /// Две-три гласные вместе: ee, ea, oa, igh…
    case vowelTeam
    /// Гласная + немая e на конце: make, time, home
    case magicE
    /// Гласная + r: car, bird, more
    case rVowel
    /// Сочетания согласных: th, sh, ch, ph, ck, ng…
    case consonantPair
    /// Окончания: -tion, -ture, -ous…
    case ending
    /// Буквы, которые не читаются
    case silent
    /// Обычная буква по основному правилу
    case plain

    var title: String {
        switch self {
        case .vowelTeam: return "Пары гласных"
        case .magicE: return "Немая e в конце"
        case .rVowel: return "Гласная + r"
        case .consonantPair: return "Пары согласных"
        case .ending: return "Окончания"
        case .silent: return "Немые буквы"
        case .plain: return "Обычные буквы"
        }
    }

    var example: String {
        switch self {
        case .vowelTeam: return "ee, ea, oa, ou, igh"
        case .magicE: return "make, time, home"
        case .rVowel: return "car, bird, more"
        case .consonantPair: return "th, sh, ch, ph, ck"
        case .ending: return "-tion, -ture, -ous"
        case .silent: return "knife, write, light"
        case .plain: return ""
        }
    }
}

/// Сочетание букв и как оно может читаться
nonisolated struct GraphemeRule: Sendable {
    enum Position: Sendable { case any, start, end, notStart }

    let letters: String
    let phones: [String]
    let kind: PhonicsKind
    /// Основное чтение — по правилу; иначе встречается реже, слово помечается как «не по правилу»
    let typical: Bool
    let note: String
    let examples: String
    var position: Position = .any
    /// Только если следующая буква — одна из этих (c и g перед e, i, y)
    var before: String?
    /// Какие буквы сочетания не читаются (по номеру в сочетании); nil — немые все, если звуков нет
    var silent: [Int]?
    /// Откуда такое чтение: греческое, французское…
    var origin: String?
    /// Только для безударного слога: нейтральный звук на месте гласной — по правилу, а под ударением — нет
    var unstressed = false
}

/// Кусок слова после разбора
nonisolated struct PhonicsChunk: Sendable, Identifiable {
    let id: Int
    let letters: String
    /// Номера букв в слове (без апострофов)
    let range: Range<Int>
    let phones: [String]
    var kind: PhonicsKind
    /// Номера немых букв в слове
    var silent: [Int]
    var note: String?
    var examples: String?
    var origin: String?
    /// Читается не по основному правилу
    var irregular: Bool
}

/// Разбор слова целиком
nonisolated struct WordReading: Sendable {
    let word: String
    let chunks: [PhonicsChunk]
    let phones: [String]
    /// Слова нет в словаре произношения — разбор только по правилам
    let isGuess: Bool
    /// Пояснения к слову целиком: исключение, происхождение
    let notes: [String]

    var isException: Bool { chunks.contains { $0.irregular } }
}

nonisolated enum ReadingRules {
    // MARK: - Таблица правил

    /// Правила по первой букве; внутри — длинные сочетания раньше коротких
    static let rules: [Character: [GraphemeRule]] = {
        // Длинные сочетания раньше коротких; при равной длине — в порядке таблицы (основное чтение первым)
        var table: [Character: [(index: Int, rule: GraphemeRule)]] = [:]
        for (index, rule) in all.enumerated() {
            table[rule.letters.first!, default: []].append((index, rule))
        }
        return table.mapValues { entries in
            entries.sorted { ($0.rule.letters.count, -$0.index) > ($1.rule.letters.count, -$1.index) }.map(\.rule)
        }
    }()

    private static func r(_ letters: String, _ phones: String, _ kind: PhonicsKind, _ typical: Bool, _ note: String,
                          _ examples: String = "", at position: GraphemeRule.Position = .any, before: String? = nil,
                          silent: [Int]? = nil, origin: String? = nil, unstressed: Bool = false) -> GraphemeRule {
        GraphemeRule(letters: letters, phones: phones.split(separator: " ").map(String.init), kind: kind, typical: typical,
                     note: note, examples: examples, position: position, before: before, silent: silent, origin: origin,
                     unstressed: unstressed)
    }

    private static let greek = "Слово греческого происхождения — отсюда необычное чтение."
    private static let french = "Слово пришло из французского и сохранило французское чтение."
    private static let oldSilent = "Когда-то эта буква читалась, потом звук исчез, а написание осталось."

    // swiftlint:disable line_length
    static let all: [GraphemeRule] = [
        // Немые буквы
        r("kn", "N", .silent, true, "kn в начале слова — k не читается", "know, knife, knee", at: .start, silent: [0], origin: oldSilent),
        r("wr", "R", .silent, true, "wr в начале слова — w не читается", "write, wrong, wrist", at: .start, silent: [0], origin: oldSilent),
        r("gn", "N", .silent, true, "gn — g не читается", "sign, design, gnome", silent: [0], origin: oldSilent),
        r("mb", "M", .silent, true, "mb на конце — b не читается", "climb, lamb, bomb", at: .end, silent: [1], origin: oldSilent),
        r("mn", "M", .silent, true, "mn на конце — n не читается", "autumn, column", at: .end, silent: [1]),
        r("bt", "T", .silent, true, "bt — b не читается", "debt, doubt, subtle", silent: [0], origin: "b вставили в написание по образцу латинских слов (debitum), но читать её никогда не стали."),
        r("ps", "S", .silent, true, "ps в начале — p не читается", "psychology, pseudo", at: .start, silent: [0], origin: greek),
        r("pn", "N", .silent, true, "pn в начале — p не читается", "pneumonia", at: .start, silent: [0], origin: greek),
        r("rh", "R", .silent, true, "rh — h не читается", "rhythm, rhyme", silent: [1], origin: greek),
        r("wh", "W", .consonantPair, true, "wh — читается как w («у» губами)", "what, when, white"),
        r("wh", "HH", .consonantPair, true, "wh перед o — «х», w не читается", "who, whole, whom", silent: [0]),
        r("lk", "K", .silent, true, "lk после a, o — l не читается", "walk, talk, folk", silent: [0]),
        r("lm", "M", .silent, true, "lm — l не читается", "calm, palm", silent: [0]),
        r("stle", "S AH L", .silent, true, "-stle — t не читается", "castle, whistle", at: .end, silent: [1, 3]),
        r("sten", "S AH N", .silent, true, "-sten — t не читается", "listen, fasten", at: .end, silent: [1]),
        r("ften", "F AH N", .silent, true, "often — t обычно не читается", "often, soften", at: .end, silent: [1]),
        r("gu", "G", .silent, true, "gu перед гласной — u не читается, g твёрдая", "guess, guitar, guide", before: "eiy", silent: [1]),
        r("gh", "", .silent, true, "gh не читается", "night, though, daughter", at: .notStart, origin: "В древнеанглийском gh читался как «х» (как в немецком), потом этот звук исчез."),
        r("gh", "F", .consonantPair, false, "gh читается как «ф»", "laugh, enough, tough, cough"),
        r("gh", "G", .consonantPair, true, "gh в начале — «г»", "ghost, ghetto", at: .start, silent: [1]),
        r("h", "", .silent, false, "h не читается", "hour, honest, heir", at: .start, origin: "Слово пришло из французского, где h не произносится."),
        r("e", "", .silent, true, "e на конце не читается", "make, time, love", at: .end),
        r("e", "", .silent, true, "e здесь не читается (часто перед суффиксами -ly, -ful, -ment)", "lovely, careful, movement", at: .notStart),
        r("w", "", .silent, false, "w не читается", "two, answer, sword"),

        // Пары согласных
        r("tch", "CH", .consonantPair, true, "tch — «ч» после краткой гласной", "watch, catch, kitchen", silent: [0]),
        r("dge", "JH", .consonantPair, true, "dge — «дж», e не читается", "bridge, edge, judge", silent: [0, 2]),
        r("th", "TH", .consonantPair, true, "th — межзубный глухой звук θ: кончик языка между зубами, «с» с выдохом", "think, three, bath"),
        r("th", "DH", .consonantPair, true, "th — межзубный звонкий звук ð: как θ, но с голосом, похож на «з»", "this, the, mother"),
        r("th", "T", .consonantPair, false, "th читается как простое «т»", "Thomas, Thames, thyme"),
        r("sh", "SH", .consonantPair, true, "sh — «ш»", "ship, fish, she"),
        r("ch", "CH", .consonantPair, true, "ch — «ч»", "chair, much, child"),
        r("ch", "K", .consonantPair, false, "ch — «к»", "school, chorus, character", origin: greek),
        r("ch", "SH", .consonantPair, false, "ch — «ш»", "chef, machine, brochure", origin: french),
        r("ph", "F", .consonantPair, true, "ph — «ф»", "phone, photo, alphabet", origin: "ph = «ф» — признак слова греческого происхождения."),
        r("ck", "K", .consonantPair, true, "ck — «к» после краткой гласной", "back, clock, duck"),
        r("ng", "NG", .consonantPair, true, "ng — носовой звук ŋ: «н» задней частью языка, «г» не слышна", "sing, long, king"),
        r("ng", "NG G", .consonantPair, true, "ng в середине слова — ŋ + лёгкое «г»", "finger, English, hungry"),
        r("nk", "NG K", .consonantPair, true, "nk — ŋ + «к»", "think, bank, pink"),
        r("qu", "K W", .consonantPair, true, "qu — «кв»", "queen, quick, question"),
        r("qu", "K", .consonantPair, false, "qu — просто «к»", "unique, queue, technique", origin: french),
        r("que", "K", .ending, false, "-que на конце — «к», ue не читаются", "unique, technique, antique", at: .end, silent: [1, 2], origin: french),
        r("x", "K S", .plain, true, "x — «кс»", "box, six, taxi"),
        r("x", "G Z", .plain, true, "x перед ударной гласной — «гз»", "exam, exact, exist"),
        r("x", "Z", .plain, false, "x в начале — «з»", "xylophone, Xerox", at: .start, origin: greek),
        r("c", "S", .plain, true, "c перед e, i, y — «с»", "city, nice, cycle", before: "eiy"),
        r("c", "K", .plain, true, "c — «к»", "cat, cup, music"),
        r("c", "SH", .plain, false, "c читается как «ш»", "ocean, special, social"),
        r("cc", "K S", .plain, true, "cc перед e, i — «кс»", "accent, success, accident", before: "eiy"),
        r("cc", "K", .plain, true, "cc — «к»", "account, occur"),
        r("g", "JH", .plain, true, "g перед e, i, y часто — «дж»", "gem, giant, gym", before: "eiy"),
        r("g", "G", .plain, true, "g — «г»", "go, big, get"),
        r("g", "ZH", .plain, false, "g — мягкое «ж»", "garage, beige, genre", origin: french),
        r("s", "Z", .plain, true, "s между гласными и на конце после звонких — «з»", "rose, music, dogs"),
        r("s", "S", .plain, true, "s — «с»", "sun, bus, list"),
        r("s", "ZH", .plain, true, "s перед u, ion — мягкое «ж»", "measure, usual, vision"),
        r("s", "SH", .plain, false, "s читается как «ш»", "sure, sugar"),
        r("ss", "SH", .plain, false, "ss — «ш»", "issue, tissue, pressure"),
        r("t", "CH", .plain, true, "t перед u — «ч»", "nature, question, actual"),
        r("t", "SH", .plain, true, "t перед ia, io — «ш»", "patient, initial"),
        r("d", "JH", .plain, true, "d перед u — «дж»", "education, soldier, gradual"),
        r("f", "V", .plain, false, "f в слове of читается как «в»", "of"),
        r("j", "Y", .plain, false, "j — «й»", "hallelujah, fjord"),
        r("z", "ZH", .plain, false, "z — мягкое «ж»", "seizure, azure"),

        // Окончания
        r("tion", "SH AH N", .ending, true, "-tion — «шн»", "nation, station, action"),
        r("tion", "CH AH N", .ending, true, "-tion после s — «чн»", "question, suggestion"),
        r("sion", "ZH AH N", .ending, true, "-sion после гласной — «жн»", "vision, decision, television"),
        r("sion", "SH AH N", .ending, true, "-sion после согласной — «шн»", "mission, tension, passion"),
        r("ssion", "SH AH N", .ending, true, "-ssion — «шн»", "mission, session, passion"),
        r("cian", "SH AH N", .ending, true, "-cian — «шн»", "musician, magician"),
        r("cial", "SH AH L", .ending, true, "-cial — «шл»", "special, social, official"),
        r("tial", "SH AH L", .ending, true, "-tial — «шл»", "partial, initial, essential"),
        r("cious", "SH AH S", .ending, true, "-cious — «шэс»", "delicious, precious"),
        r("tious", "SH AH S", .ending, true, "-tious — «шэс»", "ambitious, cautious"),
        r("ture", "CH ER", .ending, true, "-ture — «чэ(р)»", "picture, nature, future", at: .end, silent: [3]),
        r("sure", "ZH ER", .ending, true, "-sure — «жэ(р)»", "measure, pleasure, treasure", at: .end, silent: [3]),
        r("ous", "AH S", .ending, true, "-ous — «эс»", "famous, dangerous, nervous", at: .end),
        r("le", "AH L", .ending, true, "-le на конце — «л» с коротким призвуком", "table, little, apple", at: .end),
        r("ed", "D", .ending, true, "-ed после звонких — «д»", "played, opened, called", at: .end, silent: [0]),
        r("ed", "T", .ending, true, "-ed после глухих (p, k, s, sh, ch, f) — «т»", "looked, stopped, washed", at: .end, silent: [0]),
        r("ed", "IH D", .ending, true, "-ed после t и d — «ид»", "wanted, needed, started", at: .end),
        r("ed", "AH D", .ending, true, "-ed после t и d — «ид»", "wanted, needed, started", at: .end),
        r("ey", "IY", .vowelTeam, true, "ey на конце — «и»", "key, money, honey", at: .end),
        r("et", "EY", .ending, false, "-et на конце — «эй», t не читается", "ballet, buffet, bouquet", at: .end, silent: [1], origin: french),
        r("ique", "IY K", .ending, false, "-ique — «ик», i читается как «и:»", "unique, technique, antique", at: .end, silent: [2, 3], origin: french),
        r("age", "AA ZH", .ending, false, "-age — «аж»", "garage, massage, collage", at: .end, silent: [2], origin: french),

        // Гласная + r
        r("ar", "AA R", .rVowel, true, "ar — долгое «а:»", "car, star, park"),
        r("ar", "AO R", .rVowel, false, "ar после w — «о:»", "war, warm, quarter"),
        r("ar", "ER", .rVowel, true, "ar без ударения — «э»", "dollar, sugar, collar", unstressed: true),
        r("er", "ER", .rVowel, true, "er — «ё(р)», как в «Пётр»; без ударения — короткое «э»", "her, term, teacher"),
        r("ir", "ER", .rVowel, true, "ir — «ё(р)»", "bird, girl, first"),
        r("ur", "ER", .rVowel, true, "ur — «ё(р)»", "turn, nurse, church"),
        r("or", "AO R", .rVowel, true, "or — долгое «о:»", "for, horse, short"),
        r("or", "ER", .rVowel, false, "or после w или без ударения — «ё(р)»", "word, work, doctor"),
        r("air", "EH R", .rVowel, true, "air — «эа»", "hair, chair, fair"),
        r("are", "EH R", .rVowel, true, "are — «эа»", "care, share, square", silent: [2]),
        r("ear", "IH R", .rVowel, true, "ear — «иа»", "hear, near, year"),
        r("ear", "ER", .rVowel, false, "ear — «ё(р)»", "learn, early, earth"),
        r("ear", "EH R", .rVowel, false, "ear — «эа»", "bear, wear, pear"),
        r("ear", "AA R", .rVowel, false, "ear — «а:»", "heart, hearth"),
        r("eer", "IH R", .rVowel, true, "eer — «иа»", "deer, beer, career"),
        r("ere", "IH R", .rVowel, true, "ere — «иа»", "here, mere", silent: [2]),
        r("ere", "EH R", .rVowel, false, "ere — «эа»", "where, there", silent: [2]),
        r("ire", "AY ER", .rVowel, true, "ire — «айа»", "fire, tired, hire", silent: [2]),
        r("ire", "AY R", .rVowel, true, "ire — «айа»", "fire, tired, hire", silent: [2]),
        r("ore", "AO R", .rVowel, true, "ore — «о:»", "more, store, before", silent: [2]),
        r("oar", "AO R", .rVowel, true, "oar — «о:»", "board, roar, boar"),
        r("oor", "AO R", .rVowel, false, "oor — «о:»", "door, floor"),
        r("oor", "UH R", .rVowel, true, "oor — «уа»", "poor, moor"),
        r("our", "AW ER", .rVowel, true, "our — «ауэ»", "our, hour, sour"),
        r("our", "AW R", .rVowel, true, "our — «ауэ»", "our, hour, flour"),
        r("our", "AO R", .rVowel, false, "our — «о:»", "four, your, course"),
        r("our", "ER", .rVowel, false, "our — «ё(р)»", "journey, journal, colour"),
        r("ure", "Y UH R", .rVowel, true, "ure — «юа»", "pure, cure", silent: [2]),
        r("ure", "Y ER", .rVowel, true, "ure — «юа»", "pure, cure", silent: [2]),
        r("ure", "UH R", .rVowel, true, "ure — «уа»", "sure, assure", silent: [2]),

        // Пары гласных
        r("eigh", "EY", .vowelTeam, true, "eigh — «эй», gh не читается", "eight, weigh, neighbour", silent: [2, 3]),
        r("igh", "AY", .vowelTeam, true, "igh — «ай», gh не читается", "light, night, high", silent: [1, 2]),
        r("augh", "AO", .vowelTeam, true, "augh — «о:», gh не читается", "caught, daughter, taught", silent: [2, 3]),
        r("augh", "AE F", .vowelTeam, false, "augh — «а:ф»", "laugh, laughter"),
        r("ough", "AO", .vowelTeam, true, "ough — «о:»", "thought, bought, brought", silent: [2, 3]),
        r("ough", "OW", .vowelTeam, false, "ough — «оу»", "though, dough", silent: [2, 3]),
        r("ough", "UW", .vowelTeam, false, "ough — «у:»", "through", silent: [2, 3]),
        r("ough", "AH F", .vowelTeam, false, "ough — «аф»", "tough, enough, rough"),
        r("ough", "AO F", .vowelTeam, false, "ough — «оф»", "cough, trough"),
        r("ough", "AW", .vowelTeam, false, "ough — «ау»", "bough, plough", silent: [2, 3]),
        r("ough", "AH", .vowelTeam, false, "ough — короткое «э»", "borough, thorough", silent: [2, 3]),
        r("eau", "OW", .vowelTeam, false, "eau — «оу»", "plateau, bureau", origin: french),
        r("eau", "Y UW", .vowelTeam, false, "eau — «ю:»", "beauty, beautiful", origin: french),
        r("ee", "IY", .vowelTeam, true, "ee — долгое «и:»", "see, tree, green"),
        r("ea", "IY", .vowelTeam, true, "ea — долгое «и:»", "sea, eat, read"),
        r("ea", "EH", .vowelTeam, false, "ea — короткое «э»", "head, bread, weather"),
        r("ea", "EY", .vowelTeam, false, "ea — «эй»", "great, break, steak"),
        r("ai", "EY", .vowelTeam, true, "ai — «эй»", "rain, wait, train"),
        r("ai", "EH", .vowelTeam, false, "ai — короткое «э»", "said, again"),
        r("ay", "EY", .vowelTeam, true, "ay — «эй»", "day, play, say"),
        r("oa", "OW", .vowelTeam, true, "oa — «оу»", "boat, road, coat"),
        r("oe", "OW", .vowelTeam, true, "oe — «оу»", "toe, goes, Joe"),
        r("oe", "UW", .vowelTeam, false, "oe — «у:»", "shoe, canoe"),
        r("oo", "UW", .vowelTeam, true, "oo — долгое «у:»", "moon, food, school"),
        r("oo", "UH", .vowelTeam, true, "oo — короткое «у»", "book, good, look"),
        r("oo", "AH", .vowelTeam, false, "oo — короткое «а»", "blood, flood"),
        r("ou", "AW", .vowelTeam, true, "ou — «ау»", "out, house, mouth"),
        r("ou", "UW", .vowelTeam, false, "ou — долгое «у:»", "soup, group, you", origin: french),
        r("ou", "AH", .vowelTeam, false, "ou — короткое «а»", "touch, young, country"),
        r("ou", "UH", .vowelTeam, false, "ou — короткое «у»", "could, would, should"),
        r("ou", "OW", .vowelTeam, false, "ou — «оу»", "soul, shoulder"),
        r("ow", "AW", .vowelTeam, true, "ow — «ау»", "cow, now, town"),
        r("ow", "OW", .vowelTeam, true, "ow — «оу»", "snow, know, slow"),
        r("oi", "OY", .vowelTeam, true, "oi — «ой»", "oil, coin, voice"),
        r("oy", "OY", .vowelTeam, true, "oy — «ой»", "boy, toy, enjoy"),
        r("au", "AO", .vowelTeam, true, "au — долгое «о:»", "August, cause, autumn"),
        r("aw", "AO", .vowelTeam, true, "aw — долгое «о:»", "saw, draw, law"),
        r("ew", "UW", .vowelTeam, true, "ew — «у:»", "new, flew, grew"),
        r("ew", "Y UW", .vowelTeam, true, "ew — «ю:»", "few, new, view"),
        r("ue", "UW", .vowelTeam, true, "ue — «у:»", "blue, true, glue"),
        r("ue", "Y UW", .vowelTeam, true, "ue — «ю:»", "due, value, rescue"),
        r("ui", "UW", .vowelTeam, true, "ui — «у:»", "fruit, juice, suit"),
        r("ui", "IH", .vowelTeam, false, "ui — короткое «и»", "build, guilt, biscuit"),
        r("ie", "IY", .vowelTeam, true, "ie — «и:»", "field, piece, believe"),
        r("ie", "AY", .vowelTeam, true, "ie на конце — «ай»", "pie, tie, lie"),
        r("ei", "EY", .vowelTeam, true, "ei — «эй»", "vein, rein"),
        r("ei", "IY", .vowelTeam, true, "ei после c — «и:» (правило «i перед e, кроме как после c»)", "receive, ceiling, seize"),
        r("ei", "AY", .vowelTeam, false, "ei — «ай»", "height, either"),
        r("ey", "EY", .vowelTeam, true, "ey — «эй»", "they, grey, obey"),
        r("uy", "AY", .vowelTeam, false, "uy — «ай»", "buy, guy"),

        // Одиночные гласные
        r("a", "AE", .plain, true, "a в закрытом слоге — «э» (широкий рот, между «а» и «э»)", "cat, map, bag"),
        r("a", "EY", .plain, true, "a в открытом слоге — «эй», как в алфавите", "name, table, paper"),
        r("a", "AA", .plain, true, "a — долгое «а:»", "father, bath, calm"),
        r("a", "AO", .plain, true, "a перед l — «о:»", "all, ball, talk"),
        r("a", "AH", .plain, true, "a без ударения — короткий нейтральный звук «э/а»", "about, banana, sofa", unstressed: true),
        r("a", "IH", .plain, true, "a без ударения — короткое «и»", "village, private, orange", unstressed: true),
        r("a", "EH", .plain, false, "a — короткое «э»", "any, many, Thames"),
        r("e", "EH", .plain, true, "e в закрытом слоге — «э»", "bed, pen, ten"),
        r("e", "IY", .plain, true, "e в открытом слоге — «и:», как в алфавите", "me, she, these"),
        r("e", "IH", .plain, true, "e без ударения — короткое «и»", "begin, decide, wanted", unstressed: true),
        r("e", "AH", .plain, true, "e без ударения — короткий нейтральный звук", "open, problem, the", unstressed: true),
        r("i", "IH", .plain, true, "i в закрытом слоге — короткое «и»", "sit, big, film"),
        r("i", "AY", .plain, true, "i в открытом слоге — «ай», как в алфавите", "time, kind, find"),
        r("i", "IY", .plain, false, "i — долгое «и:»", "machine, police, pizza", origin: "Чтение i как «и:» пришло вместе со словом из французского или итальянского."),
        r("i", "AH", .plain, true, "i без ударения — короткий нейтральный звук", "family, possible", unstressed: true),
        r("o", "AA", .plain, true, "o в закрытом слоге — «о/а» (короткое, в американском ближе к «а»)", "hot, dog, stop"),
        r("o", "OW", .plain, true, "o в открытом слоге — «оу», как в алфавите", "go, home, open"),
        r("o", "AO", .plain, true, "o — «о:»", "long, dog, cost"),
        r("o", "AH", .plain, true, "o без ударения — короткий нейтральный звук", "today, second, lemon", unstressed: true),
        r("o", "AH", .plain, false, "o — короткое «а»", "son, love, come, mother"),
        r("o", "UW", .plain, false, "o — «у:»", "do, to, who, move"),
        r("o", "UH", .plain, false, "o — короткое «у»", "woman, wolf"),
        r("o", "IH", .plain, false, "o — короткое «и»", "women"),
        r("o", "W AH", .plain, false, "o читается как «уа» — уникальное чтение", "one, once"),
        r("u", "AH", .plain, true, "u в закрытом слоге — короткое «а»", "cup, sun, but"),
        r("u", "UW", .plain, true, "u — «у:»", "rule, June, flu"),
        r("u", "Y UW", .plain, true, "u в открытом слоге — «ю:», как в алфавите", "use, music, cute"),
        r("u", "UH", .plain, true, "u — короткое «у»", "put, full, push"),
        r("u", "Y AH", .plain, true, "u без ударения — «йэ»", "popular, regular", unstressed: true),
        r("u", "IH", .plain, false, "u — короткое «и»", "busy, business, minute"),
        r("u", "EH", .plain, false, "u — «э»", "bury"),
        r("y", "IY", .plain, true, "y на конце многосложного слова — «и»", "happy, city, baby"),
        r("y", "AY", .plain, true, "y под ударением — «ай»", "my, fly, type"),
        r("y", "IH", .plain, false, "y в середине слова — короткое «и»", "gym, myth, system", origin: greek),
        r("y", "Y", .plain, true, "y перед гласной — «й»", "yes, you, year"),

        // Двойные согласные — один звук
        r("ll", "L", .plain, true, "двойная буква читается как одна", "ball, tell"),
        r("ss", "S", .plain, true, "двойная буква читается как одна", "class, miss"),
        r("ss", "Z", .plain, false, "ss — «з»", "scissors, possess"),
        r("tt", "T", .plain, true, "двойная буква читается как одна", "letter, better"),
        r("ff", "F", .plain, true, "двойная буква читается как одна", "off, coffee"),
        r("pp", "P", .plain, true, "двойная буква читается как одна", "happy, apple"),
        r("rr", "R", .plain, true, "двойная буква читается как одна", "sorry, carry"),
        r("mm", "M", .plain, true, "двойная буква читается как одна", "summer"),
        r("nn", "N", .plain, true, "двойная буква читается как одна", "dinner"),
        r("dd", "D", .plain, true, "двойная буква читается как одна", "add, middle"),
        r("bb", "B", .plain, true, "двойная буква читается как одна", "rabbit"),
        r("gg", "G", .plain, true, "двойная буква читается как одна", "egg, bigger"),
        r("zz", "Z", .plain, true, "двойная буква читается как одна", "pizza, buzz"),

        // Одиночные согласные
        r("b", "B", .plain, true, "b — «б»", "bed"),
        r("d", "D", .plain, true, "d — «д»", "dog"),
        r("d", "T", .plain, true, "d после глухих в -ed — «т»", "looked"),
        r("f", "F", .plain, true, "f — «ф»", "fish"),
        r("h", "HH", .plain, true, "h — лёгкий выдох «х»", "hat"),
        r("j", "JH", .plain, true, "j — «дж»", "job"),
        r("k", "K", .plain, true, "k — «к»", "kid"),
        r("l", "L", .plain, true, "l — «л»", "leg"),
        r("m", "M", .plain, true, "m — «м»", "man"),
        r("n", "N", .plain, true, "n — «н»", "net"),
        r("n", "NG", .plain, true, "n перед k, g — носовое ŋ", "bank, think, English"),
        r("p", "P", .plain, true, "p — «п»", "pen"),
        r("q", "K", .plain, true, "q — «к»", "Iraq"),
        r("r", "R", .plain, true, "r — английское «р»: язык не вибрирует", "red"),
        r("t", "T", .plain, true, "t — «т»", "top"),
        r("v", "V", .plain, true, "v — «в»", "van"),
        r("w", "W", .plain, true, "w — губами «у», быстро в следующую гласную", "we"),
        r("z", "Z", .plain, true, "z — «з»", "zoo"),
    ]
    // swiftlint:enable line_length

    // MARK: - Разбор слова

    /// Буквы слова для разбора: только латиница, в нижнем регистре
    private static func letters(of word: String) -> [Character] {
        word.lowercased().filter { $0.isASCII && $0.isLetter }
    }

    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]

    /// Разбор слова: по словарю произношения, а если слова там нет — только по правилам
    static func reading(for word: String) -> WordReading? {
        let chars = letters(of: word)
        guard chars.count >= 1, chars.count <= 30 else { return nil }
        let dictionaryKey = word.lowercased().replacingOccurrences(of: "’", with: "'")
        if let phones = PronunciationDictionary.shared.phones(for: dictionaryKey) ?? PronunciationDictionary.shared.phones(for: String(chars)),
           var chunks = align(chars, phones) {
            markMagicE(&chunks, chars)
            return WordReading(word: word, chunks: chunks, phones: phones, isGuess: false, notes: wordNotes(String(chars), chunks))
        }
        var chunks = guess(chars)
        markMagicE(&chunks, chars)
        return WordReading(word: word, chunks: chunks, phones: chunks.flatMap(\.phones), isGuess: true, notes: wordNotes(String(chars), chunks))
    }

    /// Звук без знака ударения: AY1 → AY
    static func base(_ phone: String) -> String {
        phone.filter { !$0.isNumber }
    }

    private static func fits(_ rule: GraphemeRule, _ chars: [Character], at i: Int) -> Bool {
        let n = rule.letters.count
        guard i + n <= chars.count, String(chars[i..<(i + n)]) == rule.letters else { return false }
        switch rule.position {
        case .start: if i != 0 { return false }
        case .end: if i + n != chars.count { return false }
        case .notStart: if i == 0 { return false }
        case .any: break
        }
        if let before = rule.before {
            guard i + n < chars.count, before.contains(chars[i + n]) else { return false }
        }
        return true
    }

    private struct Step {
        let fromI: Int
        let fromJ: Int
        let rule: GraphemeRule?
        let letters: Int
        let phones: Int
    }

    /// Выравнивание букв со звуками: минимальная «цена» — меньше кусков, основные правила дешевле редких,
    /// неизвестное соответствие буквы и звука — дорого (так слово и попадает в исключения)
    private static func align(_ chars: [Character], _ raw: [String]) -> [PhonicsChunk]? {
        let phones = raw.map(base)
        let n = chars.count, m = phones.count
        let infinity = Int.max / 4
        var cost = Array(repeating: Array(repeating: infinity, count: m + 1), count: n + 1)
        var back = Array(repeating: Array(repeating: Step?.none, count: m + 1), count: n + 1)
        cost[0][0] = 0

        for i in 0...n {
            for j in 0...m where cost[i][j] < infinity {
                let current = cost[i][j]
                func relax(_ ni: Int, _ nj: Int, _ add: Int, _ step: Step) {
                    if current + add < cost[ni][nj] {
                        cost[ni][nj] = current + add
                        back[ni][nj] = step
                    }
                }
                if i < n {
                    for rule in rules[chars[i]] ?? [] where fits(rule, chars, at: i) {
                        let k = rule.phones.count
                        guard j + k <= m, Array(phones[j..<(j + k)]) == rule.phones else { continue }
                        // Нейтральный звук «по правилу» — только без ударения
                        if rule.unstressed, raw[j..<(j + k)].contains(where: { $0.hasSuffix("1") || $0.hasSuffix("2") }) { continue }
                        // Немая буква по правилу чуть дороже читаемой — иначе «молчание» перетягивает чужие звуки
                        let price = (rule.typical ? 10 : 14) + (k == 0 && rule.letters.count == 1 ? 3 : 0)
                        relax(i + rule.letters.count, j + k, price,
                              Step(fromI: i, fromJ: j, rule: rule, letters: rule.letters.count, phones: k))
                    }
                    // Неизвестное соответствие: буква — любой звук, или буква не читается
                    if j < m { relax(i + 1, j + 1, 46, Step(fromI: i, fromJ: j, rule: nil, letters: 1, phones: 1)) }
                    relax(i + 1, j, 45, Step(fromI: i, fromJ: j, rule: nil, letters: 1, phones: 0))
                }
                // Лишний звук без буквы — прицепляется к предыдущему куску
                if j < m, i > 0 { relax(i, j + 1, 50, Step(fromI: i, fromJ: j, rule: nil, letters: 0, phones: 1)) }
            }
        }
        guard cost[n][m] < infinity else { return nil }

        var steps: [Step] = []
        var i = n, j = m
        while i > 0 || j > 0 {
            guard let step = back[i][j] else { return nil }
            steps.append(step)
            i = step.fromI
            j = step.fromJ
        }
        steps.reverse()

        var chunks: [PhonicsChunk] = []
        for step in steps {
            let stepPhones = Array(raw[step.fromJ..<(step.fromJ + step.phones)])
            if step.letters == 0 {
                // Лишний звук — к предыдущему куску, он становится «не по правилу»
                guard var last = chunks.popLast() else { continue }
                last = PhonicsChunk(id: last.id, letters: last.letters, range: last.range, phones: last.phones + stepPhones,
                                    kind: last.kind, silent: last.silent, note: last.note, examples: last.examples,
                                    origin: last.origin, irregular: true)
                chunks.append(last)
                continue
            }
            let range = step.fromI..<(step.fromI + step.letters)
            chunks.append(chunk(id: chunks.count, chars: chars, range: range, phones: stepPhones, rule: step.rule))
        }
        return chunks
    }

    private static func chunk(id: Int, chars: [Character], range: Range<Int>, phones: [String], rule: GraphemeRule?) -> PhonicsChunk {
        let letters = String(chars[range])
        guard let rule else {
            let silent = phones.isEmpty ? Array(range) : []
            let note = phones.isEmpty ? "\(letters) здесь не читается" : "\(letters) здесь читается как «\(russian(phones))» — не по основному правилу"
            return PhonicsChunk(id: id, letters: letters, range: range, phones: phones, kind: phones.isEmpty ? .silent : .plain,
                                silent: silent, note: note, examples: nil, origin: nil, irregular: true)
        }
        let silent: [Int]
        if let marks = rule.silent {
            silent = marks.map { range.lowerBound + $0 }
        } else {
            silent = phones.isEmpty ? Array(range) : []
        }
        return PhonicsChunk(id: id, letters: letters, range: range, phones: phones, kind: rule.kind, silent: silent,
                            note: rule.note, examples: rule.examples.isEmpty ? nil : rule.examples, origin: rule.origin,
                            irregular: !rule.typical)
    }

    /// Без словаря: самые длинные сочетания с основным чтением
    private static func guess(_ chars: [Character]) -> [PhonicsChunk] {
        var chunks: [PhonicsChunk] = []
        var i = 0
        while i < chars.count {
            let rule = (rules[chars[i]] ?? []).first { $0.typical && fits($0, chars, at: i) }
                ?? (rules[chars[i]] ?? []).first { fits($0, chars, at: i) }
            let length = rule?.letters.count ?? 1
            chunks.append(chunk(id: chunks.count, chars: chars, range: i..<(i + length), phones: rule?.phones ?? [], rule: rule))
            i += length
        }
        return chunks
    }

    /// Гласная — согласная — немая e на конце: гласная читается как в алфавите (make, time, home).
    /// Если гласная при этом краткая (have, give, love) — это исключение
    private static func markMagicE(_ chunks: inout [PhonicsChunk], _ chars: [Character]) {
        guard chunks.count >= 3 else { return }
        var e = chunks.count - 1
        // makes, timed: e перед s/d на конце
        if ["s", "d"].contains(chunks[e].letters), e >= 3 { e -= 1 }
        guard chunks[e].letters == "e", chunks[e].phones.isEmpty else { return }
        let consonant = chunks[e - 1]
        guard !consonant.letters.contains(where: { vowels.contains($0) && $0 != "y" }), consonant.letters.count <= 2 else { return }
        let vowelIndex = e - 2
        let vowel = chunks[vowelIndex]
        guard vowel.letters.count == 1, let letter = vowel.letters.first, vowels.contains(letter) else { return }
        let long: [Character: [[String]]] = ["a": [["EY"]], "e": [["IY"]], "i": [["AY"]], "y": [["AY"]], "o": [["OW"]], "u": [["UW"], ["Y", "UW"]]]
        let sounds = vowel.phones.map(base)
        let example = "make, time, home, cute"
        if long[letter]?.contains(sounds) == true {
            chunks[vowelIndex].kind = .magicE
            chunks[vowelIndex].note = "\(letter)…e: немая e на конце делает гласную «длинной» — она читается как в алфавите"
            chunks[vowelIndex].examples = example
            chunks[e].kind = .magicE
            chunks[e].note = "e на конце не читается, но меняет чтение гласной перед согласной"
            chunks[e].examples = example
        } else {
            chunks[vowelIndex].irregular = true
            chunks[vowelIndex].note = "Здесь e на конце не меняет гласную — исключение из правила немой e"
            chunks[vowelIndex].examples = "have, give, love, come, done"
            chunks[e].kind = .silent
        }
    }

    /// Пояснения к слову: запомненные исключения и происхождение
    private static func wordNotes(_ word: String, _ chunks: [PhonicsChunk]) -> [String] {
        var notes: [String] = []
        if let note = ReadingNotes.words[word] { notes.append(note) }
        for origin in Set(chunks.compactMap(\.origin)) where !notes.contains(origin) {
            notes.append(origin)
        }
        if word.contains("ough") {
            notes.append("ough — самое непредсказуемое сочетание: though «оу», through «у:», tough «аф», thought «о:», cough «оф». Его чтение запоминают со словом.")
        }
        return notes
    }

    /// Как сочетание читается обычно — по основному правилу, звуком по-русски; nil — правила нет
    static func usualReading(of letters: String) -> String? {
        if let vowel = usualVowel[letters] { return vowel }
        guard let first = letters.first,
              let rule = rules[first]?.first(where: { $0.letters == letters && $0.typical && !$0.phones.isEmpty && !$0.unstressed })
        else { return nil }
        // Звуки правила — без ударения; показываем полное звучание гласных, без знака ударения
        let stressed = rule.phones.map { russianSound[$0] != nil && "AEIOU".contains($0.first!) ? $0 + "1" : $0 }
        return russian(stressed).replacingOccurrences(of: "\u{301}", with: "")
    }

    /// Одиночная гласная читается двумя основными способами: в закрытом и в открытом слоге
    private static let usualVowel: [String: String] = [
        "a": "э / эй", "e": "э / и:", "i": "и / ай", "o": "о / оу", "u": "а / ю:", "y": "и / ай",
    ]

    // MARK: - Звуки по-русски и в транскрипции

    /// Примерное звучание по-русски; ударный гласный — с ударением
    static func russian(_ phones: [String]) -> String {
        phones.map { phone -> String in
            let base = base(phone)
            let stressed = phone.hasSuffix("1")
            var text = russianSound[base] ?? base.lowercased()
            if base == "AH", !stressed { text = "э" }
            if base == "ER", !stressed { text = "э" }
            if base == "IY", phone.hasSuffix("0") { text = "и" }
            if stressed, let index = text.firstIndex(where: { "аэоуыиеёюяй".contains($0) }), text.count <= 3 {
                text.insert("\u{301}", at: text.index(after: index))
            }
            return text
        }.joined()
    }

    private static let russianSound: [String: String] = [
        "AA": "а:", "AE": "э", "AH": "а", "AO": "о:", "AW": "ау", "AY": "ай", "EH": "э", "ER": "ё:", "EY": "эй",
        "IH": "и", "IY": "и:", "OW": "оу", "OY": "ой", "UH": "у", "UW": "у:",
        "B": "б", "CH": "ч", "D": "д", "DH": "ð", "F": "ф", "G": "г", "HH": "х", "JH": "дж", "K": "к", "L": "л",
        "M": "м", "N": "н", "NG": "ŋ", "P": "п", "R": "р", "S": "с", "SH": "ш", "T": "т", "TH": "θ", "V": "в",
        "W": "w", "Y": "й", "Z": "з", "ZH": "ж",
    ]

    /// Транскрипция (американский вариант из CMU): ARPAbet → IPA
    static func ipa(_ phones: [String]) -> String {
        phones.map { phone -> String in
            let base = base(phone)
            if base == "AH" { return phone.hasSuffix("0") ? "ə" : "ʌ" }
            if base == "ER" { return phone.hasSuffix("0") ? "ɚ" : "ɜːr" }
            return ipaSound[base] ?? base.lowercased()
        }.joined()
    }

    private static let ipaSound: [String: String] = [
        "AA": "ɑː", "AE": "æ", "AO": "ɔː", "AW": "aʊ", "AY": "aɪ", "EH": "e", "EY": "eɪ", "IH": "ɪ", "IY": "iː",
        "OW": "oʊ", "OY": "ɔɪ", "UH": "ʊ", "UW": "uː",
        "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f", "G": "ɡ", "HH": "h", "JH": "dʒ", "K": "k", "L": "l",
        "M": "m", "N": "n", "NG": "ŋ", "P": "p", "R": "r", "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "V": "v",
        "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
    ]

    // MARK: - Подсветка в тексте

    /// Что подсветить в слове: куски по виду, немые буквы, слово-исключение. Диапазоны — в UTF-16 слова
    nonisolated struct Highlight: Sendable {
        var spans: [(range: NSRange, kind: PhonicsKind, irregular: Bool)] = []
        var silent: [NSRange] = []
        var isException = false
    }

    /// level: tricky — гласные, немые буквы и исключения; all — ещё согласные и окончания
    static func highlight(_ word: String, all: Bool) -> Highlight? {
        guard let reading = reading(for: word) else { return nil }
        // Номер буквы (без апострофов) → место в строке
        var offsets: [Int] = []
        var utf16 = 0
        for character in word {
            if character.isASCII, character.isLetter { offsets.append(utf16) }
            utf16 += character.utf16.count
        }
        guard offsets.count == reading.chunks.last?.range.upperBound ?? 0 else { return nil }

        var result = Highlight()
        // В сокращениях (didn't, I'll) звук без буквы — от апострофа, это не исключение
        let contraction = word.contains("'") || word.contains("’")
        let exceptions = !reading.isGuess && !contraction
        result.isException = reading.isException && exceptions
        for chunk in reading.chunks {
            let irregular = chunk.irregular && exceptions
            let shown: Bool
            switch chunk.kind {
            case .vowelTeam, .magicE, .rVowel: shown = true
            case .consonantPair, .ending: shown = all || irregular
            case .silent, .plain: shown = irregular
            }
            if shown {
                let start = offsets[chunk.range.lowerBound]
                let end = offsets[chunk.range.upperBound - 1] + 1
                result.spans.append((NSRange(location: start, length: end - start), chunk.kind, irregular))
            }
            for index in chunk.silent where index < offsets.count {
                result.silent.append(NSRange(location: offsets[index], length: 1))
            }
        }
        return result
    }
}
