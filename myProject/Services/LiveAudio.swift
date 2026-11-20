import Foundation
import Observation

/// Живая озвучка книги на устройстве: Application Support/LiveAudio/<книга>/book.json (запись LibriVox с главами) + sNNN.mp3.
/// Глава, которой ещё нет на устройстве, играет из интернета
nonisolated enum LiveAudioStore {
    private static var root: URL {
        URL.applicationSupportDirectory.appending(path: "LiveAudio", directoryHint: .isDirectory)
    }

    static func folder(_ book: UUID) -> URL {
        root.appending(path: book.uuidString, directoryHint: .isDirectory)
    }

    private static func manifestURL(_ book: UUID) -> URL {
        folder(book).appending(path: "book.json")
    }

    static func file(book: UUID, section: Int) -> URL {
        folder(book).appending(path: String(format: "s%04d.mp3", section))
    }

    static func audiobook(book: UUID) -> LibriVox.Audiobook? {
        guard let data = try? Data(contentsOf: manifestURL(book)) else { return nil }
        return try? JSONDecoder().decode(LibriVox.Audiobook.self, from: data)
    }

    static func save(_ audiobook: LibriVox.Audiobook, book: UUID) throws {
        let folder = folder(book)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Сотни мегабайт, которые можно скачать заново, — не в резервную копию iCloud
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var rootURL = root
        try? rootURL.setResourceValues(values)
        try JSONEncoder().encode(audiobook).write(to: manifestURL(book), options: .atomic)
    }

    static func isDownloaded(book: UUID, section: Int) -> Bool {
        FileManager.default.fileExists(atPath: file(book: book, section: section).path)
    }

    static func downloadedCount(book: UUID, audiobook: LibriVox.Audiobook) -> Int {
        audiobook.sections.filter { isDownloaded(book: book, section: $0.number) }.count
    }

    static func size(book: UUID) -> Int64 {
        guard let files = FileManager.default.enumerator(at: folder(book), includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    static func delete(book: UUID) {
        try? FileManager.default.removeItem(at: folder(book))
        UserDefaults.standard.removeObject(forKey: positionKey(book))
    }

    // MARK: - Где остановились

    private static func positionKey(_ book: UUID) -> String { "liveaudio_position_\(book.uuidString)" }

    /// Глава (номер LibriVox) и секунда в ней
    static func position(book: UUID) -> (section: Int, time: Double)? {
        guard let values = UserDefaults.standard.array(forKey: positionKey(book)) as? [Double], values.count == 2 else { return nil }
        return (Int(values[0]), values[1])
    }

    static func savePosition(book: UUID, section: Int, time: Double) {
        UserDefaults.standard.set([Double(section), time], forKey: positionKey(book))
    }
}

/// Скачивание глав по одной, пока приложение открыто. Одна книга за раз; уйти с экрана можно — загрузка продолжится
@MainActor @Observable
final class LiveAudioDownloader {
    static let shared = LiveAudioDownloader()

    struct Job: Equatable {
        let book: UUID
        var done: Int
        let total: Int
        var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    }

    private(set) var job: Job?
    /// Последняя ошибка: для какой книги и что сказать
    private(set) var failure: (book: UUID, text: String)?
    private var task: Task<Void, Never>?

    func isDownloading(_ book: UUID) -> Bool { job?.book == book }

    func start(book: UUID) {
        guard job == nil, let audiobook = LiveAudioStore.audiobook(book: book) else { return }
        failure = nil
        let missing = audiobook.sections.filter { !LiveAudioStore.isDownloaded(book: book, section: $0.number) }
        guard !missing.isEmpty else { return }
        job = Job(book: book, done: audiobook.sections.count - missing.count, total: audiobook.sections.count)
        task = Task {
            for section in missing {
                if Task.isCancelled { break }
                do {
                    try await Self.download(section, to: LiveAudioStore.file(book: book, section: section.number))
                    job?.done += 1
                } catch {
                    if !Task.isCancelled {
                        failure = (book, "Скачивание прервалось. Проверьте интернет и нажмите «Скачать» ещё раз — скачанное останется.")
                    }
                    break
                }
            }
            job = nil
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
    }

    private nonisolated static func download(_ section: LibriVox.Section, to destination: URL) async throws {
        var request = URLRequest(url: section.url, timeoutInterval: 120)
        request.setValue("LexiStream/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (temporary, response) = try await URLSession.shared.download(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}
