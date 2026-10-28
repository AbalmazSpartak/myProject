import SwiftUI
import AVFoundation
import FluidAudio
import os

/// Раздел разработчика → проба Kokoro на нейроядре (FluidAudio, Core ML): скачать модель, трижды озвучить
/// один отрывок и замерить, успевает ли он на этом устройстве (на процессоре через sherpa-onnx iPhone 12 не успевал)
struct KokoroCoreMLTestView: View {
    @State private var log: [String] = []
    @State private var isRunning = false
    @State private var player: AVAudioPlayer?

    private static let sample = "“Curiouser and curiouser!” cried Alice (she was so much surprised, that for the moment she quite forgot how to speak good English); “now I’m opening out like the largest telescope that ever was! Good-bye, feet!” For when she looked down at her feet, they seemed to be almost out of sight, they were getting so far off."

    var body: some View {
        List {
            Section {
                Button(isRunning ? "Идёт проверка…" : "Скачать модель и проверить") {
                    Task { await run() }
                }
                .disabled(isRunning)
                if let player {
                    Button(player.isPlaying ? "Остановить" : "Прослушать ещё раз") {
                        if player.isPlaying { player.stop() } else { player.currentTime = 0; player.play() }
                    }
                }
            } footer: {
                Text("Первый раз скачивается модель — нужен интернет. Потом один отрывок «Алисы» озвучивается три раза: сколько готовился и сколько звучит. Меньше 1 — успевает, пауз при чтении не будет.")
            }
            Section("Журнал") {
                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.footnote.monospaced())
                }
            }
        }
        .navigationTitle("Kokoro на нейроядре")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player?.stop() }
    }

    private func add(_ line: String) {
        log.append(line)
        print("[KokoroML] " + line)
        fflush(stdout)
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        // Прежний Kokoro (на процессоре) — из памяти: в прошлый раз iOS закрыла приложение на третьей попытке
        await NeuralVoice.shared.unloadEngine()
        add("Старт, \(memory())")
        let manager = KokoroAneManager(version: .v3)
        do {
            var began = Date()
            add("Загрузка модели…")
            try await manager.initialize()
            add(String(format: "Модель готова за %.1f с, ", Date().timeIntervalSince(began)) + memory())
            for attempt in 1...3 {
                began = Date()
                let result = try await manager.synthesizeDetailed(text: Self.sample)
                let made = Date().timeIntervalSince(began)
                let length = Double(result.samples.count) / Double(result.sampleRate)
                add(String(format: "Попытка %d: %.2f с готовил → %.2f с речи (×%.2f), ", attempt, made, length, made / max(length, 0.01))
                    + memory())
                // Звук — сразу после первой: качество слышно, даже если дальше что-то пойдёт не так
                if attempt == 1 { play(result) }
            }
        } catch {
            add("Ошибка: \(error)")
        }
    }

    /// Сколько памяти ещё можно занять, пока iOS не закроет приложение
    private func memory() -> String {
        String(format: "до лимита памяти %.0f МБ", Double(os_proc_available_memory()) / 1_048_576)
    }

    /// Звук — WAV в памяти (16 бит, моно) и в плеер
    private func play(_ result: KokoroAneSynthesisResult) {
        var data = Data()
        func append<T>(_ value: T) { withUnsafeBytes(of: value) { data.append(contentsOf: $0) } }
        let pcm = result.samples.map { Int16(max(-1, min(1, $0)) * Float(Int16.max)) }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + pcm.count * 2).littleEndian)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16).littleEndian)
        append(UInt16(1).littleEndian)
        append(UInt16(1).littleEndian)
        append(UInt32(result.sampleRate).littleEndian)
        append(UInt32(result.sampleRate * 2).littleEndian)
        append(UInt16(2).littleEndian)
        append(UInt16(16).littleEndian)
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(pcm.count * 2).littleEndian)
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(data: data)
        player?.play()
    }
}
