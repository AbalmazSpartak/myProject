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
    /// Верхний видимый абзац главы
    @State private var visibleParagraph: Int?
    @State private var tappedWord: TappedWord?
    @State private var isShowingContents = false
    @State private var isShowingDictionary = false

    private static let wordScheme = "wlword"

    private var chapter: BookChapter? {
        chapters.indices.contains(chapterIndex) ? chapters[chapterIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            if let chapter {
                text(of: chapter)
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .readableColumn(720)
        .task { open() }
        .onChange(of: visibleParagraph) { _, paragraph in
            guard let paragraph, chapterStarts.indices.contains(chapterIndex) else { return }
            book.position = chapterStarts[chapterIndex] + paragraph
        }
        .sheet(item: $tappedWord) { tapped in
            WordLookupView(tapped: tapped, bookTitle: book.title)
                .presentationDetents([.medium, .large])
                .appThemedColorScheme()
        }
        .sheet(isPresented: $isShowingContents) { contents }
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
                .foregroundColor(.brandDark)
            }
            Spacer()
            Button { isShowingContents = true } label: {
                Text(chapter?.title ?? book.title)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
                    .lineLimit(1)
            }
            .accessibilityHint("Оглавление")
            Spacer()
            Menu {
                Button { isShowingContents = true } label: {
                    Label("Оглавление", systemImage: "list.bullet")
                }
                Button { isShowingDictionary = true } label: {
                    Label("Словарь из книги", systemImage: "text.book.closed")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .scaledFont(size: 22)
                    .foregroundColor(.brandDark)
            }
            .accessibilityLabel("Ещё")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Текст главы

    private func text(of chapter: BookChapter) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(chapter.paragraphs.indices, id: \.self) { index in
                    Text(Self.linked(chapter.paragraphs[index], paragraph: index))
                        .scaledFont(size: 19, design: .serif)
                        .foregroundColor(.brandDark)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(index)
                }
                chapterNavigation
                    .padding(.top, 20)
            }
            .scrollTargetLayout()
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .scrollPosition(id: $visibleParagraph, anchor: .top)
        // Слова — ссылки: цвет обычного текста, нажатие открывает перевод
        .tint(.brandDark)
        .environment(\.openURL, OpenURLAction { url in
            handleTap(url)
            return .handled
        })
        .id(chapterIndex)
    }

    private var chapterNavigation: some View {
        HStack {
            if chapterIndex > 0 {
                Button { go(to: chapterIndex - 1) } label: {
                    Label("Назад", systemImage: "chevron.left")
                }
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
                    .foregroundColor(.gray)
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
        let paragraph = position - (chapterStarts.indices.contains(chapterIndex) ? chapterStarts[chapterIndex] : 0)
        book.lastOpenedAt = Date()
        // Прокрутка к месту — после того как глава отрисовалась
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            visibleParagraph = paragraph
        }
    }

    private func go(to index: Int) {
        guard chapters.indices.contains(index) else { return }
        chapterIndex = index
        visibleParagraph = 0
        book.position = chapterStarts[index]
    }

    /// wlword://w/<абзац>/<начало>/<длина> — в UTF-16, как NSRange
    private func handleTap(_ url: URL) {
        guard url.scheme == Self.wordScheme, let chapter else { return }
        let parts = url.pathComponents.compactMap(Int.init)
        guard parts.count == 3, chapter.paragraphs.indices.contains(parts[0]) else { return }
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
    static func linked(_ text: String, paragraph: Int) -> AttributedString {
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
