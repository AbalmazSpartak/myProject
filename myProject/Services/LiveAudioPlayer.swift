import AVFoundation
import MediaPlayer
import Observation
import UIKit

/// Плеер живой озвучки: главы LibriVox по порядку (скачанные — с устройства, остальные — из интернета),
/// скорость, перемотка, экран блокировки и наушники. Один на приложение: уйти с экрана — книга продолжает играть
@MainActor @Observable
final class LiveAudioPlayer {
    static let shared = LiveAudioPlayer()

    static let speeds: [Float] = [0.75, 1, 1.25, 1.5]

    private(set) var bookID: UUID?
    private(set) var bookTitle = ""
    private(set) var audiobook: LibriVox.Audiobook?
    /// Номер главы LibriVox, которая сейчас загружена в плеер
    private(set) var section: Int?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var time: Double = 0
    private(set) var duration: Double = 0
    var speed: Float = UserDefaults.standard.object(forKey: "liveaudio_speed") as? Float ?? 1 {
        didSet {
            UserDefaults.standard.set(speed, forKey: "liveaudio_speed")
            player.defaultRate = speed
            if isPlaying { player.rate = speed }
            updateNowPlaying()
        }
    }

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var artwork: MPMediaItemArtwork?
    private var lastSaved = Date.distantPast

    var currentSection: LibriVox.Section? {
        audiobook?.sections.first { $0.number == section }
    }

    func isCurrent(_ book: UUID) -> Bool { bookID == book }

    /// Открыть книгу: с места, где остановились. Уже играющую не трогаем
    func open(book: UUID, title: String, cover: Data?) {
        guard bookID != book else { return }
        guard let audiobook = LiveAudioStore.audiobook(book: book), let first = audiobook.sections.first else { return }
        stop()
        bookID = book
        bookTitle = title
        self.audiobook = audiobook
        artwork = cover.flatMap(UIImage.init(data:)).map(Self.artwork(image:))
        let saved = LiveAudioStore.position(book: book)
        let start = saved.flatMap { position in audiobook.sections.first { $0.number == position.section } } ?? first
        load(start, at: saved?.section == start.number ? saved?.time ?? 0 : 0, autoplay: false)
    }

    func play(section number: Int) {
        guard let target = audiobook?.sections.first(where: { $0.number == number }) else { return }
        load(target, at: 0, autoplay: true)
    }

    func togglePlay() { isPlaying ? pause() : resume() }

    func resume() {
        guard player.currentItem != nil else { return }
        setUpSession()
        setUpRemoteCommands()
        player.playImmediately(atRate: speed)
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
        savePosition()
        updateNowPlaying()
    }

    func skip(_ seconds: Double) {
        seek(to: min(max(time + seconds, 0), max(duration - 1, 0)))
    }

    func seek(to seconds: Double) {
        time = seconds
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        savePosition()
        updateNowPlaying()
    }

    func nextSection() {
        guard let sections = audiobook?.sections, let index = sections.firstIndex(where: { $0.number == section }),
              index + 1 < sections.count else { return }
        load(sections[index + 1], at: 0, autoplay: isPlaying)
    }

    /// В начале главы — к предыдущей, иначе — к началу этой
    func previousSection() {
        guard let sections = audiobook?.sections, let index = sections.firstIndex(where: { $0.number == section }) else { return }
        if time > 5 || index == 0 {
            seek(to: 0)
        } else {
            load(sections[index - 1], at: 0, autoplay: isPlaying)
        }
    }

    /// Книга удалена или закрыта: тишина, экран блокировки очищается
    func stop() {
        savePosition()
        player.pause()
        player.replaceCurrentItem(with: nil)
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObservation = nil
        for (command, target) in remoteTargets { command.removeTarget(target) }
        remoteTargets = []
        if bookID != nil { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil }
        isPlaying = false
        bookID = nil
        audiobook = nil
        section = nil
        time = 0
        duration = 0
    }

    // MARK: - Загрузка главы

    private func load(_ target: LibriVox.Section, at start: Double, autoplay: Bool) {
        guard let bookID else { return }
        savePosition()
        let local = LiveAudioStore.file(book: bookID, section: target.number)
        let url = FileManager.default.fileExists(atPath: local.path) ? local : target.url
        let asset = AVURLAsset(url: url, options: [AVURLAssetHTTPUserAgentKey: "LexiStream/1.0 (iOS)"])
        let item = AVPlayerItem(asset: asset)
        section = target.number
        time = start
        duration = Double(target.seconds)
        isLoading = true
        player.replaceCurrentItem(with: item)
        player.defaultRate = speed
        if start > 0 { player.seek(to: CMTime(seconds: start, preferredTimescale: 600)) }
        observe(item)
        if autoplay { resume() } else { updateNowPlaying() }
    }

    private func observe(_ item: AVPlayerItem) {
        if timeObserver == nil {
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] current in
                MainActor.assumeIsolated { self?.tick(current.seconds) }
            }
        }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finishedSection() }
        }
        statusObservation = item.observe(\.status) { [weak self] item, _ in
            let ready = item.status != .unknown
            let seconds = item.duration.seconds
            Task { @MainActor in
                guard let self, ready else { return }
                self.isLoading = false
                if seconds.isFinite, seconds > 0 { self.duration = seconds }
                self.updateNowPlaying()
            }
        }
    }

    private func tick(_ seconds: Double) {
        guard seconds.isFinite, !isLoading || isPlaying else { return }
        time = seconds
        if Date().timeIntervalSince(lastSaved) > 5 { savePosition() }
    }

    /// Глава доиграла — следующая; книга кончилась — стоп, в следующий раз с начала последней главы
    private func finishedSection() {
        guard let sections = audiobook?.sections, let index = sections.firstIndex(where: { $0.number == section }) else { return }
        if index + 1 < sections.count {
            load(sections[index + 1], at: 0, autoplay: true)
        } else {
            isPlaying = false
            time = 0
            savePosition()
            updateNowPlaying()
        }
    }

    private func savePosition() {
        guard let bookID, let section else { return }
        lastSaved = Date()
        LiveAudioStore.savePosition(book: bookID, section: section, time: time)
    }

    // MARK: - Система

    private func setUpSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func setUpRemoteCommands() {
        guard remoteTargets.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        func add(_ command: MPRemoteCommand, _ action: @escaping @MainActor (MPRemoteCommandEvent) -> Void) {
            let target = command.addTarget { event in
                MainActor.assumeIsolated { action(event) }
                return .success
            }
            remoteTargets.append((command, target))
        }
        add(center.playCommand) { [weak self] _ in self?.resume() }
        add(center.pauseCommand) { [weak self] _ in self?.pause() }
        add(center.togglePlayPauseCommand) { [weak self] _ in self?.togglePlay() }
        add(center.nextTrackCommand) { [weak self] _ in self?.nextSection() }
        add(center.previousTrackCommand) { [weak self] _ in self?.previousSection() }
        add(center.changePlaybackPositionCommand) { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent { self?.seek(to: event.positionTime) }
        }
    }

    private func updateNowPlaying() {
        guard bookID != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentSection?.title ?? bookTitle,
            MPMediaItemPropertyArtist: audiobook?.author ?? "",
            MPMediaItemPropertyAlbumTitle: bookTitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: time,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(speed) : 0.0,
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Картинку система просит из своего потока — замыкание не должно быть привязано к главному
    private nonisolated static func artwork(image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
