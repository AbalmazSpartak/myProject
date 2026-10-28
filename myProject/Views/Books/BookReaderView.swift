import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Слово, на которое нажали в книге, и предложение вокруг него
struct TappedWord: Identifiable {
    let id = UUID()
    let word: String
    let sentence: String
    /// Где слово в предложении — для словарной формы
    let range: Range<String.Index>
    /// То же место в переводе книги, если перевод добавлен
    var passage: BookPassage?
    /// Абзац главы и начало слова в нём (UTF-16) — для «Читать вслух отсюда»
    var paragraph = 0
    var location = 0
}

/// Читалка: глава прокручивается, нажатие на слово — перевод; место чтения запоминается
struct BookReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book

    @State private var chapters: [BookChapter] = []
    /// С какого абзаца книги начинается каждая глава
    @State private var chapterStarts: [Int] = []
    @State private var chapterIndex = 0
    /// Абзац, с которого открыть главу
    @State private var startParagraph = 0
    /// Абзацы главы, где каждое слово — ссылка на перевод. Готовятся один раз при открытии главы:
    /// разбор на каждой перерисовке давал рывки при прокрутке
    @State private var linkedParagraphs: [AttributedString]?
    @State private var tappedWord: TappedWord?
    /// Не английская книга: нажатие на слово — толкование из словаря iPhone
    @State private var definedWord: DefinedWord?
    /// Язык книги — определяется при открытии
    @State private var language = BookLanguage.english
    @State private var isShowingContents = false
    @State private var isShowingDictionary = false
    @State private var isShowingAppearance = false
    @State private var isShowingSearch = false
    /// Запрос поиска остаётся до закрытия книги — снова открыли поиск, а там прежние результаты
    @State private var searchQuery = ""
    /// Место, найденное поиском, — подсвечено несколько секунд
    @State private var mark = ReaderMark()

    /// Перевод книги, добавленный пользователем: абзацы подряд и какие из них под каким абзацем книги
    @State private var translationParagraphs: [String] = []
    @State private var alignment: BookAlignment?
    /// Перевод абзацев открытой главы; nil — у абзаца своего перевода нет
    @State private var chapterTranslations: [String?] = []
    /// Перевод заменили — глава собирается заново
    @State private var translationVersion = 0
    @AppStorage(ReaderSettings.parallelKey) private var showsParallel = true
    @State private var isImportingTranslation = false
    @State private var isAligning = false
    @State private var translationError: String?
    @State private var isConfirmingTranslationRemoval = false
    @State private var isShowingPageTranslation = false
    /// Абзацы открытой страницы — для «Перевод страницы»; в объекте, а не в @State: листание не перерисовывает читалку
    @State private var pageParagraphs = PageParagraphs()

    /// Закладки: абзацы от начала книги
    @State private var bookmarks: [BookBookmark] = []
    @State private var isShowingBookmarks = false
    @State private var isAddingBookmark = false
    @State private var bookmarkNote = ""
    /// «Начать книгу с этого места»: подтверждение; версия растёт, когда начало убрали, — глава собирается заново
    @State private var isConfirmingTrim = false
    @State private var contentVersion = 0
    /// Шапка спрятана: при чтении — тонкая строка с названием главы
    @State private var isChromeHidden = false

    /// Оформление — снимок настроек: обновляется после шторки «Оформление»
    @State private var style = ReaderStyle.current()
    /// Чтение вслух
    @State private var speech = ReaderSpeech()
    /// Глава дочитана вслух — следующую начать читать, как только она готова
    @State private var continuesReading = false
    @AppStorage(ReaderSpeech.speedKey) private var speechSpeed = 1.0

    nonisolated static let wordScheme = "wlword"

    private var isEnglish: Bool { language == BookLanguage.english }

    private var chapter: BookChapter? {
        chapters.indices.contains(chapterIndex) ? chapters[chapterIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Место под шапку — всегда одной высоты: свёрнута она или нет, текст не перекрывается и страница не прыгает
            ZStack {
                if isChromeHidden {
                    compactTitle
                        .transition(.opacity)
                } else {
                    header
                        .transition(.opacity)
                }
            }
            .frame(height: Self.barHeight)
            Divider().opacity(isChromeHidden ? 0 : 0.4)
            if let linkedParagraphs, style.layout == .pages, let chapter {
                ReaderPagedText(
                    chapterID: chapterIndex,
                    paragraphs: linkedParagraphs,
                    plainParagraphs: chapter.paragraphs,
                    readerFont: style.font,
                    fontSize: style.fontSize,
                    textColor: style.text,
                    lineSpacing: style.fontSize * style.spacing.factor,
                    startParagraph: startParagraph,
                    hasPrevious: chapterIndex > 0,
                    hasNext: chapterIndex + 1 < chapters.count,
                    curl: style.pageTurn == .curl,
                    animated: style.pageTurn != .instant,
                    background: style.background,
                    speech: speech,
                    mark: mark,
                    bookTitle: book.title,
                    language: language,
                    onVisible: { paragraph in
                        guard chapterStarts.indices.contains(chapterIndex) else { return }
                        book.position = chapterStarts[chapterIndex] + paragraph
                    },
                    onPageParagraphs: { pageParagraphs.range = $0 },
                    passage: bookPassage,
                    bookmarked: chapterBookmarks,
                    onBackgroundTap: toggleChrome,
                    onPageTurn: { setChromeHidden(true) },
                    onTap: handleTap,
                    onPrevious: { go(to: chapterIndex - 1, atEnd: true) },
                    onNext: { go(to: chapterIndex + 1) }
                )
                .equatable()
                .id("\(chapterIndex)-\(style.phonicsID)-\(contentVersion)")
            } else if let linkedParagraphs {
                ReaderChapterText(
                    chapterID: chapterIndex,
                    paragraphs: linkedParagraphs,
                    font: style.font.font(size: style.fontSize),
                    textColor: style.text,
                    lineSpacing: style.fontSize * style.spacing.factor,
                    startParagraph: startParagraph,
                    speech: speech,
                    mark: mark,
                    translations: showsParallel ? chapterTranslations : [],
                    translationFont: style.font.font(size: style.fontSize * 0.86),
                    onShiftTranslation: shiftTranslation,
                    bookmarked: chapterBookmarks,
                    onScrollDirection: { setChromeHidden($0) },
                    onVisible: { paragraph in
                        // Место чтения — прямо в книгу: у читалки нет состояния, которое менялось бы при прокрутке
                        guard chapterStarts.indices.contains(chapterIndex) else { return }
                        book.position = chapterStarts[chapterIndex] + paragraph
                    },
                    onTap: handleTap
                ) {
                    chapterNavigation
                }
                .equatable()
                .id("\(chapterIndex)-\(style.phonicsID)-\(showsParallel)-\(translationVersion)-\(contentVersion)")
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(style.background.ignoresSafeArea())
        // Тёмная тема книги — светлые часы и батарея в статус-баре
        .preferredColorScheme(style.colorScheme)
        .readableColumn(720)
        .task {
            open()
            speech.onChapterEnd = {
                guard chapterIndex + 1 < chapters.count else { speech.stop(); return }
                continuesReading = true
                startParagraph = 0
                chapterIndex += 1
                book.position = chapterStarts[chapterIndex]
            }
        }
        .onDisappear { speech.stop() }
        .onChange(of: speechSpeed) { _, _ in speech.speedChanged() }
        // Голос сменился сам (Kokoro не успевает) — коротко говорим об этом
        .overlay(alignment: .bottom) {
            if let notice = speech.notice {
                Text(notice)
                    .scaledFont(size: 14)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .onTapGesture { speech.notice = nil }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: speech.notice)
        .task(id: speech.notice) {
            guard speech.notice != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            speech.notice = nil
        }
        // Глава готовится, когда главы загружены и при каждой смене главы
        .task(id: "\(chapters.count)-\(chapterIndex)-\(style.phonicsID)-\(contentVersion)") { await prepareChapter() }
        .sheet(item: $tappedWord) { tapped in
            WordLookupView(tapped: tapped, bookTitle: book.title) {
                tappedWord = nil
                speech.start(from: tapped.paragraph, offset: tapped.location)
            }
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
        .sheet(item: $definedWord) { defined in
            SystemDefinitionView(term: defined.term)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingContents) { contents }
        .sheet(isPresented: $isShowingSearch) {
            BookSearchView(chapters: chapters, query: $searchQuery, onSelect: jump)
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingAppearance, onDismiss: { style = .current() }) {
            ReaderAppearanceSheet()
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingDictionary) {
            BookDictionaryView(book: book)
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingBookmarks) {
            BookBookmarksView(bookmarks: bookmarks, chapters: chapters, chapterStarts: chapterStarts,
                          onSelect: { open($0.paragraph) }, onDelete: removeBookmark)
                .appThemedColorScheme()
        }
        .alert("Закладка", isPresented: $isAddingBookmark) {
            TextField("Заметка (можно пусто)", text: $bookmarkNote)
            Button("Отмена", role: .cancel) {}
            Button("Добавить", action: addBookmark)
        } message: {
            Text("На этом месте книги. Заметка — например, «вернуться сюда».")
        }
        .sheet(isPresented: $isShowingPageTranslation) {
            PageTranslationView(items: pageTranslationItems, onShift: shiftTranslation)
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
        .fileImporter(isPresented: $isImportingTranslation, allowedContentTypes: UTType.bookFiles) { result in
            if case .success(let url) = result {
                Task { await importTranslation(url) }
            }
        }
        .overlay {
            if isAligning {
                ProgressView("Сопоставляю перевод…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Не получилось", isPresented: Binding(get: { translationError != nil }, set: { if !$0 { translationError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(translationError ?? "")
        }
        .alert("Начать книгу с этого места?", isPresented: $isConfirmingTrim) {
            Button("Отмена", role: .cancel) {}
            Button("Убрать начало", role: .destructive, action: trimBeforeCurrentPosition)
        } message: {
            Text("Всё, что стоит до открытой страницы (абзацев: \(book.position)) — обложка, оглавление, служебные строки, — будет убрано из книги. Вернуть можно, добавив книгу заново.")
        }
        .alert("Убрать перевод?", isPresented: $isConfirmingTranslationRemoval) {
            Button("Отмена", role: .cancel) {}
            Button("Убрать", role: .destructive, action: removeTranslation)
        } message: {
            Text("Книга останется, исчезнет только перевод. Его можно добавить снова.")
        }
    }

    // MARK: - Шапка

    /// Шапка: назад, название главы (нажатие — оглавление), чтение вслух, остальное (и оформление) — в «…»
    private var header: some View {
        HStack(spacing: 14) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 20, weight: .semibold)
                    .foregroundColor(style.text)
                    .frame(width: 30, height: 34, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Книги")
            Button { isShowingContents = true } label: {
                Text(chapter?.title ?? book.title)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(style.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityHint("Оглавление")
            Button(action: toggleReading) {
                if speech.isPreparing {
                    // Нейросетевой голос готовит фразу — нажатие ставит на паузу, как обычно
                    ProgressView()
                        .tint(style.text)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: speech.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .scaledFont(size: 24)
                        .foregroundColor(style.text)
                }
            }
            .accessibilityLabel(speech.isPlaying ? "Пауза" : "Читать вслух")
            Menu {
                Button { isShowingAppearance = true } label: {
                    Label("Оформление", systemImage: "textformat.size")
                }
                Button { isShowingContents = true } label: {
                    Label("Оглавление", systemImage: "list.bullet")
                }
                Button { isShowingSearch = true } label: {
                    Label("Поиск по книге", systemImage: "magnifyingglass")
                }
                if let current = currentBookmark {
                    Button(role: .destructive) { removeBookmark(current) } label: {
                        Label("Убрать закладку", systemImage: "bookmark.slash")
                    }
                } else {
                    Button {
                        bookmarkNote = ""
                        isAddingBookmark = true
                    } label: {
                        Label("Добавить закладку", systemImage: "bookmark")
                    }
                }
                Button { isShowingBookmarks = true } label: {
                    Label(bookmarks.isEmpty ? "Закладки" : "Закладки (\(bookmarks.count))", systemImage: "list.bullet.rectangle")
                }
                if isEnglish {
                    Button { isShowingDictionary = true } label: {
                        Label("Словарь из книги", systemImage: "text.book.closed")
                    }
                }
                // Перевод привязан к абзацам книги — с ним начало не убрать
                if alignment == nil, book.position > 0 {
                    Button { isConfirmingTrim = true } label: {
                        Label("Начать книгу с этого места", systemImage: "scissors")
                    }
                }
                translationMenu
                Picker(selection: $speechSpeed) {
                    ForEach(ReaderSpeech.speeds, id: \.self) { speed in
                        Text(speed == 1 ? "Обычная" : "\(speed.formatted(.number.locale(Locale(identifier: "ru_RU"))))×").tag(speed)
                    }
                } label: {
                    Label("Скорость чтения вслух", systemImage: "speedometer")
                }
                .pickerStyle(.menu)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .scaledFont(size: 22)
                    .foregroundColor(style.text)
            }
            .accessibilityLabel("Ещё")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var translationMenu: some View {
        if alignment != nil {
            if style.layout == .pages {
                Button { isShowingPageTranslation = true } label: {
                    Label("Перевод страницы", systemImage: "translate")
                }
            } else {
                Toggle(isOn: $showsParallel) {
                    Label("Перевод под абзацами", systemImage: "translate")
                }
            }
            Button { isImportingTranslation = true } label: {
                Label("Заменить перевод…", systemImage: "arrow.triangle.2.circlepath")
            }
            Button(role: .destructive) { isConfirmingTranslationRemoval = true } label: {
                Label("Убрать перевод", systemImage: "trash")
            }
        } else {
            Button { isImportingTranslation = true } label: {
                Label("Добавить перевод книги…", systemImage: "doc.badge.plus")
            }
        }
    }

    /// Высота места под шапку
    private static let barHeight: CGFloat = 50

    /// Шапка спрятана — тонкая строка с названием главы; нажатие возвращает шапку
    private var compactTitle: some View {
        Text(chapter?.title ?? book.title)
            .scaledFont(size: 12, weight: .medium)
            .foregroundColor(style.text.opacity(0.5))
            .lineLimit(1)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { setChromeHidden(false) }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Показать меню")
    }

    private func toggleChrome() {
        setChromeHidden(!isChromeHidden)
    }

    private func setChromeHidden(_ hidden: Bool) {
        guard hidden != isChromeHidden else { return }
        withAnimation(.easeInOut(duration: 0.2)) { isChromeHidden = hidden }
    }

    // MARK: - Текст главы

    private var chapterNavigation: some View {
        HStack {
            if chapterIndex > 0 {
                Button { go(to: chapterIndex - 1) } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
                .foregroundColor(style.text)
            }
            Spacer()
            if chapterIndex + 1 < chapters.count {
                Button { go(to: chapterIndex + 1) } label: {
                    HStack(spacing: 4) {
                        Text("Следующая глава")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
            } else {
                Text("Конец книги")
                    .foregroundColor(style.text.opacity(0.6))
            }
        }
        .scaledFont(size: 16, weight: .semibold)
    }

    // MARK: - Оглавление

    private var contents: some View {
        NavigationStack {
            List(chapters.indices, id: \.self) { index in
                Button {
                    go(to: index)
                    isShowingContents = false
                } label: {
                    HStack {
                        Text(chapters[index].title)
                            .foregroundColor(.brandDark)
                            .lineLimit(2)
                        Spacer()
                        if index == chapterIndex {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.brown)
                        }
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
            .brandListBackground()
            .navigationTitle("Оглавление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { isShowingContents = false }
                        .fontWeight(.bold)
                }
            }
        }
        .appThemedColorScheme()
    }

    // MARK: - Логика

    /// Главы разбираются из сохранённого JSON; открываем там, где остановились
    private func open() {
        guard chapters.isEmpty else { return }
        chapters = book.chapters
        language = BookLanguage.detect(chapters)
        speech.language = isEnglish ? nil : language
        // Запуск в режиме «Чтение» загрузит Kokoro заранее, только если последняя книга английская
        UserDefaults.standard.set(language, forKey: KokoroML.lastBookLanguageKey)
        speech.preloadVoice()
        var start = 0
        chapterStarts = chapters.map { chapter in
            defer { start += chapter.paragraphs.count }
            return start
        }
        loadTranslation()
        bookmarks = book.bookmarks
        let position = book.position
        chapterIndex = chapterStarts.lastIndex { $0 <= position } ?? 0
        startParagraph = position - (chapterStarts.indices.contains(chapterIndex) ? chapterStarts[chapterIndex] : 0)
        book.lastOpenedAt = Date()
        DailyReminder.rememberBook(book.title)
    }

    /// Ссылки на слова для всей главы — в фоне, один раз; с подсветкой правил чтения, если она включена
    private func prepareChapter() async {
        guard let chapter else { return }
        // Глава собирается заново и при смене подсветки — открываем её там же, где читали
        if chapterStarts.indices.contains(chapterIndex) {
            startParagraph = min(max(book.position - chapterStarts[chapterIndex], 0), max(chapter.paragraphs.count - 1, 0))
        }
        linkedParagraphs = nil
        updateChapterTranslations()
        pageParagraphs.range = nil
        let paragraphs = chapter.paragraphs
        // Правила чтения — английские: в книге на другом языке не подсвечиваем
        let english = isEnglish
        let phonics = english ? style.phonics : nil
        linkedParagraphs = await Task.detached(priority: .userInitiated) {
            var cache: [String: ReadingRules.Highlight?] = [:]
            return paragraphs.enumerated().map {
                Self.linked($1, paragraph: $0, english: english, phonics: phonics, cache: &cache)
            }
        }.value
        speech.load(paragraphs: paragraphs, chapterTitle: chapter.title, bookTitle: book.title,
                    author: book.author, cover: book.coverData, bookID: book.id, chapter: chapterIndex)
        if continuesReading {
            continuesReading = false
            speech.start(from: 0)
        }
    }

    /// ▶️ — с абзаца вверху экрана; ⏸ — пауза; снова ▶️ — с того же слова
    private func toggleReading() {
        if speech.isPlaying {
            speech.pause()
        } else if speech.paragraph != nil {
            speech.resume()
        } else if chapterStarts.indices.contains(chapterIndex), let chapter {
            let top = min(max(book.position - chapterStarts[chapterIndex], 0), max(chapter.paragraphs.count - 1, 0))
            speech.start(from: top)
        }
    }

    // MARK: - Закладки

    /// Абзацы открытой главы с закладкой (номера в главе)
    private var chapterBookmarks: Set<Int> {
        guard chapterStarts.indices.contains(chapterIndex), let chapter else { return [] }
        let start = chapterStarts[chapterIndex]
        return Set(bookmarks.map { $0.paragraph - start }.filter { chapter.paragraphs.indices.contains($0) })
    }

    /// Закладка на открытом месте: на открытой странице, в прокрутке — на абзаце вверху экрана
    private var currentBookmark: BookBookmark? {
        guard chapterStarts.indices.contains(chapterIndex) else { return nil }
        let start = chapterStarts[chapterIndex]
        let range = style.layout == .pages ? pageParagraphs.range.map { (start + $0.lowerBound)...(start + $0.upperBound) } : nil
        return bookmarks.first { range?.contains($0.paragraph) ?? ($0.paragraph == book.position) }
    }

    private func addBookmark() {
        let note = bookmarkNote.trimmingCharacters(in: .whitespacesAndNewlines)
        bookmarks.append(BookBookmark(paragraph: book.position, note: note))
        saveBookmarks()
        Haptics.tap()
    }

    private func removeBookmark(_ bookmark: BookBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }

    /// Всё до абзаца вверху открытой страницы — из книги: главы, закладки и место чтения сдвигаются на столько же
    private func trimBeforeCurrentPosition() {
        let cut = book.position
        guard cut > 0, alignment == nil else { return }
        speech.stop()
        var remaining = cut
        var kept: [BookChapter] = []
        for var item in chapters {
            if remaining >= item.paragraphs.count {
                remaining -= item.paragraphs.count
                continue
            }
            if remaining > 0 {
                item.paragraphs.removeFirst(remaining)
                remaining = 0
            }
            kept.append(item)
        }
        guard !kept.isEmpty, let data = try? JSONEncoder().encode(kept) else { return }
        book.chaptersData = data
        book.paragraphCount = kept.reduce(0) { $0 + $1.paragraphs.count }
        book.position = 0
        bookmarks = bookmarks.filter { $0.paragraph >= cut }.map { bookmark in
            var shifted = bookmark
            shifted.paragraph -= cut
            return shifted
        }
        book.bookmarks = bookmarks
        try? modelContext.save()
        chapters = kept
        var start = 0
        chapterStarts = kept.map { chapter in
            defer { start += chapter.paragraphs.count }
            return start
        }
        chapterIndex = 0
        startParagraph = 0
        contentVersion += 1
        Haptics.tap()
    }

    private func saveBookmarks() {
        book.bookmarks = bookmarks
        bookmarks = book.bookmarks
        try? modelContext.save()
    }

    /// Переход к абзацу книги: другая глава открывается на нём, в открытой — прокрутка или листание к нему
    private func open(_ paragraph: Int) {
        guard let index = chapterStarts.lastIndex(where: { $0 <= paragraph }), chapters.indices.contains(index) else { return }
        speech.stop()
        let local = paragraph - chapterStarts[index]
        mark.show(paragraph: local, range: NSRange(location: 0, length: 0))
        book.position = paragraph
        if index != chapterIndex {
            startParagraph = local
            chapterIndex = index
        }
    }

    // MARK: - Перевод книги

    private func loadTranslation() {
        translationParagraphs = ParallelText.flatten(book.translationChapters)
        alignment = book.alignment
    }

    private func updateChapterTranslations() {
        chapterTranslations = alignment.map {
            ParallelText.paragraphs(chapter: chapterIndex, alignment: $0, translation: translationParagraphs)
        } ?? []
    }

    /// Абзацы открытой страницы с переводом; до первого листания — несколько абзацев от места чтения
    private var pageTranslationItems: [PageTranslationView.Item] {
        guard let chapter, chapterStarts.indices.contains(chapterIndex) else { return [] }
        let top = min(max(book.position - chapterStarts[chapterIndex], 0), max(chapter.paragraphs.count - 1, 0))
        let range = pageParagraphs.range ?? top...min(top + 2, chapter.paragraphs.count - 1)
        return range.filter(chapter.paragraphs.indices.contains).map { index in
            PageTranslationView.Item(id: index, original: chapter.paragraphs[index],
                                     translation: chapterTranslations.indices.contains(index) ? chapterTranslations[index] : nil)
        }
    }

    /// Файл перевода из «Файлов»: тот же разбор, что у книг; язык должен отличаться от языка книги
    private func importTranslation(_ url: URL) async {
        isAligning = true
        defer { isAligning = false }
        guard let parsed = try? await Task.detached(priority: .userInitiated, operation: { try BookParser.parse(url) }).value else {
            translationError = "Не получилось открыть файл. Подходят .epub без защиты, .fb2 и .txt."
            return
        }
        let translation = parsed.chapters
        guard BookLanguage.detect(translation) != language else {
            translationError = "Похоже, это не перевод: язык файла тот же, что у книги."
            return
        }
        let original = chapters
        // Английская книга и русский перевод — пары абзацев ищутся и по словарю базы, не только по длине
        let usesLexicon = isEnglish && BookLanguage.detect(translation) == "ru"
        let aligned = await Task.detached(priority: .userInitiated) {
            ParallelText.align(original, translation: translation, lexicon: usesLexicon ? AlignmentLexicon.bundled : nil)
        }.value
        book.translationData = try? JSONEncoder().encode(translation)
        book.alignmentData = try? JSONEncoder().encode(aligned)
        try? modelContext.save()
        loadTranslation()
        updateChapterTranslations()
        showsParallel = true
        translationVersion += 1
    }

    /// Перевод книги для выделенного или нажатого: предложения перевода абзаца. Абзац без своего перевода
    /// (переводчик слил его с предыдущим) — ищем у предыдущего, оба абзаца одним текстом
    private func bookPassage(paragraph: Int, range: NSRange) -> BookPassage? {
        guard let chapter, chapter.paragraphs.indices.contains(paragraph), chapterTranslations.indices.contains(paragraph) else { return nil }
        var owner = paragraph
        while chapterTranslations[owner] == nil, owner > 0, paragraph - owner < 3 { owner -= 1 }
        guard let translation = chapterTranslations[owner] else { return nil }
        let original = chapter.paragraphs[owner...paragraph].joined(separator: " ")
        let shift = chapter.paragraphs[owner..<paragraph].reduce(0) { $0 + ($1 as NSString).length + 1 }
        return ParallelText.passage(original: original, selected: NSRange(location: range.location + shift, length: range.length),
                                    translation: translation, lexicon: isEnglish ? AlignmentLexicon.bundled : nil)
    }

    /// «Сдвинуть перевод» с этого абзаца до конца главы: +1 — здесь следующий абзац перевода, −1 — предыдущий
    private func shiftTranslation(from paragraph: Int, by delta: Int) {
        guard let alignment else { return }
        let shifted = ParallelText.shift(alignment, chapter: chapterIndex, from: paragraph, by: delta,
                                         translationCount: translationParagraphs.count)
        book.alignmentData = try? JSONEncoder().encode(shifted)
        try? modelContext.save()
        self.alignment = shifted
        updateChapterTranslations()
        translationVersion += 1
    }

    private func removeTranslation() {
        book.setTranslation(nil)
        try? modelContext.save()
        loadTranslation()
        updateChapterTranslations()
        translationVersion += 1
    }

    /// atEnd — листают назад с первой страницы: предыдущая глава открывается на последней странице
    private func go(to index: Int, atEnd: Bool = false) {
        guard chapters.indices.contains(index) else { return }
        speech.stop()
        mark.clear()
        startParagraph = atEnd ? max(chapters[index].paragraphs.count - 1, 0) : 0
        chapterIndex = index
        book.position = chapterStarts[index] + startParagraph
    }

    /// Переход к найденному: другая глава открывается на этом абзаце, в открытой — прокрутка или листание к месту
    private func jump(to result: BookSearchResult) {
        guard chapters.indices.contains(result.chapter), chapterStarts.indices.contains(result.chapter) else { return }
        speech.stop()
        mark.show(paragraph: result.paragraph, range: result.range)
        book.position = chapterStarts[result.chapter] + result.paragraph
        if result.chapter != chapterIndex {
            startParagraph = result.paragraph
            chapterIndex = result.chapter
        }
    }

    /// wlword://w/<абзац>/<начало>/<длина> — в UTF-16, как NSRange
    private func handleTap(_ url: URL) {
        guard url.scheme == Self.wordScheme, let chapter else { return }
        let parts = url.pathComponents.compactMap(Int.init)
        guard parts.count == 3, chapter.paragraphs.indices.contains(parts[0]) else { return }
        // Перевод слова — чтение вслух на паузу, продолжится кнопкой ▶️
        speech.pause()
        let paragraph = chapter.paragraphs[parts[0]]
        guard let range = Range(NSRange(location: parts[1], length: parts[2]), in: paragraph) else { return }
        let sentenceRange = Self.sentence(containing: range, in: paragraph)
        let sentence = String(paragraph[sentenceRange])
        let offset = paragraph.distance(from: sentenceRange.lowerBound, to: range.lowerBound)
        let start = sentence.index(sentence.startIndex, offsetBy: offset)
        let end = sentence.index(start, offsetBy: paragraph.distance(from: range.lowerBound, to: range.upperBound))
        guard isEnglish else {
            definedWord = DefinedWord(term: String(paragraph[range]))
            return
        }
        tappedWord = TappedWord(word: String(paragraph[range]), sentence: sentence, range: start..<end,
                                passage: bookPassage(paragraph: parts[0], range: NSRange(location: parts[1], length: parts[2])),
                                paragraph: parts[0], location: parts[1])
    }

    private static func sentence(containing range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var result = text.startIndex..<text.endIndex
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { _, sentenceRange, _, stop in
            if sentenceRange.contains(range.lowerBound) {
                result = sentenceRange
                stop = true
            }
        }
        return result
    }

    /// Абзац, где каждое слово — ссылка на себя: в английской книге — английские слова, в другой — слова любых букв.
    /// phonics: nil — без подсветки, иначе что подсвечивать; cache — разбор слов главы
    nonisolated static func linked(_ text: String, paragraph: Int, english: Bool = true, phonics: Set<PhonicsOption>? = nil,
                                   cache: inout [String: ReadingRules.Highlight?]) -> AttributedString {
        let ns = text as NSString
        let pattern = english ? "[A-Za-z]+(?:['’-][A-Za-z]+)*" : "\\p{L}+(?:['’-]\\p{L}+)*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return AttributedString(text) }
        let showsColloquial = english && phonics?.contains(.colloquial) == true
        // Кавычки ‘…’ в абзаце — ’ после слова скорее закрывает цитату, чем глотает звук
        let singleQuotes = showsColloquial && text.contains("‘")
        var result = AttributedString()
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let range = match.range
            if range.location > last {
                result += AttributedString(ns.substring(with: NSRange(location: last, length: range.location - last)))
            }
            var word = AttributedString(ns.substring(with: range))
            word.link = URL(string: "\(wordScheme)://w/\(paragraph)/\(range.location)/\(range.length)")
            if let phonics {
                decorate(&word, ns.substring(with: range), options: phonics, cache: &cache)
            }
            if showsColloquial {
                let before = range.location > 0 ? ns.substring(with: NSRange(location: range.location - 1, length: 1)).first : nil
                let end = NSMaxRange(range)
                let after = ns.substring(with: NSRange(location: end, length: min(2, ns.length - end)))
                if ColloquialForms.form(ns.substring(with: range), before: before, after: after, singleQuotes: singleQuotes) != nil {
                    word.underlineStyle = Text.LineStyle(pattern: .dash, color: ColloquialRule.color)
                }
            }
            result += word
            last = range.location + range.length
        }
        if last < ns.length {
            result += AttributedString(ns.substring(from: last))
        }
        return result
    }
}

extension BookReaderView {
    /// Подсветка правил чтения в слове: сочетания — цветным фоном, немые буквы — бледными, исключение — пунктиром.
    /// Слова через дефис разбираются по частям
    nonisolated static func decorate(_ word: inout AttributedString, _ text: String, options: Set<PhonicsOption>,
                                     cache: inout [String: ReadingRules.Highlight?]) {
        var offset = 0
        for part in text.split(separator: "-", omittingEmptySubsequences: false) {
            let piece = String(part)
            defer { offset += (piece as NSString).length + 1 }
            // Кэш — на одну главу с одними галочками
            let key = piece.lowercased()
            let highlight: ReadingRules.Highlight?
            if let cached = cache[key] {
                highlight = cached
            } else {
                highlight = ReadingRules.highlight(piece, options: options)
                cache[key] = highlight
            }
            guard let highlight else { continue }
            func range(_ local: NSRange) -> Range<AttributedString.Index>? {
                Range(NSRange(location: local.location + offset, length: local.length), in: word)
            }
            for span in highlight.spans {
                guard let target = range(span.range) else { continue }
                let color = span.irregular ? PhonicsKind.exceptionColor : span.kind.color
                word[target].backgroundColor = color.opacity(span.irregular ? 0.18 : 0.22)
            }
            for silent in highlight.silent {
                guard let target = range(silent) else { continue }
                word[target].foregroundColor = Color.gray.opacity(0.75)
            }
            if highlight.isException, let target = range(NSRange(location: 0, length: (piece as NSString).length)) {
                word[target].underlineStyle = Text.LineStyle(pattern: .dot, color: PhonicsKind.exceptionColor)
            }
        }
    }
}

/// Текст главы. Отдельно от читалки и сравнивается по содержимому: при прокрутке перерисовывается только он,
/// а шапка, шторки и вся читалка — нет
private struct ReaderChapterText<Navigation: View>: View, Equatable {
    let chapterID: Int
    let paragraphs: [AttributedString]
    let font: Font
    let textColor: Color
    let lineSpacing: CGFloat
    let startParagraph: Int
    let speech: ReaderSpeech
    let mark: ReaderMark
    /// Перевод под абзацами; пусто — не показывать
    let translations: [String?]
    let translationFont: Font
    let onShiftTranslation: (Int, Int) -> Void
    let bookmarked: Set<Int>
    /// true — читают дальше вниз (шапку спрятать), false — вернулись вверх (показать)
    let onScrollDirection: (Bool) -> Void
    let onVisible: (Int) -> Void
    let onTap: (URL) -> Void
    @ViewBuilder let navigation: () -> Navigation

    /// Видимые абзацы — в обычном объекте, а не в @State: их смена при прокрутке не перерисовывает главу
    @State private var visible = VisibleParagraphs()
    /// Откуда началось движение в одну сторону — шапка меняется, когда ушли от него на 40 точек
    @State private var scrollAnchor = ScrollAnchor()

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapterID == rhs.chapterID && lhs.paragraphs.count == rhs.paragraphs.count
            && lhs.font == rhs.font && lhs.textColor == rhs.textColor && lhs.lineSpacing == rhs.lineSpacing
            && lhs.translations.count == rhs.translations.count && lhs.bookmarked == rhs.bookmarked
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(paragraphs.indices, id: \.self) { index in
                        ReaderParagraph(index: index, text: paragraphs[index], font: font, textColor: textColor,
                                        lineSpacing: lineSpacing, speech: speech, mark: mark,
                                        translation: translations.indices.contains(index) ? translations[index] : nil,
                                        translationFont: translationFont,
                                        onShiftTranslation: { onShiftTranslation(index, $0) })
                            .overlay(alignment: .topTrailing) {
                                if bookmarked.contains(index) {
                                    BookmarkRibbon()
                                        .offset(x: 18, y: -6)
                                        .allowsHitTesting(false)
                                }
                            }
                            .id(index)
                    }
                    navigation()
                        .padding(.top, 20)
                }
                .scrollTargetLayout()
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .onScrollTargetVisibilityChange(idType: Int.self, threshold: 0.01) { ids in
                visible.ids = ids
            }
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, offset in
                let moved = offset - scrollAnchor.offset
                if offset < 20 {
                    onScrollDirection(false)
                    scrollAnchor.offset = offset
                } else if moved > 40 {
                    onScrollDirection(true)
                    scrollAnchor.offset = offset
                } else if moved < -40 {
                    onScrollDirection(false)
                    scrollAnchor.offset = offset
                } else if (moved > 0) != scrollAnchor.goingDown {
                    // Повернули обратно — отсчёт с этого места
                    scrollAnchor.goingDown = moved > 0
                    scrollAnchor.offset = offset
                }
            }
            // Место чтения запоминаем, когда прокрутка остановилась, а не на каждом абзаце
            .onScrollPhaseChange { _, phase in
                guard phase == .idle, let top = visible.ids.min() else { return }
                onVisible(top)
            }
            // Чтение вслух ведёт за собой: читаемый абзац — у верха экрана
            .onChange(of: speech.paragraph) { _, paragraph in
                guard let paragraph, speech.isPlaying else { return }
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(paragraph, anchor: UnitPoint(x: 0, y: 0.15)) }
            }
            // Найденное поиском в этой же главе — прокручиваем к нему
            .onChange(of: mark.jump) { _, _ in
                guard let paragraph = mark.paragraph else { return }
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(paragraph, anchor: UnitPoint(x: 0, y: 0.3)) }
            }
            .task {
                // Прокрутка к месту — после того как глава отрисовалась
                guard startParagraph > 0 else { return }
                try? await Task.sleep(for: .milliseconds(80))
                proxy.scrollTo(startParagraph, anchor: .top)
            }
        }
        // Слова — ссылки: цвет обычного текста, нажатие открывает перевод
        .tint(textColor)
        .environment(\.openURL, OpenURLAction { url in
            // Ссылки на слова — читалке; остальные (Google Переводчик из панели выделения) — системе
            guard url.scheme == BookReaderView.wordScheme else { return .systemAction }
            onTap(url)
            return .handled
        })
    }
}

/// Абзац. Читаемый вслух — с лёгким фоном, произносимое слово — ярче.
/// Слово читает только читаемый абзац: при смене слова перерисовывается он один
private struct ReaderParagraph: View {
    let index: Int
    let text: AttributedString
    let font: Font
    let textColor: Color
    let lineSpacing: CGFloat
    let speech: ReaderSpeech
    let mark: ReaderMark
    /// Абзац перевода — под оригиналом, мельче и бледнее
    let translation: String?
    let translationFont: Font
    /// Перевод не тот — сдвинуть с этого абзаца до конца главы
    let onShiftTranslation: (Int) -> Void

    var body: some View {
        let isReading = speech.paragraph == index
        let isMarked = mark.paragraph == index
        VStack(alignment: .leading, spacing: 8) {
            Text(isReading || isMarked ? highlighted : text)
                .font(font)
                .foregroundColor(textColor)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if isReading {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(textColor.opacity(0.06))
                            .padding(-8)
                    }
                }
            if let translation {
                Text(translation)
                    .font(translationFont)
                    .foregroundColor(textColor.opacity(0.55))
                    .lineSpacing(lineSpacing * 0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .contextMenu { ShiftTranslationMenu(onShift: onShiftTranslation) }
            }
        }
    }

    private var highlighted: AttributedString {
        var result = text
        if speech.paragraph == index, let word = speech.word, let range = Range(word, in: result) {
            result[range].backgroundColor = Color.yellow.opacity(0.45)
        }
        if mark.paragraph == index, let found = mark.range, let range = Range(found, in: result) {
            result[range].backgroundColor = ReaderMark.color
        }
        return result
    }
}

/// Какие абзацы сейчас на экране. Класс без наблюдения: запись не вызывает перерисовку
private final class VisibleParagraphs {
    var ids: [Int] = []
}

/// Прокрутка для шапки: где началось движение и в какую сторону. Без наблюдения — прокрутка не перерисовывает главу
private final class ScrollAnchor {
    var offset: CGFloat = 0
    var goingDown = true
}

/// Перевод встал не напротив своего абзаца — сдвинуть с этого места до конца главы
struct ShiftTranslationMenu: View {
    let onShift: (Int) -> Void

    var body: some View {
        Section("Перевод не тот? Сдвиг до конца главы") {
            Button { onShift(1) } label: {
                Label("Здесь следующий абзац перевода", systemImage: "arrow.down")
            }
            Button { onShift(-1) } label: {
                Label("Здесь предыдущий абзац перевода", systemImage: "arrow.up")
            }
        }
    }
}

/// Абзацы открытой страницы (режим страниц) — для «Перевод страницы». Класс без наблюдения: листание не перерисовывает читалку
final class PageParagraphs {
    var range: ClosedRange<Int>?
}

/// «Перевод страницы»: абзацы открытой страницы и их перевод
struct PageTranslationView: View {
    struct Item: Identifiable {
        let id: Int
        let original: String
        let translation: String?
    }

    let items: [Item]
    /// Абзац книги и сдвиг: +1 — здесь следующий абзац перевода, −1 — предыдущий
    let onShift: (Int, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.original)
                                .scaledFont(size: 14, design: .serif)
                                .foregroundColor(.gray)
                            HStack(alignment: .top) {
                                Text(item.translation ?? "В переводе этот абзац объединён с соседним.")
                                    .scaledFont(size: 17, design: .serif)
                                    .foregroundColor(item.translation == nil ? .gray : .brandDark)
                                    .italic(item.translation == nil)
                                Spacer(minLength: 4)
                                if item.translation != nil {
                                    Menu {
                                        ShiftTranslationMenu { onShift(item.id, $0) }
                                    } label: {
                                        Image(systemName: "arrow.up.arrow.down.circle")
                                            .scaledFont(size: 18)
                                            .foregroundColor(.gray)
                                    }
                                    .accessibilityLabel("Сдвинуть перевод")
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Перевод страницы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
