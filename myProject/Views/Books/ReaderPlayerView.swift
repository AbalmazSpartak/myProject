import SwiftUI

/// Таймер сна для чтения вслух: через время или в конце главы
enum SleepTimer: Hashable {
    case off
    case minutes(Int)
    case chapterEnd

    static let options: [SleepTimer] = [.off, .minutes(15), .minutes(30), .minutes(45), .minutes(60), .chapterEnd]

    var title: String {
        switch self {
        case .off: return "Выключен"
        case .minutes(let minutes): return "Через \(minutes) мин"
        case .chapterEnd: return "В конце главы"
        }
    }
}

/// Экран слушания: обложка, глава, полоса прогресса со временем, пауза и перемотка, таймер сна, скорость.
/// Лежит поверх читалки, чтение идёт тем же голосом; «Текст» убирает экран, и книга читается глазами
struct ReaderPlayerView: View {
    let book: Book
    let chapterTitle: String
    /// «Глава 2 из 12 · название» — номера считаются без титула и содержания; у них только название
    let chapterLabel: String
    /// Номер раздела в списке с единицы — для кнопок «предыдущая/следующая»
    let chapterNumber: Int
    let chapterCount: Int
    let paragraphs: [String]
    let speech: ReaderSpeech
    @Binding var speed: Double
    let sleep: SleepTimer
    let sleepEndsAt: Date?
    let onSleep: (SleepTimer) -> Void
    let onToggle: () -> Void
    /// Номер абзаца в главе, с которого читать
    let onSeek: (Int) -> Void
    /// -1 — предыдущая глава, 1 — следующая
    let onChapter: (Int) -> Void
    let onChapters: () -> Void
    let onClose: () -> Void

    /// Сколько знаков в секунду на скорости 1×: время считается по тексту, поэтому приблизительное
    private static let charsPerSecond = 14.0

    /// Сколько знаков в главе до начала каждого абзаца
    @State private var starts: [Int] = []
    @State private var total = 0
    /// Пока двигают ползунок — его значение, а не место чтения
    @State private var dragFraction: Double?

    private var coverWidth: CGFloat { PadLayout.isPad ? 220 : 170 }

    private var spoken: Int {
        guard let paragraph = speech.paragraph, starts.indices.contains(paragraph) else { return 0 }
        return starts[paragraph] + (speech.word?.location ?? 0)
    }

    private var fraction: Double {
        dragFraction ?? (total > 0 ? min(Double(spoken) / Double(total), 1) : 0)
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
            ScrollView {
                VStack(spacing: 22) {
                    topBar
                    cover
                    titleBlock
                    progress
                    controls
                    preparingNote
                    tools
                    chaptersButton
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: PadLayout.columnWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .task(id: chapterTitle) { prepare() }
    }

    // MARK: - Верх

    /// Размытая обложка сверху, плавно уходит в фон
    private var background: some View {
        Group {
            if let data = book.coverData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 30)
                    .opacity(0.5)
            } else {
                Color.brandTint.opacity(0.3)
            }
        }
        .frame(height: 300)
        .clipped()
        .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .scaledFont(size: 20, weight: .semibold)
                    .foregroundColor(.brandDark)
                    .frame(width: 40, height: 40, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Скрыть плеер")
            Spacer()
        }
        .padding(.top, 8)
    }

    private var cover: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: coverWidth)
            .overlay { BookCover(data: book.coverData, title: book.title) }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(book.title)
                .scaledFont(size: 22, weight: .bold, design: .serif)
                .foregroundColor(.brandDark)
                .multilineTextAlignment(.center)
            if !book.author.isEmpty {
                Text(book.author)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
            }
            Text(chapterLabel)
                .scaledFont(size: 14)
                .foregroundColor(Color.brandMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - Прогресс и кнопки

    private var progress: some View {
        VStack(spacing: 2) {
            Slider(value: Binding(get: { fraction }, set: { dragFraction = $0 }), in: 0...1) { editing in
                if !editing, let value = dragFraction {
                    dragFraction = nil
                    seek(to: value)
                }
            }
            .tint(.brandTint)
            HStack {
                Text(clock(fraction * seconds))
                Spacer()
                Text(clock(seconds))
            }
            .scaledFont(size: 13)
            .foregroundColor(Color.brandMuted)
            .monospacedDigit()
        }
    }

    private var seconds: Double {
        Double(total) / (Self.charsPerSecond * speed)
    }

    private func clock(_ value: Double) -> String {
        let whole = Int(value.rounded())
        return whole >= 3600
            ? String(format: "%d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60)
            : String(format: "%d:%02d", whole / 60, whole % 60)
    }

    private func seek(to value: Double) {
        let target = Int(value * Double(total))
        let paragraph = starts.lastIndex { $0 <= target } ?? 0
        onSeek(paragraph)
    }

    private var controls: some View {
        HStack(spacing: 18) {
            control("backward.end.fill", label: "Предыдущая глава") { onChapter(-1) }
                .disabled(chapterNumber <= 1)
            control("backward.fill", label: "Абзац назад") { speech.previousParagraph() }
            Button(action: onToggle) {
                ZStack {
                    Circle().fill(Color.brandTint)
                    if speech.isPreparing {
                        ProgressView().tint(.brandOnTint)
                    } else {
                        Image(systemName: speech.isPlaying ? "pause.fill" : "play.fill")
                            .scaledFont(size: 28)
                            .foregroundColor(.brandOnTint)
                    }
                }
                .frame(width: 68, height: 68)
            }
            .accessibilityLabel(speech.isPlaying ? "Пауза" : "Читать вслух")
            control("forward.fill", label: "Абзац вперёд") { speech.nextParagraph() }
            control("forward.end.fill", label: "Следующая глава") { onChapter(1) }
                .disabled(chapterNumber >= chapterCount)
        }
        .buttonStyle(.plain)
    }

    /// Голос готовит первую фразу (после установки или запуска приложения это может занять время) — видно, что не зависло.
    /// Место занято всегда: подпись не двигает кнопки
    private var preparingNote: some View {
        Text("Готовлю голос — в первый раз это дольше…")
            .scaledFont(size: 13)
            .foregroundColor(Color.brandMuted)
            .opacity(speech.isPreparing ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: speech.isPreparing)
            .padding(.top, -10)
            .accessibilityHidden(!speech.isPreparing)
    }

    private func control(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .scaledFont(size: 20)
                .foregroundColor(.brandDark)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - Таймер, скорость, текст

    private var tools: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Таймер сна", selection: Binding(get: { sleep }, set: { onSleep($0) })) {
                    ForEach(SleepTimer.options, id: \.self) { Text($0.title).tag($0) }
                }
            } label: {
                tool("moon.zzz", sleepTitle)
            }
            Menu {
                Picker("Скорость", selection: $speed) {
                    ForEach(ReaderSpeech.speeds, id: \.self) { value in
                        Text(speedTitle(value)).tag(value)
                    }
                }
            } label: {
                tool("speedometer", speedTitle(speed))
            }
            Button(action: onClose) {
                tool("text.book.closed", "Текст")
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
    }

    private func tool(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .scaledFont(size: 20)
            Text(title)
                .scaledFont(size: 13)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(.brandDark)
        .frame(maxWidth: .infinity)
    }

    private var sleepTitle: String {
        switch sleep {
        case .off: return "Таймер сна"
        case .chapterEnd: return "До конца главы"
        case .minutes: return sleepEndsAt.map { Self.remaining(until: $0) } ?? "Таймер сна"
        }
    }

    private static func remaining(until date: Date) -> String {
        "Ещё \(max(Int((date.timeIntervalSinceNow / 60).rounded(.up)), 1)) мин"
    }

    private func speedTitle(_ value: Double) -> String {
        value == 1 ? "1×" : "\(value.formatted(.number.locale(Locale(identifier: "ru_RU"))))×"
    }

    private var chaptersButton: some View {
        Button(action: onChapters) {
            VStack(spacing: 2) {
                Image(systemName: "chevron.up")
                Text("Главы")
                    .scaledFont(size: 13)
            }
            .foregroundColor(.brandDark)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Данные

    private func prepare() {
        var sum = 0
        starts = paragraphs.map { paragraph in
            defer { sum += paragraph.count }
            return sum
        }
        total = sum
    }
}
