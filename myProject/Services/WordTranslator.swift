import UIKit
@preconcurrency import Translation

/// Перевод отдельного слова встроенным переводчиком iOS и проверка, можно ли ему верить.
/// Общий для слов из книг и файлов (ScanResultsView) и формы «Добавить слово» в Словаре
enum WordTranslator {
    /// Глагол переводим с «to», иначе переводчик часто выдаёт существительное (run → «бег»)
    static func source(for word: String, partOfSpeech: String) -> String {
        partOfSpeech == "v." && !word.contains(" ") ? "to \(word)" : word
    }

    /// Второй запрос, если первый перевод плохой: глагол — без «to» («to mighty» → «к могуществу»)
    static func retrySource(for source: String) -> String? {
        source.hasPrefix("to ") ? String(source.dropFirst(3)) : nil
    }

    /// Перевод годится: настоящие русские слова, не грубость и не «к …» вместо глагола
    static func isUsable(_ translation: String, source: String) -> Bool {
        guard !looksBroken(translation), !isRude(translation) else { return false }
        return !(source.hasPrefix("to ") && startsWithPreposition(translation))
    }

    /// Что показать у сомнительного перевода: грубость — не показываем вовсе, остальное — чтобы было что исправить
    static func shown(_ translation: String) -> String {
        isRude(translation) ? "" : translation
    }

    /// Одно слово целиком: первый перевод, при плохом — второй; doubtful — оба плохие, перевод надо проверить
    static func translate(_ word: String, partOfSpeech: String = "", session: TranslationSession) async throws
        -> (text: String, doubtful: Bool) {
        let first = source(for: word, partOfSpeech: partOfSpeech)
        let translated = cleaned(try await session.translate(first).targetText)
        if isUsable(translated, source: first) { return (translated, false) }
        // Часть речи неизвестна (форма в Словаре) — второй попыткой пробуем как глагол
        let second = retrySource(for: first) ?? (partOfSpeech.isEmpty && !word.contains(" ") ? "to \(word)" : nil)
        guard let second else { return (shown(translated), true) }
        let retried = cleaned(try await session.translate(second).targetText)
        if isUsable(retried, source: second) { return (retried, false) }
        return (shown(looksBroken(retried) && !looksBroken(translated) ? translated : retried), true)
    }

    // MARK: - Очистка

    /// Скобки по краям — часть перевода: «(сплавной) плот», а не «сплавной) плот»
    private static let trimmedPunctuation = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "()")))

    /// «Маяк.» → «маяк», «чтобы бежать» → «бежать»
    static func cleaned(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: trimmedPunctuation)
        if text.lowercased().hasPrefix("чтобы ") {
            text = String(text.dropFirst("чтобы ".count))
        }
        // Первая буква — строчная, и после скобки: «(сплавной) плот»; аббревиатуры (США) не трогаем
        guard let index = text.firstIndex(where: \.isLetter) else { return text }
        let rest = text[text.index(after: index)...]
        guard rest.contains(where: \.isLowercase) || rest.isEmpty else { return text }
        return text[..<index] + text[index].lowercased() + rest
    }

    // MARK: - Проверки

    private static let prepositions: Set<String> = ["к", "ко", "в", "во", "на", "до", "для", "с", "со"]

    /// Перевод глагола начался с предлога — значит, «to» перевелось как «к», и слово не глагол
    private static func startsWithPreposition(_ translation: String) -> Bool {
        guard let first = translation.split(separator: " ").first, translation.contains(" ") else { return false }
        return prepositions.contains(first.lowercased())
    }

    /// Проверка орфографии русского — находит «переводы» из несуществующих слов: «зарать», «уныливый», «галут»
    private static let russianChecker = UITextChecker()
    private static let russianLanguage = UITextChecker.availableLanguages.first { $0.hasPrefix("ru") }

    /// Перевода по сути нет: латиница («jist») или слово, которого нет в русском языке (транслит, выдуманное)
    static func looksBroken(_ translation: String) -> Bool {
        guard translation.range(of: "[а-яё]", options: [.regularExpression, .caseInsensitive]) != nil else { return true }
        guard let language = russianLanguage else { return false }
        let range = NSRange(location: 0, length: (translation as NSString).length)
        return russianChecker.rangeOfMisspelledWord(in: translation, range: range, startingAt: 0, wrap: false, language: language).location != NSNotFound
    }

    /// Мат, пошлое и оскорбления — по началу слова: переводчик выдаёт их и для обычных слов
    /// (bang → «трахать», jerk → «дрочить», fagged → «пидор»). «Страх», «ожидать» не задеваются
    private static let rude = try? NSRegularExpression(
        pattern: "(?<![а-яё])(трах(?!е[ийяю])|дроч|пидо?р|пидар|шлюх|бляд|бля(?![а-яё])|ху[йяеёи]|пизд|[её]б[аеиоуёлн]|выеб|заеб|наеб|уеб|"
            + "мудак|мудил|залуп|сперм|жоп|задниц|говн|сра[тн]|ссать|перд|сиськ|черномаз|ниггер|ублюд|гомик|педик(?!юр)|сук[аиуе](?![а-яё])|сучк)",
        options: [.caseInsensitive])

    static func isRude(_ translation: String) -> Bool {
        guard let rude else { return false }
        let range = NSRange(location: 0, length: (translation as NSString).length)
        return rude.firstMatch(in: translation, range: range) != nil
    }
}
