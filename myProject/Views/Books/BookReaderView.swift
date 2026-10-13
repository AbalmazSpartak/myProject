import SwiftUI
import SwiftData

/// Слово, на которое нажали в книге, и предложение вокруг него
struct TappedWord: Identifiable {
    let id = UUID()
    let word: String
    let sentence: String
    /// Где слово в предложении — для словарной формы
    let range: Range<String.Index>
}

/// Читалка: глава прокручивается, нажатие на слово — перевод; место чтения запоминается
struct BookReaderView: View {
    @Environment(\.dismiss) private var dismiss
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
    @State private var isShowingContents = false
    @State private var isShowingDictionary = false
    @State private var isShowingAppearance = false

    /// Оформление — снимок настроек: обновляется после шторки «Оформление»
    @State private var style = ReaderStyle.current()
    /// Чтение вслух
    @State private var speech = ReaderSpeech()
    /// Глава дочитана вслух — следующую начать читать, как только она готова
    @State private var continuesReading = false
    @AppStorage(ReaderSpeech.speedKey) private var speechSpeed = 1.0

    nonisolated private static let wordScheme = "wlword"

    private var chapter: BookChapter? {
        chapters.indices.contains(chapterIndex) ? chapters[chapterIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
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
                    speech: speech,
                    onVisible: { paragraph in
                        guard chapterStarts.indices.contains(chapterIndex) else { return }
                        book.position = chapterStarts[chapterIndex] + paragraph
                    },
                    onTap: handleTap,
                    onPrevious: { go(to: chapterIndex - 1, atEnd: true) },
                    onNext: { go(to: chapterIndex + 1) }
                )
                .equatable()
                .id(chapterIndex)
            } else if let linkedParagraphs {
                ReaderChapterText(
                    chapterID: chapterIndex,
                    paragraphs: linkedParagraphs,
                    font: style.font.font(size: style.fontSize),
                    textColor: style.text,
                    lineSpacing: style.fontSize * style.spacing.factor,
                    startParagraph: startParagraph,
                    speech: speech,
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
                .id(chapterIndex)
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
        // Глава готовится, когда главы загружены и при каждой смене главы
        .task(id: "\(chapters.count)-\(chapterIndex)") { await prepareChapter() }
        .sheet(item: $tappedWord) { tapped in
            WordLookupView(tapped: tapped, bookTitle: book.title)
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingContents) { contents }
        .sheet(isPresented: $isShowingAppearance, onDismiss: { style = .current() }) {
            ReaderAppearanceSheet()
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingDictionary) {
            BookDictionaryView(book: book)
                .appThemedColorScheme()
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Книги")
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(style.text)
            }
            Spacer()
            Button { isShowingContents = true } label: {
                Text(chapter?.title ?? book.title)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(style.text)
                    .lineLimit(1)
            }
            .accessibilityHint("Оглавление")
            Spacer()
            Button(action: toggleReading) {
                Image(systemName: speech.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .scaledFont(size: 24)
                    .foregroundColor(style.text)
            }
            .accessibilityLabel(speech.isPlaying ? "Пауза" : "Читать вслух")
            Button { isShowingAppearance = true } label: {
                Text("Aa")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundColor(style.text)
            }
            .accessibilityLabel("Оформление")
            Menu {
                Button { isShowingContents = true } label: {
                    Label("Оглавление", systemImage: "list.bullet")
                }
                Button { isShowingDictionary = true } label: {
                    Label("Словарь из книги", systemImage: "text.book.closed")
                }
                Button { isShowingAppearance = true } label: {
                    Label("Оформление", systemImage: "textformat.size")
                }
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
        var start = 0
        chapterStarts = chapters.map { chapter in
            defer { start += chapter.paragraphs.count }
            return start
        }
        let position = book.position
        chapterIndex = chapterStarts.lastIndex { $0 <= position } ?? 0
        startParagraph = position - (chapterStarts.indices.contains(chapterIndex) ? chapterStarts[chapterIndex] : 0)
        book.lastOpenedAt = Date()
    }

    /// Ссылки на слова для всей главы — в фоне, один раз
    private func prepareChapter() async {
        guard let chapter else { return }
        linkedParagraphs = nil
        let paragraphs = chapter.paragraphs
        linkedParagraphs = await Task.detached(priority: .userInitiated) {
            paragraphs.enumerated().map { Self.linked($1, paragraph: $0) }
        }.value
        speech.load(paragraphs: paragraphs, chapterTitle: chapter.title, bookTitle: book.title)
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

    /// atEnd — листают назад с первой страницы: предыдущая глава открывается на последней странице
    private func go(to index: Int, atEnd: Bool = false) {
        guard chapters.indices.contains(index) else { return }
        speech.stop()
        startParagraph = atEnd ? max(chapters[index].paragraphs.count - 1, 0) : 0
        chapterIndex = index
        book.position = chapterStarts[index] + startParagraph
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
        tappedWord = TappedWord(word: String(paragraph[range]), sentence: sentence, range: start..<end)
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

    /// Абзац, где каждое английское слово — ссылка на себя
    nonisolated static func linked(_ text: String, paragraph: Int) -> AttributedString {
        let ns = text as NSString
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z]+(?:['’-][A-Za-z]+)*") else { return AttributedString(text) }
        var result = AttributedString()
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let range = match.range
            if range.location > last {
                result += AttributedString(ns.substring(with: NSRange(location: last, length: range.location - last)))
            }
            var word = AttributedString(ns.substring(with: range))
            word.link = URL(string: "\(wordScheme)://w/\(paragraph)/\(range.location)/\(range.length)")
            result += word
            last = range.location + range.length
        }
        if last < ns.length {
            result += AttributedString(ns.substring(from: last))
        }
        return result
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
    let onVisible: (Int) -> Void
    let onTap: (URL) -> Void
    @ViewBuilder let navigation: () -> Navigation

    /// Видимые абзацы — в обычном объекте, а не в @State: их смена при прокрутке не перерисовывает главу
    @State private var visible = VisibleParagraphs()

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapterID == rhs.chapterID && lhs.paragraphs.count == rhs.paragraphs.count
            && lhs.font == rhs.font && lhs.textColor == rhs.textColor && lhs.lineSpacing == rhs.lineSpacing
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(paragraphs.indices, id: \.self) { index in
                        ReaderParagraph(index: index, text: paragraphs[index], font: font, textColor: textColor,
                                        lineSpacing: lineSpacing, speech: speech)
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

    var body: some View {
        let isReading = speech.paragraph == index
        Text(isReading ? highlighted : text)
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
    }

    private var highlighted: AttributedString {
        var result = text
        if let word = speech.word, let range = Range(word, in: result) {
            result[range].backgroundColor = Color.yellow.opacity(0.45)
        }
        return result
    }
}

/// Какие абзацы сейчас на экране. Класс без наблюдения: запись не вызывает перерисовку
private final class VisibleParagraphs {
    var ids: [Int] = []
}
