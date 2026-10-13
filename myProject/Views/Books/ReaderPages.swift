import SwiftUI
import UIKit

/// Деление главы на страницы под экран и оформление: TextKit раскладывает текст по «листам» нужного размера.
/// Абзац может начаться на одной странице и закончиться на следующей — страница хранит куски абзацев
nonisolated enum ReaderPaginator {
    /// Кусок абзаца на странице: номер абзаца и символы (UTF-16, как NSRange)
    struct Segment: Hashable, Sendable {
        let paragraph: Int
        let range: NSRange
    }

    static let paragraphSpacing: CGFloat = 14

    static func pages(paragraphs: [String], font: UIFont, lineSpacing: CGFloat, size: CGSize) -> [[Segment]] {
        guard size.width > 50, size.height > 50, !paragraphs.isEmpty else { return [] }
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = paragraphSpacing
        let storage = NSTextStorage(string: paragraphs.joined(separator: "\n"),
                                    attributes: [.font: font, .paragraphStyle: style])
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        var starts: [Int] = []
        var offset = 0
        for paragraph in paragraphs {
            starts.append(offset)
            offset += (paragraph as NSString).length + 1
        }

        var result: [[Segment]] = []
        while result.count < 10_000 {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let glyphs = layout.glyphRange(for: container)
            guard glyphs.length > 0 else { break }
            let chars = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            let segments = paragraphs.indices.compactMap { index -> Segment? in
                let length = (paragraphs[index] as NSString).length
                let from = max(chars.location, starts[index]), to = min(NSMaxRange(chars), starts[index] + length)
                return to > from ? Segment(paragraph: index, range: NSRange(location: from - starts[index], length: to - from)) : nil
            }
            if !segments.isEmpty { result.append(segments) }
            if NSMaxRange(chars) >= storage.length { break }
        }
        return result
    }
}

/// Раскладка одной страницы для нажатий и выделения — та же TextKit, что при делении на страницы:
/// какой символ под пальцем, где слово, где края выделения. Символы — по тексту страницы, куски абзацев через «\n»
nonisolated final class ReaderPageLayout {
    let segments: [ReaderPaginator.Segment]
    let text: NSString
    /// С какого символа текста страницы начинается каждый кусок абзаца
    let offsets: [Int]
    private let storage: NSTextStorage
    private let manager = NSLayoutManager()
    private let container: NSTextContainer
    private let lineSpacing: CGFloat

    init(segments: [ReaderPaginator.Segment], paragraphs: [String], font: UIFont, lineSpacing: CGFloat, width: CGFloat) {
        self.segments = segments
        self.lineSpacing = lineSpacing
        let pieces = segments.map { (paragraphs[$0.paragraph] as NSString).substring(with: $0.range) }
        var offsets: [Int] = []
        var offset = 0
        for piece in pieces {
            offsets.append(offset)
            offset += (piece as NSString).length + 1
        }
        self.offsets = offsets
        let joined = pieces.joined(separator: "\n")
        text = joined as NSString
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacing = ReaderPaginator.paragraphSpacing
        storage = NSTextStorage(string: joined, attributes: [.font: font, .paragraphStyle: style])
        storage.addLayoutManager(manager)
        container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
    }

    /// Символ под точкой: exact — только если палец на самом символе (нажатие), иначе ближайший (протягивание)
    func index(at point: CGPoint, exact: Bool) -> Int? {
        guard text.length > 0 else { return nil }
        let glyph = manager.glyphIndex(for: point, in: container, fractionOfDistanceThroughGlyph: nil)
        if exact {
            let rect = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
            guard rect.insetBy(dx: -6, dy: -max(lineSpacing, 6)).contains(point) else { return nil }
        }
        return min(manager.characterIndexForGlyph(at: glyph), text.length - 1)
    }

    /// Английское слово, в котором стоит символ
    func word(at index: Int) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: "[A-Za-z]+(?:['’-][A-Za-z]+)*") else { return nil }
        return regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
            .first { NSLocationInRange(index, $0.range) }?.range
    }

    /// Где на странице символ — для «ручек» выделения
    func rect(of index: Int) -> CGRect {
        let glyphs = manager.glyphRange(forCharacterRange: NSRange(location: index, length: 1), actualCharacterRange: nil)
        return manager.boundingRect(forGlyphRange: glyphs, in: container)
    }

    /// Часть выделения в куске абзаца — в символах куска; nil — кусок не выделен
    func local(_ range: NSRange, segment index: Int) -> NSRange? {
        let length = segments[index].range.length
        let from = max(range.location, offsets[index]), to = min(NSMaxRange(range), offsets[index] + length)
        return to > from ? NSRange(location: from - offsets[index], length: to - from) : nil
    }

    /// Символ страницы → абзац главы и место в нём
    func paragraphPosition(of range: NSRange) -> (paragraph: Int, range: NSRange)? {
        guard let index = offsets.lastIndex(where: { $0 <= range.location }) else { return nil }
        let segment = segments[index]
        return (segment.paragraph, NSRange(location: range.location - offsets[index] + segment.range.location, length: range.length))
    }

    /// Выделенный текст: абзацы — через пробел, для перевода и озвучки
    func string(_ range: NSRange) -> String {
        text.substring(with: range).replacingOccurrences(of: "\n", with: " ")
    }
}

extension ReaderFont {
    /// Тот же шрифт, что в тексте читалки, — для расчёта страниц
    nonisolated func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .serif:
            let base = UIFont.systemFont(ofSize: size)
            return base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
        case .sans: return .systemFont(ofSize: size)
        case .georgia: return UIFont(name: "Georgia", size: size) ?? .systemFont(ofSize: size)
        }
    }
}

/// Глава по страницам: листается свайпом или нажатием у края, со сдвигом.
/// С первой страницы назад — предыдущая глава, с последней вперёд — следующая
struct ReaderPagedText: View, Equatable {
    let chapterID: Int
    let paragraphs: [AttributedString]
    let plainParagraphs: [String]
    let readerFont: ReaderFont
    let fontSize: CGFloat
    let textColor: Color
    let lineSpacing: CGFloat
    let startParagraph: Int
    let hasPrevious: Bool
    let hasNext: Bool
    /// Загиб страницы вместо сдвига
    let curl: Bool
    /// false — страница меняется мгновенно, и нажатием у края, и свайпом
    let animated: Bool
    let background: Color
    let speech: ReaderSpeech
    /// Для «В словарь» в панели выделения
    let bookTitle: String
    let onVisible: (Int) -> Void
    let onTap: (URL) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var pages: [[ReaderPaginator.Segment]] = []
    @State private var page = 0
    /// Нажатие на страницу: где и когда началось, сдвинулся ли палец (тогда это свайп), сработало ли долгое
    @State private var press: (start: Date, location: CGPoint, moved: Bool, long: Bool)?
    @State private var longPress: Task<Void, Never>?

    /// Выделение текста долгим нажатием: страница, выделенные символы и слово, с которого начали
    @State private var selection: (page: Int, range: NSRange, anchor: NSRange)?
    @State private var selectionLayout: ReaderPageLayout?
    /// Что сейчас тянет палец: продолжение долгого нажатия или одна из «ручек»
    @State private var dragMode: DragMode?

    private enum DragMode { case extend, start, end }

    /// Доля ширины у каждого края, где нажатие листает
    private static let edgeZone: CGFloat = 0.25

    private static let horizontalPadding: CGFloat = 28
    private static let topPadding: CGFloat = 16
    private static let footerHeight: CGFloat = 34

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapterID == rhs.chapterID && lhs.paragraphs.count == rhs.paragraphs.count && lhs.readerFont == rhs.readerFont
            && lhs.fontSize == rhs.fontSize && lhs.textColor == rhs.textColor && lhs.lineSpacing == rhs.lineSpacing
            && lhs.curl == rhs.curl && lhs.animated == rhs.animated && lhs.background == rhs.background && lhs.bookTitle == rhs.bookTitle
    }

    var body: some View {
        GeometryReader { proxy in
            let textSize = CGSize(width: proxy.size.width - Self.horizontalPadding * 2,
                                  height: proxy.size.height - Self.topPadding - Self.footerHeight)
            ZStack(alignment: .bottom) {
                if pages.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Сдвиг и загиб — системный UIPageViewController: только у него листание надёжно выключается,
                    // пока выделяют текст (у TabView .scrollDisabled страницу не держал — проверено на iPhone)
                    PageCurlView(page: $page, range: (hasPrevious ? -1 : 0)...(hasNext ? pages.count : pages.count - 1),
                                 curl: curl, animated: animated, background: UIColor(background), isLocked: selection != nil) { index in
                        AnyView(pageContent(index, width: proxy.size.width, textWidth: textSize.width))
                    }
                    .id("\(curl)-\(animated)")
                    Text("\(min(max(page, 0), pages.count - 1) + 1) из \(pages.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.5))
                        .frame(height: Self.footerHeight)
                        .allowsHitTesting(false)
                    // Палец отпустили — панель с выделенным: перевод, озвучка, копирование, в словарь
                    if let selection, press == nil, let layout = selectionLayout {
                        ReaderSelectionPanel(text: layout.string(selection.range), bookTitle: bookTitle) { clearSelection() }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .task(id: "\(Int(textSize.width))x\(Int(textSize.height))-\(readerFont.rawValue)-\(fontSize)-\(lineSpacing)") {
                await paginate(textSize)
            }
        }
        .tint(textColor)
        .environment(\.openURL, OpenURLAction { url in
            onTap(url)
            return .handled
        })
        .onChange(of: page) { _, page in
            clearSelection()
            if page == -1 { onPrevious(); return }
            if page == pages.count, hasNext { onNext(); return }
            if let first = pages[safe: page]?.first?.paragraph { onVisible(first) }
        }
        // Чтение вслух листает само: читаемое слово ушло на следующую страницу — перелистываем
        .onChange(of: speech.paragraph) { _, _ in followSpeech() }
        .onChange(of: speech.word) { _, _ in followSpeech() }
    }

    /// Страница целиком: -1 и pages.count — переходы в соседние главы
    @ViewBuilder
    private func pageContent(_ index: Int, width: CGFloat, textWidth: CGFloat) -> some View {
        if index == -1 {
            edgePage("‹ Предыдущая глава")
        } else if index == pages.count {
            edgePage("Следующая глава ›")
        } else if let segments = pages[safe: index] {
            pageView(segments, page: index)
                .overlay(alignment: .topLeading) { handles(page: index) }
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.top, Self.topPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(background)
                .contentShape(Rectangle())
                // Вместе со свайпом, а не вместо: сдвиг пальца — листание свайпом
                .simultaneousGesture(pressGesture(page: index, width: width, textWidth: textWidth))
        }
    }

    private func pageView(_ segments: [ReaderPaginator.Segment], page index: Int) -> some View {
        VStack(alignment: .leading, spacing: ReaderPaginator.paragraphSpacing) {
            ForEach(Array(segments.enumerated()), id: \.element) { number, segment in
                ReaderPageSegment(segment: segment, text: paragraphs[segment.paragraph], font: readerFont.font(size: fontSize),
                                  textColor: textColor, lineSpacing: lineSpacing, speech: speech,
                                  selected: selectedPart(page: index, segment: number))
            }
        }
    }

    private func selectedPart(page index: Int, segment: Int) -> NSRange? {
        guard let selection, selection.page == index, let layout = selectionLayout else { return nil }
        return layout.local(selection.range, segment: segment)
    }

    /// «Ручки» выделения, как в iOS: у начала — точка сверху, у конца — снизу; за них тянут края
    @ViewBuilder
    private func handles(page index: Int) -> some View {
        if let selection, selection.page == index, let layout = selectionLayout {
            let first = layout.rect(of: selection.range.location)
            let last = layout.rect(of: NSMaxRange(selection.range) - 1)
            ZStack(alignment: .topLeading) {
                handle(height: first.height, dotOnTop: true)
                    .offset(x: first.minX - 5, y: first.minY - 10)
                handle(height: last.height, dotOnTop: false)
                    .offset(x: last.maxX - 5, y: last.minY)
            }
            .allowsHitTesting(false)
        }
    }

    private func handle(height: CGFloat, dotOnTop: Bool) -> some View {
        VStack(spacing: 0) {
            if dotOnTop { Circle().frame(width: 10, height: 10) }
            Rectangle().frame(width: 2, height: height)
            if !dotOnTop { Circle().frame(width: 10, height: 10) }
        }
        .frame(width: 10)
        .foregroundColor(.accentColor)
    }

    private func edgePage(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(textColor.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
    }

    // MARK: - Нажатия: края листают, слово в середине — перевод, долгое нажатие — перевод где угодно

    private func pressGesture(page index: Int, width: CGFloat, textWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if press == nil {
                    press = (Date(), value.startLocation, false, false)
                    if let selection, selection.page == index, let layout = selectionLayout {
                        // Палец у края выделения — тянем этот край
                        let point = textPoint(value.startLocation)
                        let first = layout.rect(of: selection.range.location)
                        let last = layout.rect(of: NSMaxRange(selection.range) - 1)
                        if hypot(point.x - first.minX, point.y - first.midY) < 34 { dragMode = .start }
                        else if hypot(point.x - last.maxX, point.y - last.midY) < 34 { dragMode = .end }
                    } else {
                        longPress?.cancel()
                        longPress = Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            guard !Task.isCancelled, let current = press, !current.moved else { return }
                            press?.long = true
                            beginSelection(at: current.location, page: index, textWidth: textWidth)
                        }
                    }
                }
                if hypot(value.translation.width, value.translation.height) > 10 { press?.moved = true }
                if dragMode != nil { moveSelection(to: value.location) }
            }
            .onEnded { value in
                longPress?.cancel()
                defer {
                    press = nil
                    dragMode = nil
                }
                guard let current = press else { return }
                if current.long {
                    // Долгое нажатие без протягивания — привычная карточка слова
                    if let selection, NSEqualRanges(selection.range, selection.anchor) {
                        openWord(selection.anchor)
                        clearSelection()
                    }
                    return
                }
                guard dragMode == nil else { return }
                if current.moved {
                    // Без анимации свайп листает сам: системный сдвиг выключен
                    let dx = value.translation.width
                    if !animated, selection == nil, abs(dx) > 40, abs(dx) > abs(value.translation.height) {
                        turn(dx < 0 ? 1 : -1)
                    }
                    return
                }
                // Нажатие мимо выделения — снять его
                if selection != nil {
                    clearSelection()
                    return
                }
                let x = value.location.x
                if x < width * Self.edgeZone {
                    turn(-1)
                } else if x > width * (1 - Self.edgeZone) {
                    turn(1)
                } else {
                    translate(at: value.location, page: index, textWidth: textWidth)
                }
            }
    }

    private func textPoint(_ location: CGPoint) -> CGPoint {
        CGPoint(x: location.x - Self.horizontalPadding, y: location.y - Self.topPadding)
    }

    private func layout(page index: Int, textWidth: CGFloat) -> ReaderPageLayout? {
        guard let segments = pages[safe: index] else { return nil }
        return ReaderPageLayout(segments: segments, paragraphs: plainParagraphs, font: readerFont.uiFont(size: fontSize),
                                lineSpacing: lineSpacing, width: textWidth)
    }

    /// Долгое нажатие на слово — оно выделено, дальше палец тянет выделение
    private func beginSelection(at location: CGPoint, page index: Int, textWidth: CGFloat) {
        guard let layout = layout(page: index, textWidth: textWidth),
              let character = layout.index(at: textPoint(location), exact: true),
              let word = layout.word(at: character) else { return }
        Haptics.tap()
        selectionLayout = layout
        selection = (index, word, word)
        dragMode = .extend
    }

    /// Протягивание: выделение до слова под пальцем — от слова, с которого начали, или от неподвижного края
    private func moveSelection(to location: CGPoint) {
        guard var current = selection, let layout = selectionLayout, let mode = dragMode,
              let character = layout.index(at: textPoint(location), exact: false) else { return }
        let word = layout.word(at: character) ?? NSRange(location: character, length: 1)
        switch mode {
        case .extend:
            current.range = NSUnionRange(current.anchor, word)
        case .start:
            let end = NSMaxRange(current.range)
            guard word.location < end else { return }
            current.range = NSRange(location: word.location, length: end - word.location)
        case .end:
            let end = NSMaxRange(word)
            guard end > current.range.location else { return }
            current.range = NSRange(location: current.range.location, length: end - current.range.location)
        }
        if !NSEqualRanges(current.range, selection?.range ?? NSRange()) { selection = current }
    }

    private func clearSelection() {
        guard selection != nil else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            selection = nil
            selectionLayout = nil
        }
    }

    /// Слово страницы → та же ссылка, что у слов в прокрутке: читалка покажет карточку слова
    private func openWord(_ range: NSRange) {
        guard let position = selectionLayout?.paragraphPosition(of: range),
              let url = URL(string: "wlword://w/\(position.paragraph)/\(position.range.location)/\(position.range.length)") else { return }
        onTap(url)
    }

    private func turn(_ step: Int) {
        let target = page + step
        guard target >= (hasPrevious ? -1 : 0), target <= (hasNext ? pages.count : pages.count - 1) else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) { page = target }
        } else {
            page = target
        }
    }

    /// Нажатие на слово в середине страницы — карточка слова
    private func translate(at location: CGPoint, page index: Int, textWidth: CGFloat) {
        guard let layout = layout(page: index, textWidth: textWidth),
              let character = layout.index(at: textPoint(location), exact: true),
              let word = layout.word(at: character),
              let position = layout.paragraphPosition(of: word),
              let url = URL(string: "wlword://w/\(position.paragraph)/\(position.range.location)/\(position.range.length)") else { return }
        onTap(url)
    }

    /// Страницы — в фоне; запас в полстроки снизу: SwiftUI и TextKit могут разойтись на пиксель-другой
    private func paginate(_ size: CGSize) async {
        let plain = plainParagraphs, font = readerFont, fontSize = fontSize, lineSpacing = lineSpacing
        let height = size.height - fontSize * 0.6
        let result = await Task.detached(priority: .userInitiated) {
            ReaderPaginator.pages(paragraphs: plain, font: font.uiFont(size: fontSize), lineSpacing: lineSpacing,
                                  size: CGSize(width: size.width, height: height))
        }.value
        guard !result.isEmpty else { return }
        let keep = pages.isEmpty ? startParagraph : (pages[safe: page]?.first?.paragraph ?? startParagraph)
        pages = result
        page = result.firstIndex { $0.contains { $0.paragraph == keep } } ?? 0
    }

    private func followSpeech() {
        guard speech.isPlaying, let paragraph = speech.paragraph else { return }
        let location = speech.word?.location ?? 0
        guard let target = pages.firstIndex(where: { segments in
            segments.contains { $0.paragraph == paragraph && location >= $0.range.location && location < NSMaxRange($0.range) }
        }), target != page else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) { page = target }
        } else {
            page = target
        }
    }
}

/// Кусок абзаца на странице; читаемый вслух — с фоном, произносимое слово — жёлтым
private struct ReaderPageSegment: View {
    let segment: ReaderPaginator.Segment
    let text: AttributedString
    let font: Font
    let textColor: Color
    let lineSpacing: CGFloat
    let speech: ReaderSpeech
    /// Выделенное долгим нажатием — в символах этого куска
    let selected: NSRange?

    var body: some View {
        let isReading = speech.paragraph == segment.paragraph
        Text(slice(highlighting: isReading))
            .font(font)
            .foregroundColor(textColor)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isReading {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(textColor.opacity(0.06))
                        .padding(-6)
                }
            }
    }

    private func slice(highlighting: Bool) -> AttributedString {
        guard let range = Range(segment.range, in: text) else { return text }
        var result = AttributedString(text[range])
        // Нажатия на страницах разбирает сама страница — ссылки у слов не нужны
        result.link = nil
        if let selected, let selectedRange = Range(selected, in: result) {
            result[selectedRange].backgroundColor = Color.accentColor.opacity(0.28)
        }
        if highlighting, let word = speech.word {
            let local = NSRange(location: word.location - segment.range.location, length: word.length)
            if local.location >= 0, NSMaxRange(local) <= segment.range.length, let wordRange = Range(local, in: result) {
                result[wordRange].backgroundColor = Color.yellow.opacity(0.45)
            }
        }
        return result
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Листание страниц системным UIPageViewController: сдвигом или с загибом, как в бумажной книге.
/// Страницы — SwiftUI-виды; номер страницы общий для свайпа, нажатий у края и чтения вслух
struct PageCurlView: UIViewControllerRepresentable {
    @Binding var page: Int
    let range: ClosedRange<Int>
    /// true — загиб страницы, false — сдвиг
    let curl: Bool
    /// false — без анимации: свайп не тянет страницу, смена мгновенная
    var animated = true
    let background: UIColor
    /// Идёт выделение текста — страница не листается
    var isLocked = false
    let content: (Int) -> AnyView

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: curl ? .pageCurl : .scroll, navigationOrientation: .horizontal)
        if curl { controller.isDoubleSided = false }
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.view.backgroundColor = background
        controller.setViewControllers([context.coordinator.host(page)], direction: .forward, animated: false)
        // Нажатия у края разбирает сама страница — системные отключаем, иначе страница перелистнётся дважды
        controller.gestureRecognizers.filter { $0 is UITapGestureRecognizer }.forEach { $0.isEnabled = false }
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        controller.view.backgroundColor = background
        // Выделяют текст — листание стоит: у загиба — его жесты, у сдвига — прокрутка внутри
        controller.gestureRecognizers.filter { !($0 is UITapGestureRecognizer) }.forEach { $0.isEnabled = !isLocked }
        controller.view.subviews.compactMap { $0 as? UIScrollView }.forEach { $0.isScrollEnabled = !isLocked }
        guard let current = controller.viewControllers?.first as? PageHost else { return }
        if current.index == page {
            current.rootView = content(page)
            current.view.backgroundColor = background
        } else if !context.coordinator.isTurning {
            controller.setViewControllers([context.coordinator.host(page)],
                                          direction: page > current.index ? .forward : .reverse, animated: animated)
        }
    }

    final class PageHost: UIHostingController<AnyView> {
        var index = 0
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageCurlView
        /// Палец ведёт страницу — номер меняет сам UIPageViewController
        var isTurning = false

        init(_ parent: PageCurlView) { self.parent = parent }

        func host(_ index: Int) -> PageHost {
            let host = PageHost(rootView: parent.content(index))
            host.index = index
            host.view.backgroundColor = parent.background
            return host
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard !parent.isLocked, parent.animated, let index = (viewController as? PageHost)?.index, parent.range.contains(index - 1) else { return nil }
            return host(index - 1)
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard !parent.isLocked, parent.animated, let index = (viewController as? PageHost)?.index, parent.range.contains(index + 1) else { return nil }
            return host(index + 1)
        }

        func pageViewController(_ controller: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(_ controller: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTurning = false
            if completed, let index = (controller.viewControllers?.first as? PageHost)?.index {
                parent.page = index
            }
        }
    }
}
