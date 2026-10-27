import Foundation

/// Правило, по которому слово старой книги отличается от обычного английского. Все шесть — в уроке
/// «Разговорный английский в старых книгах» (BuiltInTopics.colloquialID)
nonisolated enum ColloquialRule: String, CaseIterable, Sendable {
    case aPrefix, regularizedPast, droppedSound, negation, speech, distorted

    var title: String {
        switch self {
        case .aPrefix: "«a-» перед -ing"
        case .regularizedPast: "Неправильный глагол «по правилу»"
        case .droppedSound: "Проглоченный звук"
        case .negation: "Просторечное отрицание"
        case .speech: "Произношение героя"
        case .distorted: "Искажённое слово"
        }
    }
}

/// Разговорная форма в тексте и что она значит
nonisolated struct ColloquialForm: Sendable {
    let rule: ColloquialRule
    /// Как в обычном английском: knew, going, them
    let standard: String
    /// Словарная форма — для перевода и словаря книги; nil — служебное слово (the, and): в словарь из текста не берём
    let lemma: String?
    /// Пояснение к форме: «прошедшее от know»
    let note: String?
}

/// Диалект и просторечие старых книг (Твен и др.). Общие для подсветки в читалке, карточки слова и словаря из книги —
/// чтобы списки не расходились. Только формы, которые обычными словами не бывают: jest («шутка»), kin («родня»),
/// tuck, seed («семя») не трогаем
nonisolated enum ColloquialForms {
    private struct Entry {
        let standard: String
        let lemma: String?
        var note: String? = nil
    }

    /// knowed → knew: -ed у неправильного глагола
    private static let regularizedPast: [String: Entry] = [
        "knowed": Entry(standard: "knew", lemma: "know", note: "прошедшее от know"),
        "catched": Entry(standard: "caught", lemma: "catch", note: "прошедшее от catch"),
        "throwed": Entry(standard: "threw", lemma: "throw", note: "прошедшее от throw"),
        "growed": Entry(standard: "grew", lemma: "grow", note: "прошедшее от grow"),
        "drawed": Entry(standard: "drew", lemma: "draw", note: "прошедшее от draw"),
        "blowed": Entry(standard: "blew", lemma: "blow", note: "прошедшее от blow"),
        "clumb": Entry(standard: "climbed", lemma: "climb", note: "прошедшее от climb"),
        "drownded": Entry(standard: "drowned", lemma: "drown", note: "лишний слог: drown + ded"),
        "hearn": Entry(standard: "heard", lemma: "hear", note: "прошедшее от hear"),
        "riz": Entry(standard: "rose", lemma: "rise", note: "прошедшее от rise"),
        "fotch": Entry(standard: "fetched", lemma: "fetch", note: "прошедшее от fetch"),
    ]

    /// Речь героя «как слышится»: th → d, проглоченные окончания
    private static let speech: [String: Entry] = [
        "de": Entry(standard: "the", lemma: nil), "dat": Entry(standard: "that", lemma: nil),
        "dem": Entry(standard: "them", lemma: nil), "dey": Entry(standard: "they", lemma: nil),
        "dis": Entry(standard: "this", lemma: nil), "dese": Entry(standard: "these", lemma: nil),
        "wid": Entry(standard: "with", lemma: nil), "en": Entry(standard: "and", lemma: nil),
        "uz": Entry(standard: "was", lemma: nil), "wuz": Entry(standard: "was", lemma: nil),
        "heah": Entry(standard: "here", lemma: nil), "dah": Entry(standard: "there", lemma: nil),
        "yo": Entry(standard: "you, your", lemma: nil), "nuffn": Entry(standard: "nothing", lemma: nil),
        "sumfn": Entry(standard: "something", lemma: nil), "bekase": Entry(standard: "because", lemma: nil),
        "kase": Entry(standard: "because", lemma: nil),
        "gwyne": Entry(standard: "going", lemma: "go"), "gwine": Entry(standard: "going", lemma: "go"),
        "sah": Entry(standard: "sir", lemma: "sir"),
    ]

    /// Знакомое слово, записанное по-деревенски
    private static let distorted: [String: Entry] = [
        "agin": Entry(standard: "again", lemma: "again"), "yit": Entry(standard: "yet", lemma: "yet"),
        "jist": Entry(standard: "just", lemma: "just"), "jis": Entry(standard: "just", lemma: "just"),
        "git": Entry(standard: "get", lemma: "get"), "ketch": Entry(standard: "catch", lemma: "catch"),
        "afeard": Entry(standard: "afraid", lemma: "afraid"), "afeared": Entry(standard: "afraid", lemma: "afraid"),
        "hoss": Entry(standard: "horse", lemma: "horse"), "gal": Entry(standard: "girl", lemma: "girl"),
        "critter": Entry(standard: "creature", lemma: "creature"), "cretur": Entry(standard: "creature", lemma: "creature"),
        "widder": Entry(standard: "widow", lemma: "widow"), "yaller": Entry(standard: "yellow", lemma: "yellow"),
        "tobacker": Entry(standard: "tobacco", lemma: "tobacco"), "ruther": Entry(standard: "rather", lemma: "rather"),
        "druther": Entry(standard: "rather", lemma: "rather"), "fust": Entry(standard: "first", lemma: "first"),
        "forgit": Entry(standard: "forget", lemma: "forget"), "resk": Entry(standard: "risk", lemma: "risk"),
        "pison": Entry(standard: "poison", lemma: "poison"), "ole": Entry(standard: "old", lemma: "old"),
        "mos": Entry(standard: "most", lemma: "most"), "las": Entry(standard: "last", lemma: "last"),
        "holt": Entry(standard: "hold", lemma: "hold"), "shet": Entry(standard: "shut", lemma: "shut"),
        "deef": Entry(standard: "deaf", lemma: "deaf"), "wisht": Entry(standard: "wish", lemma: "wish"),
        "considable": Entry(standard: "considerable", lemma: "considerable"),
        "considerble": Entry(standard: "considerable", lemma: "considerable"),
        "generly": Entry(standard: "generally", lemma: "generally"), "skasely": Entry(standard: "scarcely", lemma: "scarcely"),
        "govment": Entry(standard: "government", lemma: "government"),
        "somewheres": Entry(standard: "somewhere", lemma: "somewhere"), "nowheres": Entry(standard: "nowhere", lemma: "nowhere"),
        "anywheres": Entry(standard: "anywhere", lemma: "anywhere"), "everywheres": Entry(standard: "everywhere", lemma: "everywhere"),
        "anyways": Entry(standard: "anyway", lemma: "anyway"), "obleeged": Entry(standard: "obliged", lemma: "oblige"),
        "varmint": Entry(standard: "vermin", lemma: "vermin"),
        "mo": Entry(standard: "more", lemma: nil), "ther": Entry(standard: "there", lemma: nil),
        "fer": Entry(standard: "for", lemma: nil), "sich": Entry(standard: "such", lemma: nil),
        "nuther": Entry(standard: "another", lemma: nil), "arter": Entry(standard: "after", lemma: nil),
        "acrost": Entry(standard: "across", lemma: nil), "behine": Entry(standard: "behind", lemma: nil),
        "ef": Entry(standard: "if", lemma: nil),
    ]

    /// Отрицания целиком, с апострофом
    private static let negations: [String: Entry] = [
        "ain't": Entry(standard: "isn't, am not, haven't", lemma: nil, note: "универсальное «не»"),
        "hain't": Entry(standard: "haven't, isn't", lemma: nil),
        "haint": Entry(standard: "haven't, isn't", lemma: nil),
        "warn't": Entry(standard: "wasn't", lemma: nil),
        "dasn't": Entry(standard: "daren't", lemma: nil, note: "не смеет"),
        "tain't": Entry(standard: "it isn't", lemma: nil),
    ]

    /// Начало слова проглочено: ’em, ’bout
    private static let droppedStart: [String: String] = [
        "em": "them", "bout": "about", "way": "away", "long": "along", "cause": "because", "spose": "suppose",
        "pears": "appears", "round": "around", "fore": "before", "gainst": "against", "cept": "except",
        "member": "remember", "tis": "it is", "twas": "it was",
    ]

    /// Конец слова проглочен: islan’, roun’, kep’
    private static let droppedEnd: [String: String] = [
        "doan": "don't", "ain": "ain't", "lan": "land", "islan": "island", "roun": "round", "aroun": "around",
        "raf": "raft", "kep": "kept", "blame": "blamed", "han": "hand", "fren": "friend", "frien": "friend",
        "ol": "old", "tole": "told", "jes": "just", "mos": "most", "ther": "there", "nex": "next", "las": "last",
        "fur": "for", "mine": "mind", "ole": "old", "behin": "behind", "fo": "for", "befo": "before", "b'fo": "before",
    ]

    // MARK: - Для словаря из текста

    /// Словарная форма: knowed → know, agin → again, gwyne → go
    static func lemma(of word: String) -> String? {
        entry(word.lowercased())?.lemma
    }

    /// Служебное слово в разговорной записи (de — the, en — and): обычные служебные слова из текста не берутся — и эти тоже
    static func isFunctionWord(_ word: String) -> Bool {
        let key = word.lowercased()
        if negations[key] != nil { return true }
        guard let entry = entry(key) else { return false }
        return entry.lemma == nil
    }

    private static func entry(_ key: String) -> Entry? {
        regularizedPast[key] ?? speech[key] ?? distorted[key]
    }

    // MARK: - Для читалки

    /// Разговорная форма слова в тексте. before — знак прямо перед словом, after — до двух знаков сразу после:
    /// по апострофу видно проглоченный звук (goin’, ’em). singleQuotes — в абзаце есть кавычка ‘: тогда ’ после слова —
    /// скорее закрывающая кавычка (‘to the cabin’), а не проглоченный звук
    static func form(_ word: String, before: Character?, after: String, singleQuotes: Bool = false) -> ColloquialForm? {
        let key = word.lowercased().replacingOccurrences(of: "’", with: "'")
        if let negation = negations[key] {
            return ColloquialForm(rule: .negation, standard: negation.standard, lemma: nil, note: negation.note)
        }
        if key.hasPrefix("a-"), key.hasSuffix("ing"), key.count > 5 {
            let standard = String(key.dropFirst(2))
            return ColloquialForm(rule: .aPrefix, standard: standard, lemma: nil, note: "«a-» смысла не меняет")
        }
        let apostrophes: Set<Character> = ["'", "’"]
        let afterFirst = after.first, afterSecond = after.dropFirst().first
        // goin’, nothin’, o’ — звук в конце проглочен
        if !singleQuotes, let afterFirst, apostrophes.contains(afterFirst), !(afterSecond?.isLetter ?? false) {
            if key == "o" { return ColloquialForm(rule: .droppedSound, standard: "of", lemma: nil, note: nil) }
            // a-comin’ — и «a-», и проглоченное g
            if key.hasPrefix("a-"), key.hasSuffix("in"), key.count > 5 {
                return ColloquialForm(rule: .aPrefix, standard: String(key.dropFirst(2)) + "g", lemma: nil,
                                      note: "«a-» смысла не меняет, g в конце проглочено")
            }
            if let standard = droppedEnd[key] {
                return ColloquialForm(rule: .droppedSound, standard: standard, lemma: nil, note: "проглочен звук в конце")
            }
            // wouldn’, didn’ — без t: wouldn’t, didn’t
            if key.hasSuffix("dn") || key.hasSuffix("sn") || key.hasSuffix("ldn") {
                return ColloquialForm(rule: .droppedSound, standard: key + "'t", lemma: nil, note: "проглочено t в n’t")
            }
            if key.hasSuffix("in"), key.count > 3 {
                return ColloquialForm(rule: .droppedSound, standard: key + "g", lemma: nil, note: "проглочено g в -ing")
            }
            if key.count > 2, !key.hasSuffix("s"), entry(key) == nil {
                return ColloquialForm(rule: .droppedSound, standard: key + "…", lemma: nil, note: "проглочен звук в конце")
            }
        }
        // ’em, ’bout — проглочено начало
        if let before, apostrophes.contains(before) {
            if let standard = droppedStart[key] {
                return ColloquialForm(rule: .droppedSound, standard: standard, lemma: nil, note: "проглочено начало слова")
            }
        }
        if let entry = regularizedPast[key] {
            return ColloquialForm(rule: .regularizedPast, standard: entry.standard, lemma: entry.lemma, note: entry.note)
        }
        if let entry = speech[key] {
            return ColloquialForm(rule: .speech, standard: entry.standard, lemma: entry.lemma, note: entry.note)
        }
        if let entry = distorted[key] {
            return ColloquialForm(rule: .distorted, standard: entry.standard, lemma: entry.lemma, note: entry.note)
        }
        return nil
    }
}
