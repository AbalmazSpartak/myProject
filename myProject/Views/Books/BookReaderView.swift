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
    /// Открыта кнопкой «Слушать» на странице книги: чтение вслух начинается само
    var listensOnOpen = false
    /// «Слушать с этой главы»: книга открывается с начала этой главы (номер с нуля)
    var listenFromChapter: Int?
    @State private var didAutoListen = false
    /// Экран слушания поверх читалки; таймер сна
    @State private var isShowingPlayer = false
    @State private var sleep = SleepTimer.off
    @State private var sleepEndsAt: Date?
    @State private var sleepTask: Task<Void, Never>?
    /// Нижняя панель: пока двигают ползунок книги — его значение
    @State private var barDrag: Double?
    @Environment(\.colorScheme) private var systemScheme

    @State private var chapters: [BookChapter] = []
    /// Номера глав для показа в шапке и оглавлении (считаются один раз на набор глав)
    @State private var numbering = ChapterNumbering(titles: [])
    /// С какого абзаца книги начинается каждая глава
    @State private var chapterStarts: [Int] = []
    @State private var chapterIndex = 0
    /// Живой голос LibriVox из меню «Голос»: открыт ли его плеер и с какой главы записи
    @State private var isListeningLive = false
    @State private var liveSection: Int?
    /// Другой чтец, а у нынешнего есть скачанные главы — спрашиваем
    @State private var pendingLiveRecording: LibriVox.Audiobook?
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
    /// Заметка к выделенному месту: фраза уже выбрана, ждём описание
    private struct NoteDraft { let text: String; let paragraph: Int; let range: NSRange }
    @State private var notes: [BookNote] = []
    @State private var noteDraft: NoteDraft?
    @State private var noteText = ""
    /// «Меню чтения» — лист снизу; что открывает другой экран, делается после его закрытия
    @State private var isShowingMenu = false
    @State private var pendingMenuAction: (() -> Void)?
    @State private var isShowingDictionary = false
    @State private var isShowingAppearance = false
    @State private var isShowingSearch = false
    /// «Герои и места»: имена по всей книге считаются один раз при первом открытии
    @State private var isShowingNames = false
    @State private var bookNames: [BookName]?
    /// Из шторки имён — «все места»: поиск открывается, когда шторка закрылась
    @State private var pendingSearch: String?
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
    @State private var recorder = AudiobookRecorder.shared
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
                        book.furthest = max(book.furthest, book.position)
                    },
                    onPageParagraphs: { pageParagraphs.range = $0 },
                    passage: bookPassage,
                    bookmarked: chapterBookmarks,
                    onBackgroundTap: toggleChrome,
                    onPageTurn: { setChromeHidden(true) },
                    onTap: handleTap,
                    onSelectionStart: { setChromeHidden(true) },
                    onNote: { text, paragraph, range in
                        guard chapterStarts.indices.contains(chapterIndex) else { return }
                        noteText = ""
                        noteDraft = NoteDraft(text: text, paragraph: chapterStarts[chapterIndex] + paragraph, range: range)
                    },
                    noted: chapterNotedRanges,
                    onPrevious: { go(to: chapterIndex - 1, atEnd: true) },
                    onNext: { go(to: chapterIndex + 1) }
                )
                .equatable()
                .id("\(chapterIndex)-\(style.phonicsID)-\(themeSwitchID)-\(contentVersion)")
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
                        book.furthest = max(book.furthest, book.position)
                    },
                    onTap: handleTap
                ) {
                    chapterNavigation
                }
                .equatable()
                .id("\(chapterIndex)-\(style.phonicsID)-\(themeSwitchID)-\(showsParallel)-\(translationVersion)-\(contentVersion)")
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(style.background.ignoresSafeArea())
        // Тёмная тема книги — светлые часы и батарея в статус-баре
        .preferredColorScheme(style.colorScheme)
        .readableColumn(PadLayout.readerWidth)
        .task {
            await open()
            speech.onChapterEnd = {
                // Таймер сна «в конце главы» — дальше не читаем
                if sleep == .chapterEnd {
                    setSleep(.off)
                    speech.stop()
                    return
                }
                guard chapterIndex + 1 < chapters.count else { speech.stop(); return }
                continuesReading = true
                startParagraph = 0
                chapterIndex += 1
                book.position = chapterStarts[chapterIndex]
                book.furthest = max(book.furthest, book.position)
            }
        }
        .onDisappear {
            sleepTask?.cancel()
            speech.stop()
        }
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
        .task(id: "\(chapters.count)-\(chapterIndex)-\(style.phonicsID)-\(themeSwitchID)-\(contentVersion)") { await prepareChapter() }
        .sheet(item: $tappedWord, onDismiss: {
            // Слово могли добавить в словарь или отметить «Знаю» — статусы в тексте обновляем
            if style.showsStatus { contentVersion += 1 }
        }) { tapped in
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
        .sheet(isPresented: $isShowingMenu, onDismiss: {
            let action = pendingMenuAction
            pendingMenuAction = nil
            action?()
        }) { readerMenu }
        .overlay {
            if isShowingPlayer, let chapter {
                ReaderPlayerView(book: book, chapterTitle: chapter.title,
                                 chapterLabel: numbering.label(for: chapterIndex, title: chapter.title),
                                 chapterNumber: chapterIndex + 1, chapterCount: chapters.count,
                                 paragraphs: chapter.paragraphs, speech: speech, speed: $speechSpeed,
                                 sleep: sleep, sleepEndsAt: sleepEndsAt, onSleep: setSleep, onToggle: toggleReading,
                                 onSeek: { speech.start(from: $0) }, onChapter: playerChapter(_:),
                                 onChapters: { isShowingContents = true }, onClose: { isShowingPlayer = false },
                                 language: language, onNeuralVoice: switchNeuralVoice, onLiveVoice: switchToLive)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isShowingPlayer)
        .navigationDestination(isPresented: $isListeningLive) {
            LiveAudioPlayerView(book: book, startSection: liveSection, onNeural: resumeNeural)
                .toolbar(.visible, for: .navigationBar)
        }
        .confirmationDialog("Сменить чтеца?", isPresented: Binding(get: { pendingLiveRecording != nil }, set: { if !$0 { pendingLiveRecording = nil } }),
                            titleVisibility: .visible, presenting: pendingLiveRecording) { audiobook in
            Button("Сменить и удалить скачанное", role: .destructive) {
                if (try? LiveAudioPlayer.shared.replaceRecording(book: book.id, with: audiobook)) != nil { openLive(audiobook) }
            }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Скачанные главы нынешнего чтеца удалятся. Новый чтец играет онлайн, скачать его можно на странице книги.")
        }
        // Нижняя панель — вместе с шапкой; поверх страницы, не сдвигая текст
        .overlay(alignment: .bottom) {
            if !isShowingPlayer, !chapters.isEmpty {
                VStack(spacing: 0) {
                    // Озвучка идёт — мини-плеер над нижней панелью: пауза, прогресс главы, скорость
                    if speech.isPlaying || speech.isPreparing || speech.paragraph != nil {
                        miniPlayer
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if !isChromeHidden {
                        bottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !mark.pageQuery.isEmpty {
                Button { mark.pageQuery = "" } label: {
                    Label("Подсвечено: «\(mark.pageQuery)»", systemImage: "xmark.circle.fill")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(style.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(style.text.opacity(0.14)))
                }
                .padding(.bottom, isChromeHidden ? 44 : 150)
            }
        }
        .sheet(isPresented: $isShowingNames, onDismiss: {
            if let query = pendingSearch {
                pendingSearch = nil
                searchQuery = query
                isShowingSearch = true
            }
        }) {
            BookNamesView(chapters: chapters, position: max(book.furthest, book.position), names: $bookNames,
                          onSelect: { mention in
                              jump(to: BookSearchResult(id: 0, chapter: mention.chapter, paragraph: mention.paragraph,
                                                        range: mention.range, snippet: AttributedString()))
                          },
                          onSearch: { query in
                              pendingSearch = query
                              isShowingNames = false
                          })
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingSearch) {
            BookSearchView(chapters: chapters, query: $searchQuery, isPaged: style.layout == .pages, onSelect: jump,
                           onPageSearch: { mark.pageQuery = $0 })
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
        .alert("Заметка", isPresented: Binding(get: { noteDraft != nil }, set: { if !$0 { noteDraft = nil } })) {
            TextField("Описание (можно пусто)", text: $noteText)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить", action: saveNote)
        } message: {
            Text("«\(String((noteDraft?.text ?? "").prefix(140)))»")
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

    /// «2. The Pool of Tears» вместо «CHAPTER II. The Pool of Tears»
    private var chapterHeadline: String {
        guard let chapter else { return book.title }
        return numbering.listTitle(for: chapterIndex, title: chapter.title)
    }

    /// Шапка: назад, название главы по центру (нажатие — оглавление), чтение вслух, оформление, остальное — в «…».
    /// Название не зависит от кнопок по краям и стоит там же, где в свёрнутой шапке
    private var header: some View {
        ZStack {
            buttonsBar
            Button { isShowingContents = true } label: {
                Text(chapterHeadline)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(style.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 112)
            .accessibilityHint("Оглавление")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var buttonsBar: some View {
        HStack(spacing: 14) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 20, weight: .semibold)
                    .foregroundColor(style.text)
                    .frame(width: 30, height: 34, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Книги")
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
            Spacer()
            Button { isShowingAppearance = true } label: {
                Image(systemName: "textformat.size")
                    .scaledFont(size: 22)
                    .foregroundColor(style.text)
            }
            .accessibilityLabel("Оформление")
            Menu {
                Button { isShowingPlayer = true } label: {
                    Label("Плеер", systemImage: "headphones")
                }
                Button { isShowingNames = true } label: {
                    Label("Герои и места", systemImage: "person.2")
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
                if isEnglish, AppMode.tapTranslationEnabled {
                    Button { isShowingDictionary = true } label: {
                        Label("Словарь из книги", systemImage: "text.book.closed")
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
        Text(chapterHeadline)
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
                .tint(Color.brandButton)
                .foregroundStyle(Color.brandOnButton)
                .tint(Color.brandTint)
            } else {
                Text("Конец книги")
                    .foregroundColor(style.text.opacity(0.6))
            }
        }
        .scaledFont(size: 16, weight: .semibold)
    }

    // MARK: - Меню чтения

    private var readerMenu: some View {
        ReaderMenuSheet(
            bookTitle: book.title,
            chapterTitles: chapters.indices.map { numbering.listTitle(for: $0, title: chapters[$0].title) },
            currentChapter: chapterIndex,
            isNight: isNight,
            hasBookmark: currentBookmark != nil,
            onStyleChange: { style = .current() },
            onSearch: { query in
                pendingMenuAction = { searchQuery = query; isShowingSearch = true }
                isShowingMenu = false
            },
            onChapter: { index in
                go(to: index)
                isShowingMenu = false
            },
            onAllChapters: {
                pendingMenuAction = { isShowingContents = true }
                isShowingMenu = false
            },
            onToggleDayNight: { toggleDayNight() },
            onBookmark: {
                if let current = currentBookmark {
                    removeBookmark(current)
                } else {
                    pendingMenuAction = { bookmarkNote = ""; isAddingBookmark = true }
                }
                isShowingMenu = false
            },
            onBookmarks: {
                pendingMenuAction = { isShowingBookmarks = true }
                isShowingMenu = false
            }
        )
        .appThemedColorScheme()
    }

    // MARK: - Оглавление

    private var contents: some View {
        NavigationStack {
            Group {
                if AppDesign.isSketch { sketchContents } else { classicContents }
            }
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

    private var classicContents: some View {
        List(chapters.indices, id: \.self) { index in
            Button {
                go(to: index)
                isShowingContents = false
            } label: {
                HStack {
                    Text(numbering.listTitle(for: index, title: chapters[index].title))
                        .foregroundColor(.brandDark)
                        .lineLimit(2)
                    Spacer()
                    if index == chapterIndex {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(Color.brandTint)
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
    }

    /// «Скетч»: главы одной группой с контуром, текущая — жёлтой плашкой
    private var sketchContents: some View {
        ScrollView {
            LXGroup {
                ForEach(chapters.indices, id: \.self) { index in
                    let isCurrent = index == chapterIndex
                    Button {
                        go(to: index)
                        isShowingContents = false
                    } label: {
                        HStack(spacing: 10) {
                            Text(numbering.listTitle(for: index, title: chapters[index].title))
                                .scaledFont(size: 16, weight: isCurrent ? .bold : .regular, design: .serif)
                                .foregroundStyle(Color.brandDark)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            if isCurrent {
                                Image(systemName: "bookmark.fill").scaledFont(size: 13).foregroundStyle(Color.brandDark)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .background(isCurrent ? NewStyle.yellow.opacity(0.55) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }

    // MARK: - Логика

    /// Главы разбираются из сохранённого JSON; открываем там, где остановились
    private func open() async {
        guard chapters.isEmpty else { return }
        // JSON большой книги разбирается в фоне: экран не замирает при открытии
        let data = book.chaptersData
        let decoded = await Task.detached(priority: .userInitiated) { () -> ([BookChapter], String) in
            let list = (try? JSONDecoder().decode([BookChapter].self, from: data)) ?? []
            return (list, BookLanguage.detect(list))
        }.value
        guard chapters.isEmpty else { return }
        chapters = decoded.0
        numbering = ChapterNumbering(titles: chapters.map(\.title))
        language = decoded.1
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
        notes = book.notes
        if let target = listenFromChapter, chapterStarts.indices.contains(target) { book.position = chapterStarts[target] }
        let position = book.position
        chapterIndex = chapterStarts.lastIndex { $0 <= position } ?? 0
        startParagraph = position - (chapterStarts.indices.contains(chapterIndex) ? chapterStarts[chapterIndex] : 0)
        book.lastOpenedAt = Date()
        DailyReminder.rememberBook(book.title)
        if listensOnOpen { isShowingPlayer = true }
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
        let palette = style.phonicsPalette(isDark: isNight)
        // Статусы слов: словарь читаем здесь (главный поток), окрашиваем в фоне
        let statuses = english && style.showsStatus ? BookWordStatusSnapshot.make(in: modelContext) : nil
        linkedParagraphs = await Task.detached(priority: .userInitiated) {
            var cache: [String: ReadingRules.Highlight?] = [:]
            return paragraphs.enumerated().map {
                Self.linked($1, paragraph: $0, english: english, phonics: phonics, palette: palette, statuses: statuses, cache: &cache)
            }
        }.value
        speech.load(paragraphs: paragraphs, chapterTitle: chapter.title, bookTitle: book.title,
                    author: book.author, cover: book.coverData, bookID: book.id, chapter: chapterIndex)
        if continuesReading {
            continuesReading = false
            speech.start(from: 0)
        } else if listensOnOpen, !didAutoListen {
            didAutoListen = true
            speech.start(from: startParagraph)
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

    // MARK: - Нижняя панель

    /// Прогресс по всей книге и быстрые кнопки: тема, оглавление, поиск, закладки
    private var bottomBar: some View {
        let total = max(book.paragraphCount, 1)
        let fraction = barDrag ?? min(Double(book.position) / Double(total), 1)
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Slider(value: Binding(get: { fraction }, set: { barDrag = $0 }), in: 0...1) { editing in
                    if !editing, let value = barDrag {
                        barDrag = nil
                        open(min(Int(value * Double(total)), total - 1))
                    }
                }
                .tint(style.text.opacity(0.7))
                Text("\(Int((fraction * 100).rounded()))%")
                    .scaledFont(size: 13, weight: .medium)
                    .monospacedDigit()
                    .foregroundColor(style.text.opacity(0.7))
                    .frame(width: 40, alignment: .trailing)
                // Идёт запись озвучки этой книги — её прогресс на той же строке
                if recorder.isRecording(book.id), let job = recorder.job {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                        Text("\(Int((job.fraction * 100).rounded()))%")
                            .monospacedDigit()
                    }
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(style.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(style.text.opacity(0.12)))
                    .accessibilityLabel("Запись озвучки \(Int((job.fraction * 100).rounded())) процентов")
                }
            }
            HStack(spacing: 0) {
                barButton(isNight ? "sun.max" : "moon", isNight ? "День" : "Ночь") { toggleDayNight() }
                barButton("magnifyingglass", "Поиск") { isShowingSearch = true }
                barButton("bookmark", bookmarks.isEmpty ? "Закладки" : "Закладки \(bookmarks.count)") { isShowingBookmarks = true }
                barButton("list.bullet", "Меню") { isShowingMenu = true }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            if AppDesign.isSketch {
                // «Скетч»: вместо тени — тонкая линия сверху
                style.background.ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) { Rectangle().fill(style.text).frame(height: 1.5) }
            } else {
                style.background.shadow(color: .black.opacity(0.12), radius: 6, y: -2).ignoresSafeArea(edges: .bottom)
            }
        }
    }

    /// Мини-плеер по холсту: кнопка паузы, полоса прогресса главы с подписью, скорость. Нажатие на полосу — полный плеер
    private var miniPlayer: some View {
        let count = max(chapter?.paragraphs.count ?? 1, 1)
        let fraction = min(Double(speech.paragraph ?? 0) / Double(count), 1)
        return HStack(spacing: 12) {
            Button(action: toggleReading) {
                Group {
                    if speech.isPreparing {
                        ProgressView().tint(Color.brandOnButton)
                    } else {
                        Image(systemName: speech.isPlaying ? "pause.fill" : "play.fill")
                            .scaledFont(size: 18)
                            .foregroundStyle(AppDesign.isSketch ? Color.black : Color.brandOnButton)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppDesign.isSketch ? NewStyle.yellow : Color.brandButton))
                .overlay { if AppDesign.isSketch { Circle().stroke(NewStyle.outline, style: NewStyle.stroke) } }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speech.isPlaying ? "Пауза" : "Читать вслух")
            Button { isShowingPlayer = true } label: {
                VStack(alignment: .leading, spacing: 5) {
                    if AppDesign.isSketch {
                        SketchProgress(value: fraction)
                    } else {
                        ProgressView(value: fraction)
                            .tint(Color.brandButton)
                    }
                    Text("Озвучка · \(chapterHeadline)")
                        .scaledFont(size: 11)
                        .foregroundStyle(Color.brandMuted)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Открыть плеер")
            Text(speechSpeed == 1 ? "1×" : "\(speechSpeed.formatted(.number.locale(Locale(identifier: "ru_RU"))))×")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(Color.brandOnSoft)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.brandFill)
        .overlay(alignment: .top) { LXDivider() }
    }

    private func barButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .scaledFont(size: 20)
                Text(title)
                    .scaledFont(size: 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(style.text.opacity(0.85))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var isNight: Bool { (style.colorScheme ?? systemScheme) == .dark }

    /// День и ночь перестраивают главу только при включённой подсветке правил: цвета подсветки зависят от темы, а сам текст — нет
    private var themeSwitchID: String { style.phonics == nil && !style.showsStatus ? "" : String(isNight) }

    /// «Ночь» ↔ «День»: тёмная тема — «Ночь», светлая — «Бумага»; прочие настройки оформления остаются
    private func toggleDayNight() {
        let next: ReaderTheme = isNight ? .paper : .night
        UserDefaults.standard.set(next.rawValue, forKey: ReaderSettings.themeKey)
        style = .current()
    }

    /// Экран слушания: ⏮ ⏭ — соседняя глава; читает дальше, если до этого читал
    // MARK: - Смена голоса

    /// Другой нейроголос: читаем дальше с того же слова уже им
    private func switchNeuralVoice(_ choice: String) {
        NeuralVoice.shared.setBookChoice(language, choice)
        guard speech.isPlaying, let paragraph = speech.paragraph else { return }
        speech.start(from: paragraph, offset: speech.word?.location ?? 0)
    }

    /// Живой голос LibriVox: нейроголос — на паузу, плеер записи — с той же главы
    private func switchToLive(_ audiobook: LibriVox.Audiobook) {
        let saved = LiveAudioStore.audiobook(book: book.id)
        if saved?.id != audiobook.id {
            let downloaded = saved.map { LiveAudioStore.downloadedCount(book: book.id, audiobook: $0) } ?? 0
            if downloaded > 0 {
                pendingLiveRecording = audiobook
                return
            }
            guard (try? LiveAudioPlayer.shared.replaceRecording(book: book.id, with: audiobook)) != nil else { return }
        }
        openLive(audiobook)
    }

    private func openLive(_ audiobook: LibriVox.Audiobook) {
        speech.pause()
        if let chapter {
            liveSection = ChapterMatch.section(chapterTitle: chapter.title, chapterIndex: chapterIndex,
                                               chapterCount: chapters.count, sections: audiobook.sections)
        }
        isShowingPlayer = false
        isListeningLive = true
    }

    /// Вернулись из живого голоса нейроголосом: глава — та, что играла в записи, читаем с её начала
    private func resumeNeural(_ chapter: Int) {
        isShowingPlayer = true
        if chapter != chapterIndex, chapters.indices.contains(chapter) {
            go(to: chapter)
            continuesReading = true
        } else if speech.paragraph != nil {
            speech.resume()
        } else {
            toggleReading()
        }
    }

    private func playerChapter(_ delta: Int) {
        let wasPlaying = speech.isPlaying || speech.isPreparing
        let target = chapterIndex + delta
        guard chapters.indices.contains(target) else { return }
        go(to: target)
        continuesReading = wasPlaying
    }

    /// Таймер сна: через время — пауза; «в конце главы» проверяет onChapterEnd
    private func setSleep(_ option: SleepTimer) {
        sleepTask?.cancel()
        sleep = option
        sleepEndsAt = nil
        guard case .minutes(let minutes) = option else { return }
        sleepEndsAt = Date().addingTimeInterval(Double(minutes) * 60)
        sleepTask = Task {
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            speech.pause()
            sleep = .off
            sleepEndsAt = nil
        }
    }

    // MARK: - Закладки

    /// Абзацы открытой главы с закладкой (номера в главе)
    private var chapterBookmarks: Set<Int> {
        guard chapterStarts.indices.contains(chapterIndex), let chapter else { return [] }
        let start = chapterStarts[chapterIndex]
        return Set(bookmarks.map { $0.paragraph - start }.filter { chapter.paragraphs.indices.contains($0) })
    }

    /// Места заметок открытой главы: абзац главы → символы абзаца
    private var chapterNotedRanges: [Int: [NSRange]] {
        guard chapterStarts.indices.contains(chapterIndex) else { return [:] }
        let start = chapterStarts[chapterIndex]
        var result: [Int: [NSRange]] = [:]
        for note in notes {
            guard let location = note.location, let length = note.length, length > 0 else { continue }
            result[note.paragraph - start, default: []].append(NSRange(location: location, length: length))
        }
        return result
    }

    /// Закладка на открытом месте: на открытой странице, в прокрутке — на абзаце вверху экрана
    private var currentBookmark: BookBookmark? {
        guard chapterStarts.indices.contains(chapterIndex) else { return nil }
        let start = chapterStarts[chapterIndex]
        let range = style.layout == .pages ? pageParagraphs.range.map { (start + $0.lowerBound)...(start + $0.upperBound) } : nil
        return bookmarks.first { range?.contains($0.paragraph) ?? ($0.paragraph == book.position) }
    }

    private func saveNote() {
        guard let draft = noteDraft else { return }
        var list = book.notes
        list.append(BookNote(paragraph: draft.paragraph, text: draft.text,
                             note: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
                             location: draft.range.location, length: draft.range.length))
        book.notes = list
        notes = book.notes
        noteDraft = nil
        Haptics.tap()
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
        modelContext.saveReporting()
        chapters = kept
        numbering = ChapterNumbering(titles: kept.map(\.title))
        var start = 0
        chapterStarts = kept.map { chapter in
            defer { start += chapter.paragraphs.count }
            return start
        }
        chapterIndex = 0
        startParagraph = 0
        contentVersion += 1
        bookNames = nil
        Haptics.tap()
    }

    private func saveBookmarks() {
        book.bookmarks = bookmarks
        bookmarks = book.bookmarks
        modelContext.saveReporting()
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
        modelContext.saveReporting()
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
        modelContext.saveReporting()
        self.alignment = shifted
        updateChapterTranslations()
        translationVersion += 1
    }

    private func removeTranslation() {
        book.setTranslation(nil)
        modelContext.saveReporting()
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
        // Строка оглавления в начале книги — переход в главу, а не карточка слова
        if let target = contentsEntry(chapter.paragraphs[parts[0]]) {
            go(to: target)
            return
        }
        // «Перевод по нажатию» выключен в «Оформлении» читалки — нажатие на слово ничего не делает
        guard AppMode.tapTranslationEnabled else { return }
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

    /// Строка оглавления в тексте («CHAPTER I. Jonathan Harker’s Journal») → глава, куда она ведёт:
    /// название совпадает с названием главы или у обоих одинаковое «CHAPTER <номер>»
    private func contentsEntry(_ text: String) -> Int? {
        guard text.count <= 120 else { return nil }
        let key = Self.contentsKey(text)
        guard key.count >= 3 else { return nil }
        let head = Self.chapterHead(text)
        return chapters.indices.first { index in
            guard index != chapterIndex else { return false }
            let title = chapters[index].title
            if Self.contentsKey(title) == key { return true }
            if let head, Self.chapterHead(title) == head { return true }
            return false
        }
    }

    /// Только буквы и цифры в нижнем регистре: кавычки и точки в оглавлении и в заголовке главы могут различаться
    private static func contentsKey(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// «CHAPTER XIV. …» → «chapter xiv»
    private static func chapterHead(_ text: String) -> String? {
        guard let match = text.firstMatch(of: /(?i)^\s*(chapter|глава)\s+([ivxlcdm]+|\d+)\b/) else { return nil }
        return "\(match.1.lowercased()) \(match.2.lowercased())"
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
    /// Выражения для слов главы собираются один раз, а не на каждый абзац
    nonisolated(unsafe) private static let englishWordRegex = try? NSRegularExpression(pattern: "[A-Za-z]+(?:['’-][A-Za-z]+)*")
    nonisolated(unsafe) private static let anyWordRegex = try? NSRegularExpression(pattern: "\\p{L}+(?:['’-]\\p{L}+)*")

    nonisolated static func linked(_ text: String, paragraph: Int, english: Bool = true, phonics: Set<PhonicsOption>? = nil,
                                   palette: PhonicsPalette = .make(.paper), statuses: BookWordStatusSnapshot? = nil,
                                   cache: inout [String: ReadingRules.Highlight?]) -> AttributedString {
        let ns = text as NSString
        guard let regex = english ? Self.englishWordRegex : Self.anyWordRegex else { return AttributedString(text) }
        let showsColloquial = english && phonics?.contains(.colloquial) == true
        // Кавычки ‘…’ в абзаце — ’ после слова скорее закрывает цитату, чем глотает звук
        let singleQuotes = showsColloquial && text.contains("‘")
        var result = AttributedString()
        var last = 0
        // Словарные формы абзаца считаем, только если есть что красить
        let statuses = statuses?.isEmpty == false ? statuses : nil
        let lemmas = statuses == nil ? [:] : BookWordStatusSnapshot.lemmas(in: text)
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let range = match.range
            if range.location > last {
                result += AttributedString(ns.substring(with: NSRange(location: last, length: range.location - last)))
            }
            var word = AttributedString(ns.substring(with: range))
            word.link = URL(string: "\(wordScheme)://w/\(paragraph)/\(range.location)/\(range.length)")
            if let phonics {
                decorate(&word, ns.substring(with: range), options: phonics, palette: palette, cache: &cache)
            }
            if let statuses, let status = statuses.status(surface: ns.substring(with: range), lemma: lemmas[range.location]) {
                if AppDesign.isSketch {
                    // «Скетч»: цвет текста не меняем (читается так же), слово подчёркнуто маркером
                    word.backgroundColor = Color(hex: status == .learning ? palette.sketchLearningFill : palette.sketchLearnedFill)
                } else {
                    word.foregroundColor = Color(hex: status == .learning ? palette.learning : palette.learned)
                }
            }
            if showsColloquial {
                let before = range.location > 0 ? ns.substring(with: NSRange(location: range.location - 1, length: 1)).first : nil
                let end = NSMaxRange(range)
                let after = ns.substring(with: NSRange(location: end, length: min(2, ns.length - end)))
                if ColloquialForms.form(ns.substring(with: range), before: before, after: after, singleQuotes: singleQuotes) != nil {
                    // Разговорная форма: штрих-точка под словом и курсив (вариант C холста)
                    let line = Color(hex: palette.colloquial.ink)
                    word.underlineStyle = Text.LineStyle(pattern: .dashDot, color: line)
                    word.inlinePresentationIntent = .emphasized
                    word[PhonicsLineKey.self] = PhonicsLine(pattern: 3, color: palette.colloquial.ink)
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
    /// Подсветка правил чтения в слове (вариант C холста «Подсветка правил чтения»): заливка у исключений, немой e и окончаний,
    /// линии разного вида у пар гласных, гласной + r и пар согласных, немые буквы перечёркнуты. Слова через дефис разбираются по частям
    nonisolated static func decorate(_ word: inout AttributedString, _ text: String, options: Set<PhonicsOption>,
                                     palette: PhonicsPalette, cache: inout [String: ReadingRules.Highlight?]) {
        func fill(_ target: Range<AttributedString.Index>, _ entry: PhonicsPalette.Entry, bold: Bool = false) {
            word[target].backgroundColor = Color(hex: entry.fill)
            if bold { word[target].inlinePresentationIntent = .stronglyEmphasized }
        }
        func line(_ target: Range<AttributedString.Index>, _ entry: PhonicsPalette.Entry, pattern: Int) {
            let color = Color(hex: entry.ink)
            let style: Text.LineStyle.Pattern = [.solid, .dash, .dot, .dashDot][pattern]
            word[target].underlineStyle = Text.LineStyle(pattern: style, color: color)
            word[target][PhonicsLineKey.self] = PhonicsLine(pattern: pattern, color: entry.ink)
        }
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
                if span.irregular {
                    fill(target, palette.exception, bold: true)
                    continue
                }
                switch span.kind {
                case .vowelTeam: line(target, palette.vowelPair, pattern: 0)
                case .rVowel: line(target, palette.rControlled, pattern: 1)
                case .consonantPair: line(target, palette.consonantPair, pattern: 2)
                case .magicE: fill(target, palette.magicE)
                case .ending: fill(target, palette.ending)
                case .silent, .plain: break
                }
            }
            for silent in highlight.silent {
                guard let target = range(silent) else { continue }
                let color = Color(hex: palette.silent)
                word[target].foregroundColor = color
                word[target].strikethroughStyle = Text.LineStyle(pattern: .solid, color: color)
                word[target][PhonicsLineKey.self] = PhonicsLine(pattern: 0, color: palette.silent, strike: true)
            }
            // Слово-исключение целиком: заливка и полужирный
            if highlight.isException, let target = range(NSRange(location: 0, length: (piece as NSString).length)) {
                fill(target, palette.exception, bold: true)
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
            Text(isReading || isMarked || !mark.pageQuery.isEmpty ? highlighted : text)
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
        if !mark.pageQuery.isEmpty {
            for found in BookSearch.ranges(of: mark.pageQuery, in: String(text.characters)) {
                if let range = Range(found, in: result) { result[range].backgroundColor = ReaderMark.color }
            }
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
                                .foregroundColor(Color.brandMuted)
                            HStack(alignment: .top) {
                                Text(item.translation ?? "В переводе этот абзац объединён с соседним.")
                                    .scaledFont(size: 17, design: .serif)
                                    .foregroundColor(item.translation == nil ? Color.brandMuted : .brandDark)
                                    .italic(item.translation == nil)
                                Spacer(minLength: 4)
                                if item.translation != nil {
                                    Menu {
                                        ShiftTranslationMenu { onShift(item.id, $0) }
                                    } label: {
                                        Image(systemName: "arrow.up.arrow.down.circle")
                                            .scaledFont(size: 18)
                                            .foregroundColor(Color.brandMuted)
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
