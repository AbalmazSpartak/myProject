import SwiftUI

/// Настройки → «Озвучка» → «Нейросетевой голос»: скачать модель, включить, выбрать голос, послушать, удалить
struct NeuralVoiceSettingsView: View {
    @AppStorage(NeuralVoice.enabledKey) private var isEnabled = false
    @AppStorage(NeuralVoice.voiceKey) private var voiceID = 1
    @State private var voice = NeuralVoice.shared
    @State private var isConfirmingRemove = false

    private static let sample = "Hello! This is how English words will sound."

    var body: some View {
        List {
            Group {
                Section {
                    status
                } footer: {
                    Text("Голос Kokoro звучит живее системного и работает без интернета. Скачивается один раз (\(NeuralVoice.downloadSize)), в резервную копию iCloud не попадает. Пока голос не скачан или выключен — говорит системный.")
                }

                if voice.phase == .ready {
                    Section {
                        Toggle("Озвучивать нейросетевым голосом", isOn: $isEnabled)
                        Picker("Голос", selection: $voiceID) {
                            ForEach(NeuralVoice.voices) { item in
                                Text(item.title).tag(item.id)
                            }
                        }
                        Button {
                            isEnabled = true
                            TextToSpeechManager.shared.speak(Self.sample)
                        } label: {
                            HStack {
                                Label("Прослушать", systemImage: "speaker.wave.2.fill")
                                if voice.isPreparing {
                                    Spacer()
                                    ProgressView()
                                    Text("Готовлю голос…")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    } footer: {
                        Text("Фраза готовится от полусекунды до нескольких секунд — на новых iPhone быстрее; уже сказанные слова повторяются сразу. Книга вслух читается системным голосом — там нужна подсветка слов.")
                    }

                    Section {
                        Button("Удалить голос", role: .destructive) { isConfirmingRemove = true }
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Нейросетевой голос")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { voice.warmUp() }
        .onChange(of: isEnabled) { _, enabled in if enabled { voice.warmUp() } }
        .alert("Удалить нейросетевой голос?", isPresented: $isConfirmingRemove) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { voice.remove() }
        } message: {
            Text("Освободится \(NeuralVoice.downloadSize). Озвучка станет системной, голос можно скачать снова.")
        }
    }

    @ViewBuilder
    private var status: some View {
        switch voice.phase {
        case .notDownloaded:
            Button {
                voice.download()
            } label: {
                Label("Скачать голос (\(NeuralVoice.downloadSize))", systemImage: "arrow.down.circle.fill")
            }
        case .downloading(let fraction):
            progressRow("Загрузка…", fraction)
        case .unpacking(let fraction):
            progressRow("Распаковка…", fraction)
        case .ready:
            Label("Голос скачан", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundColor(.red)
                Button("Попробовать ещё раз") { voice.download() }
            }
        }
    }

    private func progressRow(_ title: String, _ fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .monospacedDigit()
                    .foregroundColor(.gray)
            }
            ProgressView(value: fraction)
            Button("Отменить", role: .cancel) { voice.cancelDownload() }
                .font(.footnote)
        }
    }
}
