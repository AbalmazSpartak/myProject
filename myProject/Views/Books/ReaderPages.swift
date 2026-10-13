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
    let speech: ReaderSpeech
    let onVisible: (Int) -> Void
    let onTap: (URL) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var pages: [[ReaderPaginator.Segment]] = []
    @State private var page = 0

    private static let horizontalPadding: CGFloat = 28
    private static let topPadding: CGFloat = 16
    private static let footerHeight: CGFloat = 34

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapterID == rhs.chapterID && lhs.paragraphs.count == rhs.paragraphs.count && lhs.readerFont == rhs.readerFont
            && lhs.fontSize == rhs.fontSize && lhs.textColor == rhs.textColor && lhs.lineSpacing == rhs.lineSpacing
    }

    var body: some View {
        GeometryReader { proxy in
            let textSize = CGSize(width: proxy.size.width - Self.horizontalPadding * 2,
                                  height: proxy.size.height - Self.topPadding - Self.footerHeight)
            ZStack(alignment: .bottom) {
                if pages.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $page) {
                        if hasPrevious {
                            edgePage("‹ Предыдущая глава").tag(-1)
                        }
                        ForEach(pages.indices, id: \.self) { index in
                            pageView(pages[index])
                                .padding(.horizontal, Self.horizontalPadding)
                                .padding(.top, Self.topPadding)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .tag(index)
                        }
                        if hasNext {
                            edgePage("Следующая глава ›").tag(pages.count)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Нажатие у края — соседняя страница; поля шире отступа текста, слова они не закрывают
                    .overlay {
                        HStack {
                            edgeTap(-1)
                            Spacer()
                            edgeTap(1)
                        }
                    }
                    Text("\(min(max(page, 0), pages.count - 1) + 1) из \(pages.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textColor.opacity(0.5))
                        .frame(height: Self.footerHeight)
                        .allowsHitTesting(false)
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
            if page == -1 { onPrevious(); return }
            if page == pages.count, hasNext { onNext(); return }
            if let first = pages[safe: page]?.first?.paragraph { onVisible(first) }
        }
        // Чтение вслух листает само: читаемое слово ушло на следующую страницу — перелистываем
        .onChange(of: speech.paragraph) { _, _ in followSpeech() }
        .onChange(of: speech.word) { _, _ in followSpeech() }
    }

    private func pageView(_ segments: [ReaderPaginator.Segment]) -> some View {
        VStack(alignment: .leading, spacing: ReaderPaginator.paragraphSpacing) {
            ForEach(segments, id: \.self) { segment in
                ReaderPageSegment(segment: segment, text: paragraphs[segment.paragraph], font: readerFont.font(size: fontSize),
                                  textColor: textColor, lineSpacing: lineSpacing, speech: speech)
            }
        }
    }

    private func edgePage(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(textColor.opacity(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func edgeTap(_ step: Int) -> some View {
        Color.clear
            .frame(width: Self.horizontalPadding - 4)
            .contentShape(Rectangle())
            .onTapGesture {
                let target = page + step
                guard target >= (hasPrevious ? -1 : 0), target <= (hasNext ? pages.count : pages.count - 1) else { return }
                withAnimation(.easeInOut(duration: 0.3)) { page = target }
            }
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
        withAnimation(.easeInOut(duration: 0.3)) { page = target }
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
