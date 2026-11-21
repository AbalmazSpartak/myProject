import Foundation
import SwiftData

// Тесты логики без экрана: запускаются на компьютере (scripts/run_tests.sh), телефон не нужен.
// Каждая проверка — expect(условие, «что проверяем»); в конце — итог и код выхода.

var passed = 0
var failures: [String] = []

func expect(_ condition: Bool, _ name: String, file: StaticString = #file, line: UInt = #line) {
    if condition { passed += 1 } else { failures.append("\(name) (строка \(line))") }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String, line: UInt = #line) {
    if actual == expected { passed += 1 } else { failures.append("\(name): получено \(actual), ожидалось \(expected) (строка \(line))") }
}

// MARK: - Склонение

expectEqual(RussianPlural.words(1), "1 слово", "1 слово")
expectEqual(RussianPlural.words(2), "2 слова", "2 слова")
expectEqual(RussianPlural.words(5), "5 слов", "5 слов")
expectEqual(RussianPlural.words(11), "11 слов", "11 слов, не «11 слово»")
expectEqual(RussianPlural.words(21), "21 слово", "21 слово")
expectEqual(RussianPlural.words(112), "112 слов", "112 слов")
expectEqual(RussianPlural.cards(1), "1 карточку", "1 карточку")
expectEqual(RussianPlural.cards(3), "3 карточки", "3 карточки")
expectEqual(RussianPlural.cards(12), "12 карточек", "12 карточек")
expectEqual(RussianPlural.cards(0), "0 карточек", "0 карточек")

// MARK: - Режимы приложения

func setFlags(reader: Bool, learning: Bool, mode: String?) {
    let defaults = UserDefaults.standard
    defaults.set(reader, forKey: AppMode.readerOnlyKey)
    defaults.set(learning, forKey: AppMode.learningOnlyKey)
    if let mode { defaults.set(mode, forKey: AppMode.storageKey) } else { defaults.removeObject(forKey: AppMode.storageKey) }
}
setFlags(reader: true, learning: false, mode: "learning")
expect(AppMode.current == .reading, "«Читаем»: всегда читалка, даже если режим был learning")
setFlags(reader: false, learning: true, mode: "reading")
expect(AppMode.current == .learning, "«Учим английский»: всегда обучение")
setFlags(reader: false, learning: false, mode: "reading")
expect(AppMode.current == .reading, "«Читаем и учим»: берётся выбранный режим")
setFlags(reader: false, learning: false, mode: nil)
expect(AppMode.current == .learning, "режим не задан: обучение по умолчанию")
setFlags(reader: true, learning: true, mode: nil)
expect(AppMode.current == .reading, "оба флага сразу: читалка важнее")
setFlags(reader: false, learning: false, mode: nil)

UserDefaults.standard.removeObject(forKey: AppMode.tapTranslationKey)
expect(AppMode.tapTranslationEnabled, "перевод по нажатию включён по умолчанию")
UserDefaults.standard.set(false, forKey: AppMode.tapTranslationKey)
expect(!AppMode.tapTranslationEnabled, "перевод по нажатию можно выключить")
UserDefaults.standard.removeObject(forKey: AppMode.tapTranslationKey)

// MARK: - Транскрипция из словаря

let sample = """
[{"word":"ensnare","phonetics":[
 {"text":"/ɛnˈsnɛə/","audio":""},
 {"text":"/ɛnˈsnɛ(ə)ɹ/","audio":"https://x/en-us.mp3"},
 {"text":"/ɪnˈsneə/","audio":"https://x/en-uk.mp3"}]}]
""".data(using: .utf8)!
expectEqual(TranscriptionLookup.parse(sample) ?? "", "ɪnˈsneə", "британская запись (метка uk) важнее остальных")
let neutral = #"[{"phonetics":[{"text":"/ˈɡlumi/","audio":""},{"text":"/ˈɡluːmi/","audio":"x-us.mp3"}]}]"#.data(using: .utf8)!
expectEqual(TranscriptionLookup.parse(neutral) ?? "", "ˈɡlumi", "без метки uk — запись без метки раньше американской")
let usOnly = #"[{"phonetics":[{"text":"/ˈkjʊəɹɪɒsɪti/","audio":"c-us.mp3"}]}]"#.data(using: .utf8)!
expectEqual(TranscriptionLookup.parse(usOnly) ?? "", "ˈkjʊərɪɒsɪti", "только американская — берём её, знаки как в базе (ɹ → r)")
expect(TranscriptionLookup.parse(#"[{"phonetics":[]}]"#.data(using: .utf8)!) == nil, "нет транскрипции — nil")
expect(TranscriptionLookup.parse(Data("не json".utf8)) == nil, "мусор вместо ответа — nil")
expect(TranscriptionLookup.isLookupable("ensnare"), "слово ищем")
expect(TranscriptionLookup.isLookupable("well-known"), "слово с дефисом ищем")
expect(!TranscriptionLookup.isLookupable("two words"), "фразу с пробелом не ищем")
expect(!TranscriptionLookup.isLookupable("слово"), "русское слово не ищем")
expect(!TranscriptionLookup.isLookupable("a"), "одну букву не ищем")

// MARK: - PDF: страницы → абзацы

let page1 = """
Chapter One
It was a bright cold day in April, and the clocks were striking
thirteen. Winston Smith, his chin nuzzled into his breast in an
effort to escape the vile wind, slipped quickly through the glass
doors of Victory Mansions.
12
The hallway smelled of boiled cabbage and old rag mats. At one end
of it a coloured poster, too large for indoor display, had been tacked
to the wall. It depicted simply an enormous face.
"""
let page2 = """
The face of a man of about forty-five, with a heavy black mous-
tache and ruggedly handsome features.
"""
let paragraphs = PDFBook.paragraphs(from: [page1, page2])
expectEqual(paragraphs.count, 4, "абзацы: заголовок отдельно + три абзаца")
expectEqual(paragraphs.first ?? "", "Chapter One", "короткая строка без точки — заголовок отдельным абзацем")
expect(paragraphs.contains { $0.contains("striking thirteen") }, "строки одного абзаца склеены пробелом")
expect(!paragraphs.contains { $0 == "12" }, "номер страницы отброшен")
expect(paragraphs.contains { $0.contains("moustache") }, "перенос слова по слогам склеен (mous- tache → moustache)")
expect(paragraphs.allSatisfy { !$0.hasPrefix(" ") && !$0.contains("  ") }, "в абзацах нет лишних пробелов")
expect(PDFBook.paragraphs(from: ["", "  \n \n"]).isEmpty, "пустые страницы дают пустой список")

// MARK: - Текст и FB2: разбор книги

let headed = """
Chapter I

First paragraph of the first chapter.

Second paragraph of the first chapter.

Chapter II

Only paragraph of the second chapter.
"""
do {
    let book = try BookParser.parseText(Data(headed.utf8), title: "Test")
    expectEqual(book.chapters.count, 2, "txt с «Chapter»: две главы")
    expectEqual(book.chapters.first?.paragraphs.count ?? 0, 2, "в первой главе два абзаца")
    expectEqual(book.chapters.first?.title ?? "", "Chapter I", "название главы взято из строки Chapter")
} catch { failures.append("parseText с главами упал: \(error)") }

let flat = (1...320).map { "Paragraph number \($0) is here." }.joined(separator: "\n\n")
do {
    let book = try BookParser.parseText(Data(flat.utf8), title: "Flat")
    expectEqual(book.chapters.count, 3, "txt без глав: 320 абзацев → 3 части по 150")
    expect(book.chapters.first?.title.hasPrefix("Часть") == true, "части названы «Часть N»")
} catch { failures.append("parseText без глав упал: \(error)") }

let fb2 = """
<?xml version="1.0" encoding="utf-8"?>
<FictionBook><description><title-info>
<author><first-name>Lewis</first-name><last-name>Carroll</last-name></author>
<book-title>Alice</book-title></title-info></description>
<body>
<section><title><p>Down the Rabbit-Hole</p></title><p>Alice was beginning to get very tired.</p><p>She peeped into the book.</p></section>
<section><title><p>The Pool of Tears</p></title><p>Curiouser and curiouser!</p></section>
</body></FictionBook>
"""
do {
    let book = try BookParser.parseFB2(Data(fb2.utf8), fallbackTitle: "Файл")
    expectEqual(book.title, "Alice", "fb2: название книги")
    expect(book.author.contains("Carroll"), "fb2: автор")
    expectEqual(book.chapters.count, 2, "fb2: две главы")
    expectEqual(book.chapters.first?.title ?? "", "Down the Rabbit-Hole", "fb2: название главы")
    expectEqual(book.chapters.first?.paragraphs.count ?? 0, 2, "fb2: два абзаца в первой главе")
} catch { failures.append("parseFB2 упал: \(error)") }

// MARK: - Закладки и заметки в книге

let parsed = ParsedBook(title: "T", author: "A", cover: nil, chapters: [BookChapter(title: "C", paragraphs: ["p"])])
let book = Book(parsed)
book.notes = [BookNote(paragraph: 9, text: "later", note: "b", location: 4, length: 5),
              BookNote(paragraph: 2, text: "earlier", note: "", location: 0, length: 7)]
expectEqual(book.notes.map(\.paragraph), [2, 9], "заметки хранятся по порядку в книге")
expectEqual(book.notes.last?.location ?? -1, 4, "место заметки в абзаце сохраняется")
expectEqual(book.notes.last?.length ?? -1, 5, "длина выделения сохраняется")
book.bookmarks = [BookBookmark(paragraph: 7, note: "x"), BookBookmark(paragraph: 3)]
expectEqual(book.bookmarks.map(\.paragraph), [3, 7], "закладки по порядку в книге")
book.notes = []
expect(book.notesData == nil, "пустой список заметок — поле очищено")
let oldNote = #"{"id":"11111111-1111-1111-1111-111111111111","paragraph":4,"text":"t","note":"","created":0}"#
expect((try? JSONDecoder().decode(BookNote.self, from: Data(oldNote.utf8)))?.location == nil, "заметка без места (старая) читается, подсветки у неё нет")

// MARK: - Порядок слов книги

func word(_ english: String, state: FSRSState, due: Date) -> Word {
    let item = Word(english: english, russian: "x", example: "<b>\(english)</b>", cefrLevel: "B1", partOfSpeech: "n.", isCustom: true)
    item.state = state
    item.dueDate = due
    return item
}
let now = Date()
let ordered = BookWordOrder.ordered([
    word("later", state: .review, due: now.addingTimeInterval(86_400)),
    word("fresh", state: .new, due: now),
    word("overdue2", state: .review, due: now.addingTimeInterval(-100)),
    word("overdue1", state: .learning, due: now.addingTimeInterval(-5_000)),
], now: now).map(\.english)
expectEqual(Array(ordered.prefix(2)), ["overdue1", "overdue2"], "сначала слова, которым пора: самые давние раньше")
expectEqual(ordered[2], "fresh", "потом новые")
expectEqual(ordered[3], "later", "в конце остальные")
expectEqual(BookWordOrder.ordered([]).count, 0, "пустая книга — пустой список")

// MARK: - Палитра подсветки правил чтения

for set in PhonicsPalette.Variant.allCases {
    let palette = PhonicsPalette.make(set)
    // Текст темы на заливках категорий читается: контраст не ниже 4,5
    for (index, entry) in PhonicsPalette.entries(palette).enumerated() {
        expect(PhonicsPalette.contrast(palette.text, entry.fill) >= 4.5, "\(set): текст на заливке категории \(index) контраст ≥ 4,5")
        // Линия или текст категории видны на фоне темы (≥ 3)
        expect(PhonicsPalette.contrast(palette.background, entry.ink) >= 3.0, "\(set): цвет категории \(index) виден на фоне, контраст ≥ 3")
    }
    expect(PhonicsPalette.contrast(palette.background, palette.silent) >= 4.5, "\(set): немые буквы читаются на фоне, контраст ≥ 4,5")
    // Статусы слов: цвет «учу» и «выучено» виден на фоне темы, они различаются, и читаются поверх заливок правил
    expect(PhonicsPalette.contrast(palette.background, palette.learning) >= 4.5, "\(set): цвет «учу» на фоне, контраст ≥ 4,5")
    expect(PhonicsPalette.contrast(palette.background, palette.learned) >= 4.5, "\(set): цвет «выучено» на фоне, контраст ≥ 4,5")
    expect(palette.learning != palette.learned, "\(set): «учу» и «выучено» разного цвета")
    for (index, entry) in PhonicsPalette.entries(palette).enumerated() {
        expect(PhonicsPalette.contrast(entry.fill, palette.learning) >= 3.0, "\(set): «учу» читается на заливке категории \(index), контраст ≥ 3")
        expect(PhonicsPalette.contrast(entry.fill, palette.learned) >= 3.0, "\(set): «выучено» читается на заливке категории \(index), контраст ≥ 3")
    }
    // Цвета категорий в теме не совпадают
    let inks = PhonicsPalette.entries(palette).map(\.ink)
    expectEqual(Set(inks).count, inks.count, "\(set): у категорий разные цвета")
}

// MARK: - Куски абзацев на странице (быстрый поиск против прямого перебора)

func naivePieces(starts: [Int], lengths: [Int], chars: NSRange) -> [PageSegments.Piece] {
    starts.indices.compactMap { index in
        let from = max(chars.location, starts[index]), to = min(NSMaxRange(chars), starts[index] + lengths[index])
        return to > from ? PageSegments.Piece(paragraph: index, location: from - starts[index], length: to - from) : nil
    }
}
var generator = SystemRandomNumberGenerator()
var pieceMismatches = 0
for _ in 0..<400 {
    let count = Int.random(in: 1...40, using: &generator)
    let lengths = (0..<count).map { _ in Int.random(in: 0...60, using: &generator) }
    var starts: [Int] = []
    var offset = 0
    for length in lengths { starts.append(offset); offset += length + 1 }
    let location = Int.random(in: 0...max(offset - 1, 0), using: &generator)
    let chars = NSRange(location: location, length: Int.random(in: 1...max(offset - location, 1), using: &generator))
    if PageSegments.pieces(starts: starts, lengths: lengths, chars: chars) != naivePieces(starts: starts, lengths: lengths, chars: chars) { pieceMismatches += 1 }
}
expectEqual(pieceMismatches, 0, "быстрый поиск кусков страницы даёт то же, что полный перебор (400 случайных глав)")
expect(PageSegments.pieces(starts: [], lengths: [], chars: NSRange(location: 0, length: 5)).isEmpty, "нет абзацев — нет кусков")

// MARK: - Поиск слова запросом по написанию

do {
    let container = try ModelContainer(for: AppGroup.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    for (english, pos) in [("run", "v."), ("run", "n."), ("April", "n."), ("AI", "n."), ("other", "det.")] {
        context.insert(Word(english: english, russian: "x", example: "<b>\(english)</b>", cefrLevel: "A1", partOfSpeech: pos, isCustom: false))
    }
    try context.save()
    expectEqual(context.words(spelled: ["run"]).count, 2, "слово с двумя частями речи находится обеими строками")
    expectEqual(context.words(spelled: ["Run"]).count, 2, "регистр не важен (Run → run)")
    expectEqual(context.words(spelled: ["april"]).first?.english ?? "", "April", "april → April")
    expectEqual(context.words(spelled: ["ai"]).first?.english ?? "", "AI", "ai → AI")
    expectEqual(context.words(spelled: ["ran", "run"]).count, 2, "несколько написаний сразу (форма и словарная)")
    expect(context.words(spelled: ["zzzz"]).isEmpty, "нет слова — пусто")
} catch { failures.append("поиск слова запросом: \(error)") }

// MARK: - Статусы слов в книге

do {
    let container = try ModelContainer(for: AppGroup.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    let walk = Word(english: "walk", russian: "ходить", example: "<b>walk</b>", cefrLevel: "A1", partOfSpeech: "v.", isCustom: false)
    let known = Word(english: "house", russian: "дом", example: "<b>house</b>", cefrLevel: "A1", partOfSpeech: "n.", isCustom: false)
    let untouched = Word(english: "table", russian: "стол", example: "<b>table</b>", cefrLevel: "A1", partOfSpeech: "n.", isCustom: false)
    let own = Word(english: "gizmo", russian: "штуковина", example: "<b>gizmo</b>", cefrLevel: "C1", partOfSpeech: "n.", isCustom: true)
    for word in [walk, known, untouched, own] { context.insert(word) }
    walk.reps = 1; walk.state = .learning
    known.reps = 3; known.state = .review
    try context.save()
    let snapshot = BookWordStatusSnapshot.make(in: context)
    expect(snapshot.status(surface: "walk", lemma: nil) == .learning, "слово в процессе изучения — «учу»")
    expect(snapshot.status(surface: "House", lemma: nil) == .learned, "слово в повторении — «выучено», регистр не важен")
    expect(snapshot.status(surface: "gizmo", lemma: nil) == .learning, "своё слово без прогресса — «учу»")
    expect(snapshot.status(surface: "table", lemma: nil) == nil, "слово базы без прогресса и словарей — без статуса")
    expect(snapshot.status(surface: "walked", lemma: "walk") == .learning, "форма слова находится по словарной форме")
    expect(snapshot.status(surface: "unknownword", lemma: "unknownword") == nil, "незнакомое слово — без статуса")
    for (form, base) in [("walked", "walk"), ("dogs", "dog"), ("stopped", "stop"), ("studies", "study"), ("making", "make"), ("liked", "like"), ("boxes", "box"), ("carried", "carry")] {
        expect(BookWordStatusSnapshot.baseCandidates(of: form).contains(base), "по окончанию \(form) → \(base)")
    }
    let lemmas = BookWordStatusSnapshot.lemmas(in: "She walked home.")
    expectEqual(lemmas[4] ?? "", "walk", "теггер приводит walked к walk по месту слова в абзаце")
} catch { failures.append("статусы слов: \(error)") }

// MARK: - Дубль или другое издание

do {
    func para(_ i: Int) -> String { "Это достаточно длинный абзац номер \(i) про старый дом и собаку у реки, чтобы пройти порог длины." }
    let original = [BookChapter(title: "1", paragraphs: (0..<40).map(para))]
    let sameWithNoise = [BookChapter(title: "Глава I", paragraphs: ["***", "Заголовок"] + (0..<40).map { para($0).uppercased() + "  " })]
    let otherEdition = [BookChapter(title: "1", paragraphs: (0..<40).map { $0 % 3 == 0 ? "Совсем другой абзац \($0), в нём переведено иначе и сказано по-другому слово в слово." : para($0) })]
    let different = [BookChapter(title: "1", paragraphs: (0..<40).map { "Другая книга и её содержание, абзац \($0), про море, корабли и ветер над волнами." })]
    let a = BookDuplicates.fingerprint(original)
    expectEqual(a.count, 40, "короткие строки вроде *** и заголовков в отпечаток не входят")
    expect(BookDuplicates.similarity(a, BookDuplicates.fingerprint(sameWithNoise)) >= 0.97, "та же книга с другим регистром, пробелами и заголовками — дубль")
    let editionScore = BookDuplicates.similarity(a, BookDuplicates.fingerprint(otherEdition))
    expect(editionScore >= 0.5 && editionScore < 0.97, "часть абзацев другая — другое издание (\(editionScore))")
    expect(BookDuplicates.similarity(a, BookDuplicates.fingerprint(different)) < 0.05, "другая книга — почти нет общего")
    expect(BookDuplicates.verdict(similarity: 0.99, sameTitle: false) == .duplicate, "99% общего — дубль, даже с другим названием")
    expect(BookDuplicates.verdict(similarity: 0.2, sameTitle: true) == .edition, "то же название, но текст другой — другое издание")
    expect(BookDuplicates.verdict(similarity: 0.2, sameTitle: false) == .none, "ничего общего — не дубль")
    // Поиск среди книг библиотеки
    func candidate(_ title: String, _ chapters: [BookChapter]) -> BookDuplicates.Candidate {
        BookDuplicates.Candidate(title: title, author: "", paragraphCount: chapters.reduce(0) { $0 + $1.paragraphs.count },
                                 chaptersData: (try? JSONEncoder().encode(chapters)) ?? Data())
    }
    let library = [candidate("Другая", different), candidate("Дом у реки", original)]
    let found = BookDuplicates.find(ParsedBook(title: "дом у реки!", author: "", cover: nil, chapters: sameWithNoise), among: library)
    expectEqual(found?.index ?? -1, 1, "поиск находит нужную книгу среди нескольких")
    expect(found?.verdict == .duplicate, "и называет её дублем")
    let edition = BookDuplicates.find(ParsedBook(title: "Дом у реки", author: "", cover: nil, chapters: otherEdition), among: library)
    expect(edition?.verdict == .edition, "другое издание того же названия находится как издание")
    expect(BookDuplicates.find(ParsedBook(title: "Новая", author: "", cover: nil, chapters: [BookChapter(title: "1", paragraphs: ["Совсем новый текст про космос и звёзды, которого нет ни у одной книги в списке."])]), among: library) == nil,
           "новая книга без пары — nil")
}

// MARK: - Итог

if failures.isEmpty {
    print("Все проверки прошли: \(passed)")
    exit(0)
} else {
    print("Не прошло \(failures.count) из \(passed + failures.count):")
    failures.forEach { print("  ✗ \($0)") }
    exit(1)
}
