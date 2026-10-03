import AVFoundation
import Observation

/// Проигрывает записи и файлы из тем сообщества. Одновременно звучит один клип;
/// музыку пользователя, как и озвучка слов, приглушает, а не останавливает
@MainActor
@Observable
final class AudioClipPlayer: NSObject {
    static let shared = AudioClipPlayer()

    /// Какой клип сейчас звучит — у его кнопки «стоп» вместо «играть»
    private(set) var playingID: UUID?
    private var player: AVAudioPlayer?

    func toggle(_ data: Data, id: UUID, fileExtension: String) {
        if playingID == id {
            stop()
        } else {
            play(data, id: id, fileExtension: fileExtension)
        }
    }

    func play(_ data: Data, id: UUID, fileExtension: String) {
        stop()
        guard let player = try? AVAudioPlayer(data: data, fileTypeHint: Self.typeHint(for: fileExtension)) else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.delegate = self
        player.play()
        self.player = player
        playingID = id
    }

    func stop() {
        player?.stop()
        player = nil
        guard playingID != nil else { return }
        playingID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Длительность в секундах — показать рядом с кнопкой
    static func duration(of data: Data) -> TimeInterval? {
        (try? AVAudioPlayer(data: data))?.duration
    }

    private static func typeHint(for fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "mp3": return AVFileType.mp3.rawValue
        case "m4a": return AVFileType.m4a.rawValue
        case "wav": return AVFileType.wav.rawValue
        case "aiff", "aif": return AVFileType.aiff.rawValue
        default: return nil
        }
    }
}

extension AudioClipPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
