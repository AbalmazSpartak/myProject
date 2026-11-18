import AVFoundation
import SwiftUI

/// Записанная озвучка главы: звук предложений подряд (AAC) и где какое предложение, чтобы читалка подсвечивала его при воспроизведении
nonisolated struct AudiobookChapter: Codable, Sendable {
    struct Word: Codable, Sendable {
        let time: Double
        let location: Int
        let length: Int
    }

    /// Одно предложение: куда оно попадает в абзаце, где его звук в файле и какие паузы вокруг (в файл они не пишутся)
    struct Segment: Codable, Sendable {
        let paragraph: Int
        let location: Int
        let length: Int
        /// Номер первого кадра звука в файле
        let start: Int
        let frames: Int
        let before: Double
        let after: Double
        let words: [Word]
    }

    let rate: Double
    /// Сколько было абзацев в главе при записи: изменился текст — запись не подходит
    let paragraphCount: Int
    let segments: [Segment]
}

/// Файлы озвучки на устройстве: Application Support/Audiobooks/<книга>/<голос>/chNNNN.m4a + .json.
/// Запись главы считается готовой, когда рядом лежит .json — он пишется последним
nonisolated enum AudiobookStore {
    /// Битрейт AAC: мономорная речь, ~21 МБ на час звука
    static let bitRate = 48_000
    /// ~МБ на минуту записи — для оценки размера до записи
    static let megabytesPerMinute = Double(bitRate) / 8 * 60 / 1_000_000

    static func voiceKey(_ voice: NeuralVoice.BookVoice) -> String {
        switch voice.engine {
        case .kokoroML(let name): "kokoro-ml-\(name)"
        case .sherpa(.kokoro): "kokoro-\(voice.speaker)"
        case .sherpa(.piper(_, let file)): "piper-\(file)"
        }
    }

    private static var root: URL {
        URL.applicationSupportDirectory.appending(path: "Audiobooks", directoryHint: .isDirectory)
    }

    static func bookFolder(_ book: UUID) -> URL {
        root.appending(path: book.uuidString, directoryHint: .isDirectory)
    }

    static func folder(book: UUID, key: String) -> URL {
        bookFolder(book).appending(path: key, directoryHint: .isDirectory)
    }

    static func audioURL(book: UUID, key: String, chapter: Int, temporary: Bool = false) -> URL {
        folder(book: book, key: key).appending(path: String(format: temporary ? "ch%04d.tmp.m4a" : "ch%04d.m4a", chapter))
    }

    private static func metaURL(book: UUID, key: String, chapter: Int) -> URL {
        folder(book: book, key: key).appending(path: String(format: "ch%04d.json", chapter))
    }

    /// Готовая запись главы этим голосом; nil — записи нет или она не подходит к тексту
    static func chapter(book: UUID, key: String, index: Int, paragraphCount: Int) -> (chapter: AudiobookChapter, url: URL)? {
        let url = audioURL(book: book, key: key, chapter: index)
        guard let data = try? Data(contentsOf: metaURL(book: book, key: key, chapter: index)),
              let chapter = try? JSONDecoder().decode(AudiobookChapter.self, from: data),
              chapter.paragraphCount == paragraphCount, !chapter.segments.isEmpty,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return (chapter, url)
    }

    static func hasChapter(book: UUID, key: String, index: Int) -> Bool {
        FileManager.default.fileExists(atPath: metaURL(book: book, key: key, chapter: index).path)
    }

    static func recordedCount(book: UUID, key: String, chapters: Int) -> Int {
        (0..<chapters).filter { hasChapter(book: book, key: key, index: $0) }.count
    }

    static func save(_ chapter: AudiobookChapter, book: UUID, key: String, index: Int) throws {
        try JSONEncoder().encode(chapter).write(to: metaURL(book: book, key: key, chapter: index), options: .atomic)
    }

    /// Папка голоса — готова к записи; в копию устройства (iCloud) файлы не попадают
    static func prepareFolder(book: UUID, key: String) throws {
        var folder = Self.folder(book: book, key: key)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var root = Self.root
        try? root.setResourceValues(values)
        try? folder.setResourceValues(values)
    }

    /// Сколько глав записано (самым полным из голосов) и сколько места занимает озвучка; nil — озвучки нет
    static func summary(book: UUID) -> (chapters: Int, bytes: Int64)? {
        let manager = FileManager.default
        guard let voices = try? manager.contentsOfDirectory(at: bookFolder(book), includingPropertiesForKeys: nil) else { return nil }
        var most = 0
        for voice in voices {
            let files = (try? manager.contentsOfDirectory(atPath: voice.path)) ?? []
            most = max(most, files.filter { $0.hasPrefix("ch") && $0.hasSuffix(".json") }.count)
        }
        return most > 0 ? (most, size(book: book)) : nil
    }

    /// Сколько байт занимает озвучка книги (всеми голосами)
    static func size(book: UUID) -> Int64 {
        let folder = bookFolder(book)
        guard let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    static func delete(book: UUID) {
        try? FileManager.default.removeItem(at: bookFolder(book))
    }

    /// Звук с кадра start — count кадров, по порядку, как в файле
    static func samples(from file: AVAudioFile, start: Int, frames: Int) -> [Float]? {
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        file.framePosition = AVAudioFramePosition(start)
        do { try file.read(into: buffer, frameCount: AVAudioFrameCount(frames)) } catch { return nil }
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}

/// Запись озвучки книги на устройстве: глава за главой тем же голосом, что читает книгу вслух.
/// Идёт, пока приложение открыто (экран не гаснет): нейросети в фоне iOS не даёт ядра. Готовые главы остаются при отмене и сбое
@MainActor
@Observable
final class AudiobookRecorder {
    static let shared = AudiobookRecorder()

    struct Job {
        let bookID: UUID
        let title: String
        let voiceKey: String
        /// 0…1 по абзацам всей книги
        var fraction: Double
        var chapter: Int
        let total: Int
        /// Записывают только эти главы (номера с нуля); nil — вся книга
        let only: Set<Int>?
        let startedAt = Date()
        /// С какой доли начали (часть глав уже была записана) — по ней считается, сколько ещё ждать
        var startFraction: Double?

        /// «Глава 3 из 13» при записи всей книги, «Глава 3» — одной главы
        var chapterText: String { only == nil ? "Глава \(chapter + 1) из \(total)" : "Глава \(chapter + 1)" }

        /// Сколько ещё идёт запись, секунды; nil — пока мало данных для оценки
        var remaining: TimeInterval? {
            guard let startFraction, fraction - startFraction > 0.01 else { return nil }
            let elapsed = Date().timeIntervalSince(startedAt)
            return elapsed * (1 - fraction) / (fraction - startFraction)
        }
    }

    private(set) var job: Job?
    /// Чем кончилась прошлая запись этой книги: nil — ничего или всё хорошо
    private(set) var failure: (bookID: UUID, text: String)?
    @ObservationIgnored private var task: Task<Void, Never>?

    private init() {}

    func isRecording(_ book: UUID) -> Bool { job?.bookID == book }

    func start(bookID: UUID, title: String, chaptersData: Data, language: String, only: Set<Int>? = nil) {
        guard job == nil, let voice = NeuralVoice.shared.bookVoice(language: language) else { return }
        failure = nil
        let key = AudiobookStore.voiceKey(voice)
        let isKokoroML = if case .kokoroML = voice.engine { true } else { false }
        let speed = Float(SpeechSettings.bookNeuralSpeedFactor)
        job = Job(bookID: bookID, title: title, voiceKey: key, fraction: 0, chapter: 0, total: 0, only: only)
        UIApplication.shared.isIdleTimerDisabled = true
        task = Task {
            defer {
                job = nil
                task = nil
                UIApplication.shared.isIdleTimerDisabled = false
            }
            let chapters = await Task.detached(priority: .utility) {
                (try? JSONDecoder().decode([BookChapter].self, from: chaptersData)) ?? []
            }.value
            guard !chapters.isEmpty else { return }
            let totalParagraphs = max(chapters.enumerated().reduce(0) { only?.contains($1.offset) == false ? $0 : $0 + $1.element.paragraphs.count }, 1)
            job = Job(bookID: bookID, title: title, voiceKey: key, fraction: 0, chapter: 0, total: chapters.count, only: only)
            do { try AudiobookStore.prepareFolder(book: bookID, key: key) } catch {
                failure = (bookID, "Не удалось создать папку для озвучки.")
                return
            }
            var done = 0
            for (index, chapter) in chapters.enumerated() {
                if Task.isCancelled { return }
                if let only, !only.contains(index) { continue }
                job?.chapter = index
                if AudiobookStore.hasChapter(book: bookID, key: key, index: index) || chapter.paragraphs.isEmpty {
                    done += chapter.paragraphs.count
                    job?.fraction = Double(done) / Double(totalParagraphs)
                    continue
                }
                if job?.startFraction == nil { job?.startFraction = Double(done) / Double(totalParagraphs) }
                do {
                    try await record(chapter, index: index, bookID: bookID, key: key, voice: voice, isKokoroML: isKokoroML,
                                     language: language, speed: speed) { paragraph in
                        self.job?.fraction = Double(done + paragraph) / Double(totalParagraphs)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    failure = (bookID, "Запись остановилась на главе \(index + 1). Откройте приложение и продолжите — готовые главы сохранены.")
                    return
                }
                done += chapter.paragraphs.count
            }
            job?.fraction = 1
        }
    }

    func cancel() {
        task?.cancel()
    }

    private func record(_ chapter: BookChapter, index: Int, bookID: UUID, key: String, voice: NeuralVoice.BookVoice,
                        isKokoroML: Bool, language: String, speed: Float, progress: (Int) -> Void) async throws {
        let temporary = AudiobookStore.audioURL(book: bookID, key: key, chapter: index, temporary: true)
        try? FileManager.default.removeItem(at: temporary)
        var file: AVAudioFile?
        var rate = 0.0
        var frames = 0
        var segments: [AudiobookChapter.Segment] = []
        do {
            for (paragraphIndex, text) in chapter.paragraphs.enumerated() {
                progress(paragraphIndex)
                let sentences = SpokenText.pieces(of: text, from: 0, language: language)
                let pieces = isKokoroML ? sentences.flatMap { ReaderSpeech.limited($0) } : sentences
                for (number, piece) in pieces.enumerated() {
                    try Task.checkCancellation()
                    let generated = try await NeuralVoice.shared.bookAudio(piece.text, voice: voice, speed: speed)
                    try Task.checkCancellation()
                    let samples = ReaderSpeech.leveled(generated.audio.samples)
                    let sampleRate = Double(generated.audio.sampleRate)
                    if file == nil {
                        rate = sampleRate
                        file = try AVAudioFile(forWriting: temporary, settings: [
                            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sampleRate,
                            AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: AudiobookStore.bitRate])
                    }
                    guard let file, sampleRate == rate, !samples.isEmpty,
                          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(samples.count)),
                          let channel = buffer.floatChannelData?[0] else { continue }
                    samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
                    buffer.frameLength = AVAudioFrameCount(samples.count)
                    try file.write(from: buffer)
                    // Время слов: у Kokoro на нейроядре от модели, у остальных — оценка (как при чтении вслух)
                    let starts = generated.words ?? (isKokoroML || !NeuralVoice.estimatesWordTimes
                                                     ? nil
                                                     : ReaderSpeech.estimatedStarts(piece: piece, samples: samples, rate: sampleRate))
                    let before = number == 0 && SpokenText.isDialogue(text) ? 0.15 : 0
                    let after = number == pieces.count - 1 ? ReaderSpeech.paragraphPause : ReaderSpeech.sentencePause
                    let range = ReaderSpeech.range(of: piece)
                    segments.append(.init(
                        paragraph: paragraphIndex, location: range.location, length: range.length, start: frames, frames: samples.count,
                        before: before, after: after,
                        words: ReaderSpeech.wordMarks(starts, piece: piece).map { .init(time: $0.time, location: $0.range.location, length: $0.range.length) }))
                    frames += samples.count
                }
            }
        } catch {
            file = nil
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
        // Файл закрывается, когда его отпускают; в главе без слов (одни «* * *») записывать нечего
        file = nil
        guard !segments.isEmpty else {
            try? FileManager.default.removeItem(at: temporary)
            try AudiobookStore.save(AudiobookChapter(rate: 0, paragraphCount: chapter.paragraphs.count, segments: []),
                                    book: bookID, key: key, index: index)
            return
        }
        let final = AudiobookStore.audioURL(book: bookID, key: key, chapter: index)
        try? FileManager.default.removeItem(at: final)
        try FileManager.default.moveItem(at: temporary, to: final)
        try AudiobookStore.save(AudiobookChapter(rate: rate, paragraphCount: chapter.paragraphs.count, segments: segments),
                                book: bookID, key: key, index: index)
    }
}

extension AudiobookRecorder.Job {
    /// «≈ 40 мин», «≈ 2 ч 5 мин»
    var remainingText: String? {
        guard let remaining else { return nil }
        let minutes = Int((remaining / 60).rounded(.up))
        return minutes >= 60 ? "≈ \(minutes / 60) ч \(minutes % 60) мин" : "≈ \(max(minutes, 1)) мин"
    }
}

/// Полоса прогресса записи озвучки: видна в библиотеке, пока идёт запись, — не нужно держать страницу книги открытой
struct AudiobookRecordingBar: View {
    @State private var recorder = AudiobookRecorder.shared

    var body: some View {
        if let job = recorder.job {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "waveform")
                    Text("Записываю озвучку: \(job.title)")
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(job.fraction * 100))%")
                        .monospacedDigit()
                }
                .scaledFont(size: 14, weight: .semibold)
                .foregroundColor(.brandDark)
                ProgressView(value: job.fraction)
                    .tint(.brandTint)
                HStack {
                    Text(job.chapterText + (job.remainingText.map { " · осталось \($0)" } ?? ""))
                    Spacer()
                    Button("Остановить") { recorder.cancel() }
                        .foregroundColor(.brandTint)
                }
                .scaledFont(size: 13)
                .foregroundColor(.gray)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cardBackground))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
