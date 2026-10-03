import AVFoundation
import Observation

/// Запись голоса для блока «Аудио» в теме сообщества (AAC, m4a)
@MainActor
@Observable
final class AudioRecorder {
    static let maxDuration: TimeInterval = 10 * 60

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    /// Микрофон запрещён в настройках iPhone
    private(set) var isDenied = false

    private var recorder: AVAudioRecorder?
    private var ticker: Task<Void, Never>?
    private let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("topic-recording.m4a")

    func start() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            isDenied = true
            return
        }
        AudioClipPlayer.shared.stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            guard recorder.record(forDuration: Self.maxDuration) else {
                restoreSession()
                return
            }
            self.recorder = recorder
            isRecording = true
            elapsed = 0
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard let self, let recorder = self.recorder else { return }
                    if recorder.isRecording {
                        self.elapsed = recorder.currentTime
                    } else {
                        // Дошли до предела — запись остановилась сама
                        self.isRecording = false
                        return
                    }
                }
            }
        } catch {
            restoreSession()
        }
    }

    /// Останавливает запись и отдаёт её; nil — записать не получилось
    func stop() -> Data? {
        ticker?.cancel()
        ticker = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        restoreSession()
        return try? Data(contentsOf: fileURL)
    }

    /// Возвращаем сессию озвучки: только воспроизведение, музыка приглушается
    private func restoreSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
}
