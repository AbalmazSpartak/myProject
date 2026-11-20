import SwiftUI
import SwiftData

/// Страница книги: обложка, название, автор, сколько прочитано, «Читать» и «Слушать».
/// Открывается нажатием на книгу в библиотеке; читалка — следующим шагом
struct BookDetailView: View {
    @Bindable var book: Book
    /// Открыта кнопкой «Слушать» из раздела «Аудио»: сразу открыть читалку и включить озвучку
    var startsListening = false

    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @Query private var lists: [WordList]
    @State private var isReviewingBookWords = false
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

    private var coverWidth: CGFloat { PadLayout.isPad ? 200 : 168 }

    private var isStarted: Bool { book.position > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                cover
                VStack(spacing: 0) {
                    titleBlock
                    chips.padding(.top, 14)
                    actions.padding(.top, 18)
                    bookWordsCard.padding(.top, 14)
                    aboutRows.padding(.top, 14)
                    audiobookCard.padding(.top, 18)
                    if mode == .learning { dictionaryButton.padding(.top, 12) }
                }
                .padding(.horizontal, 24)
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
        .fullScreenCover(isPresented: $isReviewingBookWords) {
            if let bookList {
                FlashcardsView(filter: .list(bookList))
                    .appThemedColorScheme()
            }
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

    // MARK: - Обложка (по холсту «Страница книги»: по центру, без размытого фона)

    private var cover: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: coverWidth)
            .overlay { BookCover(data: book.coverData, title: book.title) }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
            .padding(.top, 8)
    }

    // MARK: - Название и кнопки

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(book.title)
                .scaledFont(size: 28, weight: .semibold, design: .serif)
                .foregroundStyle(Color.brandDark)
                .multilineTextAlignment(.center)
            if !book.author.isEmpty {
                Text(book.author)
                    .scaledFont(size: 14)
                    .foregroundStyle(Color.brandMuted)
            }
        }
    }

    /// Язык, сколько прочитано, сколько читать осталось
    private var chips: some View {
        FlowLayout(spacing: 8) {
            if let details {
                chip(Self.languageName(details.language), isSoft: true)
            }
            chip("Прочитано \(Int((book.progress * 100).rounded()))%", isSoft: false)
            if let details {
                chip(remainingText(details), isSoft: false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ text: String, isSoft: Bool) -> some View {
        Text(text)
            .scaledFont(size: 12, weight: isSoft ? .semibold : .regular)
            .foregroundStyle(isSoft ? Color.brandOnSoft : Color.brandMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(isSoft ? Color.brandAccent : Color.brandFill))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                listensOnOpen = false
                listenChapter = nil
                isReading = true
            } label: {
                Label(isStarted ? "Продолжить" : "Читать", systemImage: "book.closed")
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(Color.brandOnButton)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandButton))
            }
            Button {
                listensOnOpen = true
                listenChapter = nil
                isReading = true
            } label: {
                Label("Слушать", systemImage: "headphones")
                    .scaledFont(size: 16, weight: .semibold)
                    // Значок и слово — одним цветом вместе с рамкой кнопки
                    .foregroundStyle(Color.brandButton)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.brandButton, lineWidth: 1.5))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Слова из книги

    /// Словарь с названием книги: слова, которые взяли в словарь при чтении
    private var bookList: WordList? {
        let name = book.title.trimmingCharacters(in: .whitespaces)
        return lists.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Мягкий мост от чтения к учёбе: слова, взятые из этой книги, — повторить в любой момент, без счётчиков и сроков
    @ViewBuilder
    private var bookWordsCard: some View {
        if let bookList, !bookList.words.isEmpty, !AppMode.isReaderOnly {
            let now = Date()
            let words = bookList.words
            let due = words.filter { $0.state != .new && $0.dueDate <= now }.count
            let fresh = words.filter { $0.state == .new }.count
            VStack(alignment: .leading, spacing: 10) {
                LXSectionLabel(text: "Слова из этой книги")
                Text(DictionaryCounts.words(words.count))
                    .scaledFont(size: 22, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                Text(due > 0 ? "Пора повторить: \(due)" : (fresh > 0 ? "Новых, ещё не начатых: \(fresh)" : "Всё повторено, можно освежить"))
                    .scaledFont(size: 14)
                    .foregroundStyle(Color.brandMuted)
                LXButton(title: "Повторить слова книги", systemImage: "rectangle.stack", style: .soft) {
                    isReviewingBookWords = true
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        }
    }

    // MARK: - О книге

    /// Строки со справкой, как на холсте: слева название, справа значение, между ними тонкие линии
    private var aboutRows: some View {
        VStack(spacing: 0) {
            if let details {
                row("Язык", Self.languageName(details.language))
                LXDivider()
                row("Глав", "\(details.realChapters)")
                LXDivider()
                row("Слов в книге", details.words.formatted())
                LXDivider()
                row("Всего читать", duration(minutes: Double(details.words) / Self.wordsPerMinute))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.brandDark)
            Spacer()
            Text(value).foregroundStyle(Color.brandMuted)
        }
        .scaledFont(size: 14)
        .padding(.vertical, 13)
    }

    private var dictionaryButton: some View {
        LXButton(title: "Слова из книги", systemImage: "text.book.closed", style: .soft) { isShowingDictionary = true }
    }

    // MARK: - Озвучка

    /// Голос, которым сейчас читается книга; nil — нейросетевого нет, записать нечего
    private var audiobookVoice: NeuralVoice.BookVoice? {
        details.flatMap { NeuralVoice.shared.bookVoice(language: $0.language) }
    }

    private var audiobookKey: String? { audiobookVoice.map(AudiobookStore.voiceKey) }

    private var audiobookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LXSectionLabel(text: "Озвучка")
            if let details {
                if recorder.isRecording(book.id), let job = recorder.job {
                    ProgressView(value: job.fraction)
                        .tint(.brandTint)
                    Text("Записываю: \(job.chapterText.lowercased()) · \(Int(job.fraction * 100))%" + (job.remainingText.map { " · осталось \($0)" } ?? "") + ". Не закрывайте приложение, экран не погаснет.")
                        .scaledFont(size: 13)
                        .foregroundColor(Color.brandMuted)
                    audiobookButton("Остановить", systemImage: "stop.circle") { recorder.cancel() }
                    chaptersList(details)
                } else if audiobookVoice == nil {
                    Text("Нужен нейросетевой голос: Настройки → Озвучка → Нейросетевой голос. Записанная озвучка читается им же.")
                        .scaledFont(size: 13)
                        .foregroundColor(Color.brandMuted)
                } else {
                    let complete = recordedChapters >= details.chapters && details.chapters > 0
                    Text(audiobookStatus(details, complete: complete))
                        .scaledFont(size: 14)
                        .foregroundColor(.brandDark)
                    if let failure = recorder.failure, failure.bookID == book.id {
                        Text(failure.text)
                            .scaledFont(size: 13)
                            .foregroundStyle(Color.statusLearning)
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
                        .foregroundColor(Color.brandMuted)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
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
                            .foregroundColor(isRecorded || !isBusy ? .brandTint : Color.brandMuted.opacity(0.5))
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
                .foregroundColor(role == .destructive ? Color.statusLearning : .brandTint)
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
