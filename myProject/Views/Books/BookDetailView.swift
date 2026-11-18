import SwiftUI

/// Страница книги: обложка, название, автор, сколько прочитано, «Читать» и «Слушать».
/// Открывается нажатием на книгу в библиотеке; читалка — следующим шагом
struct BookDetailView: View {
    @Bindable var book: Book
    /// Открыта кнопкой «Слушать» из раздела «Аудио»: сразу открыть читалку и включить озвучку
    var startsListening = false

    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @State private var details: Details?
    @State private var isReading = false
    @State private var listensOnOpen = false
    @State private var isShowingDictionary = false
    @State private var recorder = AudiobookRecorder.shared
    @State private var recordedChapters = 0
    @State private var recordedSet: Set<Int> = []
    @State private var listenChapter: Int?
    @State private var audioSize: Int64 = 0
    @State private var isConfirmingDelete = false
    @State private var isShowingChapters = false
    @State private var didAutoListen = false

    /// Что нужно разобрать из текста книги: делается один раз, в фоне
    private struct Details {
        let chapters: Int
        let words: Int
        let wordsRead: Int
        let language: String
        let titles: [String]
        /// Сколько глав на самом деле: без титула и содержания
        var realChapters: Int { ChapterNumbering(titles: titles).count }
    }

    /// Средняя скорость чтения про себя, слов в минуту
    private static let wordsPerMinute = 220.0

    private var coverWidth: CGFloat { PadLayout.isPad ? 200 : 150 }

    private var isStarted: Bool { book.position > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                top
                VStack(spacing: 20) {
                    titleBlock
                    chips
                    actions
                    aboutCard
                    audiobookCard
                    if mode == .learning { dictionaryButton }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: PadLayout.columnWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        // Читалка в дневной теме делает светлым весь стек; страница книги держит тему приложения сама
        .appThemedColorScheme()
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isReading) {
            BookReaderView(book: book, listensOnOpen: listensOnOpen, listenFromChapter: listenChapter)
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isShowingDictionary) {
            BookDictionaryView(book: book)
                .appThemedColorScheme()
        }
        .task {
            await loadDetails()
            // Один раз: после возврата из читалки страница не должна открыть её снова
            if startsListening, !didAutoListen {
                didAutoListen = true
                listensOnOpen = true
                listenChapter = nil
                isReading = true
            }
        }
    }

    // MARK: - Обложка

    /// Обложка по центру на размытом фоне из неё же; по бокам — главы и прочитанное
    private var backdropHeight: CGFloat { coverWidth * 1.5 * 0.62 + 40 }

    private var backdrop: some View {
        Group {
            if let data = book.coverData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 28)
                    .opacity(0.55)
            } else {
                Color.brown.opacity(0.35)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: backdropHeight, alignment: .center)
        .clipped()
    }

    private var top: some View {
        ZStack {
            backdrop
            .frame(maxHeight: .infinity, alignment: .top)
            .mask(
                LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .bottom, spacing: 0) {
                stat(title: "Глав", value: details.map { "\($0.realChapters)" } ?? "—")
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(width: coverWidth)
                    .overlay { BookCover(data: book.coverData, title: book.title) }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                stat(title: "Прочитано", value: "\(Int((book.progress * 100).rounded()))%")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        // Если потянуть страницу вниз, фон продолжается до самого верха: над ним зеркальные копии, шов не виден.
        // В background — на раскладку не влияет
        .background(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    backdrop.scaleEffect(x: 1, y: index % 2 == 0 ? -1 : 1)
                }
            }
            .offset(y: -backdropHeight * 3)
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .scaledFont(size: 12)
                .foregroundColor(.gray)
            Text(value)
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    // MARK: - Название и кнопки

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(book.title)
                .scaledFont(size: 24, weight: .bold, design: .serif)
                .foregroundColor(.brandDark)
                .multilineTextAlignment(.center)
            if !book.author.isEmpty {
                Text(book.author)
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundColor(.gray)
            }
            ProgressView(value: book.progress)
                .tint(.brown)
                .padding(.top, 8)
                .padding(.horizontal, 30)
        }
    }

    /// Язык и сколько читать осталось
    private var chips: some View {
        HStack(spacing: 10) {
            if let details {
                chip(Self.languageName(details.language))
                chip(remainingText(details))
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 14, weight: .medium)
            .foregroundColor(.brandDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.brandFill))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                listensOnOpen = false
                listenChapter = nil
                isReading = true
            } label: {
                Text(isStarted ? "Продолжить" : "Читать")
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandTint))
            }
            Button {
                listensOnOpen = true
                listenChapter = nil
                isReading = true
            } label: {
                Label("Слушать", systemImage: "headphones")
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandTint)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandTint, lineWidth: 1.5))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - О книге

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("О книге")
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            if let details {
                row("Язык", Self.languageName(details.language))
                row("Глав", "\(details.realChapters)")
                row("Всего читать", duration(minutes: Double(details.words) / Self.wordsPerMinute))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.brandDark)
        }
        .scaledFont(size: 15)
    }

    private var dictionaryButton: some View {
        Button { isShowingDictionary = true } label: {
            Label("Слова из книги", systemImage: "text.book.closed")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundColor(.brandTint)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.cardBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Озвучка

    /// Голос, которым сейчас читается книга; nil — нейросетевого нет, записать нечего
    private var audiobookVoice: NeuralVoice.BookVoice? {
        details.flatMap { NeuralVoice.shared.bookVoice(language: $0.language) }
    }

    private var audiobookKey: String? { audiobookVoice.map(AudiobookStore.voiceKey) }

    private var audiobookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Озвучка")
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            if let details {
                if recorder.isRecording(book.id), let job = recorder.job {
                    ProgressView(value: job.fraction)
                        .tint(.brandTint)
                    Text("Записываю: \(job.chapterText.lowercased()) · \(Int(job.fraction * 100))%" + (job.remainingText.map { " · осталось \($0)" } ?? "") + ". Не закрывайте приложение, экран не погаснет.")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                    audiobookButton("Остановить", systemImage: "stop.circle") { recorder.cancel() }
                    chaptersList(details)
                } else if audiobookVoice == nil {
                    Text("Нужен нейросетевой голос: Настройки → Озвучка → Нейросетевой голос. Записанная озвучка читается им же.")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                } else {
                    let complete = recordedChapters >= details.chapters && details.chapters > 0
                    Text(audiobookStatus(details, complete: complete))
                        .scaledFont(size: 14)
                        .foregroundColor(.brandDark)
                    if let failure = recorder.failure, failure.bookID == book.id {
                        Text(failure.text)
                            .scaledFont(size: 13)
                            .foregroundColor(.red)
                    }
                    if !complete {
                        audiobookButton(recordedChapters == 0 ? "Записать озвучку" : "Продолжить запись", systemImage: "arrow.down.circle") {
                            recorder.start(bookID: book.id, title: book.title, chaptersData: book.chaptersData, language: details.language)
                        }
                    }
                    if audioSize > 0 {
                        audiobookButton("Удалить озвучку", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                    }
                    chaptersList(details)
                    Text("Книга читается записью без ожидания, подсветка предложений и скорость работают как обычно. Если сменить голос в «Озвучке», запись нужно сделать заново.")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
        .confirmationDialog("Удалить озвучку этой книги?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                AudiobookStore.delete(book: book.id)
                refreshAudiobook()
            }
        }
        .onChange(of: recorder.job?.chapter) { _, _ in refreshAudiobook() }
        .onChange(of: recorder.job == nil) { _, _ in refreshAudiobook() }
        .onChange(of: details?.chapters) { _, _ in refreshAudiobook() }
    }

    /// Главы: у записанной справа ▶ (слушать с этой главы), у незаписанной — ⬇ (записать её)
    private func chaptersList(_ details: Details) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isShowingChapters.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text("Главы: записано \(recordedChapters) из \(details.chapters)")
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.brandDark)
                    Spacer()
                    // Та же колонка и ширина, что у значков ▶ и ⬇ в строках глав
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(.brandTint)
                        .rotationEffect(.degrees(isShowingChapters ? 90 : 0))
                        .frame(width: 32, height: 32)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Главы")
            .accessibilityValue(isShowingChapters ? "развёрнут" : "свёрнут")
            if isShowingChapters {
                Divider()
                // Номера считаются один раз на весь список, а не на каждую строку
                let numbering = ChapterNumbering(titles: details.titles)
                ForEach(Array(details.titles.enumerated()), id: \.offset) { index, title in
                    chapterRow(index, title: title, numbering: numbering, details: details)
                    if index < details.titles.count - 1 { Divider() }
                }
            }
        }
    }

    @ViewBuilder
    private func chapterRow(_ index: Int, title: String, numbering: ChapterNumbering, details: Details) -> some View {
        let isRecorded = recordedSet.contains(index)
        let isRecordingThis = recorder.isRecording(book.id) && recorder.job?.chapter == index
        let isBusy = recorder.job != nil
        Button {
            if isRecorded {
                listensOnOpen = true
                listenChapter = index
                isReading = true
            } else if !isBusy, audiobookVoice != nil {
                recorder.start(bookID: book.id, title: book.title, chaptersData: book.chaptersData,
                               language: details.language, only: [index])
            }
        } label: {
            HStack(spacing: 10) {
                Text(numbering.listTitle(for: index, title: title))
                    .lineLimit(1)
                    .foregroundColor(.brandDark)
                Spacer()
                // Одна ширина и один размер: значки ▶ и ⬇ стоят ровно друг под другом
                Group {
                    if isRecordingThis {
                        ProgressView()
                    } else {
                        Image(systemName: isRecorded ? "play.circle" : "arrow.down.circle")
                            .scaledFont(size: 22)
                            .foregroundColor(isRecorded || !isBusy ? .brandTint : .gray.opacity(0.5))
                    }
                }
                .frame(width: 32, height: 32)
            }
            .scaledFont(size: 15)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isRecorded && (isBusy || audiobookVoice == nil))
        .accessibilityLabel(isRecorded ? "Слушать с главы \(index + 1): \(title)" : "Записать главу \(index + 1): \(title)")
    }

    private func audiobookStatus(_ details: Details, complete: Bool) -> String {
        let megabytes = ByteCountFormatter.string(fromByteCount: audioSize, countStyle: .file)
        if complete { return "Записано: все \(details.chapters) глав · \(megabytes)" }
        if recordedChapters > 0 { return "Записано \(recordedChapters) из \(details.chapters) глав · \(megabytes)" }
        // ~150 слов в минуту речи
        let estimate = Double(details.words) / 150 * AudiobookStore.megabytesPerMinute
        return "Не записана. Размер около \(Int(estimate.rounded())) МБ, запись идёт, пока приложение открыто. Голос: \(NeuralVoice.shared.bookVoiceTitle(details.language))."
    }

    private func audiobookButton(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .scaledFont(size: 16, weight: .semibold)
                .foregroundColor(role == .destructive ? .red : .brandTint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandFill))
        }
        .buttonStyle(.plain)
    }

    private func refreshAudiobook() {
        guard let details, let key = audiobookKey else {
            recordedChapters = 0
            recordedSet = []
            audioSize = AudiobookStore.size(book: book.id)
            return
        }
        recordedSet = Set((0..<details.chapters).filter { AudiobookStore.hasChapter(book: book.id, key: key, index: $0) })
        recordedChapters = recordedSet.count
        audioSize = AudiobookStore.size(book: book.id)
    }

    // MARK: - Данные

    private func loadDetails() async {
        guard details == nil else { return }
        let data = book.chaptersData, position = book.position
        details = await Task.detached(priority: .userInitiated) {
            let chapters = (try? JSONDecoder().decode([BookChapter].self, from: data)) ?? []
            var words = 0, wordsRead = 0, index = 0
            for chapter in chapters {
                for paragraph in chapter.paragraphs {
                    let count = paragraph.split(whereSeparator: \.isWhitespace).count
                    words += count
                    if index < position { wordsRead += count }
                    index += 1
                }
            }
            let titles = chapters.enumerated().map { index, chapter -> String in
                let title = chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? "Глава \(index + 1)" : title
            }
            return Details(chapters: chapters.count, words: words, wordsRead: wordsRead, language: BookLanguage.detect(chapters), titles: titles)
        }.value
    }

    private func remainingText(_ details: Details) -> String {
        let left = Double(max(details.words - details.wordsRead, 0)) / Self.wordsPerMinute
        return left < 1 ? "Дочитана" : "Осталось ≈ \(duration(minutes: left))"
    }

    private func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let hours = total / 60, rest = total % 60
        if hours == 0 { return "\(max(rest, 1)) мин" }
        return rest == 0 ? "\(hours) ч" : "\(hours) ч \(rest) мин"
    }

    private static func languageName(_ code: String) -> String {
        Locale(identifier: "ru_RU").localizedString(forLanguageCode: code)?.capitalized ?? code
    }
}
