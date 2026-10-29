import SwiftUI

/// Прогресс загрузки или распаковки голоса с кнопкой «Отменить»
struct VoiceProgressRow: View {
    let title: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(fraction * 100))%")
                    .monospacedDigit()
                    .foregroundColor(.gray)
            }
            ProgressView(value: fraction)
            Button("Отменить", role: .cancel) { NeuralVoice.shared.cancelDownload() }
                .font(.footnote)
        }
    }
}

/// Нейросетевой голос → «Языки книг»: список языков с голосами Piper
struct BookLanguagesView: View {
    @State private var voice = NeuralVoice.shared

    var body: some View {
        List {
            Section {
                ForEach(NeuralVoice.PiperVoice.languages, id: \.code) { language in
                    NavigationLink {
                        BookLanguageVoiceView(code: language.code, title: language.title)
                    } label: {
                        LabeledContent(language.title, value: installedTitle(language.code))
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .textCase(nil)
        .navigationTitle("Языки книг")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Имя скачанного голоса языка — видно, где озвучка уже стоит
    private func installedTitle(_ code: String) -> String {
        voice.piperPhase(code) == .ready ? (NeuralVoice.installedPiper(language: code)?.title ?? "") : ""
    }
}

/// Голос Piper для книг на одном языке: выбор, скачать, прослушать, удалить;
/// у английских книг, когда скачаны оба, — кто их читает: Kokoro или Piper
struct BookLanguageVoiceView: View {
    let code: String
    let title: String

    @State private var voice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared
    @State private var choice: NeuralVoice.PiperVoice
    @State private var isConfirmingRemove = false
    @AppStorage(NeuralVoice.voiceKey) private var kokoroVoiceID = 1

    init(code: String, title: String) {
        self.code = code
        self.title = title
        _choice = State(initialValue: NeuralVoice.installedPiper(language: code) ?? NeuralVoice.PiperVoice.voices(for: code)[0])
    }

    var body: some View {
        List {
            Section {
                if hasBothEnglish {
                    Picker("Читает книги", selection: englishBooksVoice) {
                        Text("Piper").tag("piper")
                        Text("Kokoro").tag("kokoro")
                    }
                    .pickerStyle(.segmented)
                }
                if showsKokoro {
                    // Голос Kokoro выбирается на экране «Нейросетевой голос»; здесь — строка на том же месте, что у Piper, и «Прослушать»
                    LabeledContent("Голос", value: NeuralVoice.voices.first { $0.id == kokoroVoiceID }?.title ?? "")
                    if voice.phase == .ready {
                        Button {
                            TextToSpeechManager.shared.speak("Hello! This is how English books will sound.")
                        } label: {
                            Label("Прослушать Kokoro", systemImage: "speaker.wave.2.fill")
                        }
                    }
                } else {
                    Picker("Голос", selection: $choice) {
                        ForEach(NeuralVoice.PiperVoice.voices(for: code)) { Text($0.summary).tag($0) }
                    }
                    status
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .textCase(nil)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Удалить голос?", isPresented: $isConfirmingRemove) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { voice.removePiper(language: code) }
        } message: {
            Text("Эти книги снова будет читать системный голос. Скачать можно заново.")
        }
    }

    /// У английских скачан и Kokoro, и Piper — между ними переключатель
    private var hasBothEnglish: Bool {
        code == "en" && (voice.phase == .ready || kokoroML.isReady) && voice.piperPhase("en") == .ready
    }

    /// Выбран Kokoro — Piper-голос и его кнопки не нужны
    private var showsKokoro: Bool { hasBothEnglish && englishBooksVoice.wrappedValue == "kokoro" }

    @ViewBuilder
    private var status: some View {
        switch voice.piperPhase(code) {
        case .downloading(let fraction):
            VoiceProgressRow(title: "Загрузка…", fraction: fraction)
        case .unpacking(let fraction):
            VoiceProgressRow(title: "Распаковка…", fraction: fraction)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundColor(.red)
                Button("Попробовать ещё раз") { voice.downloadPiper(choice) }
            }
        case .ready where NeuralVoice.installedPiper(language: code) == choice:
            Button { voice.previewPiper(choice) } label: {
                HStack {
                    Label("Прослушать", systemImage: "speaker.wave.2.fill")
                    if voice.previewing == choice {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            Button("Удалить голос", role: .destructive) { isConfirmingRemove = true }
        default:
            Button {
                voice.downloadPiper(choice)
            } label: {
                Label("Скачать «\(choice.title)» (\(NeuralVoice.piperDownloadSizeShort))", systemImage: "arrow.down.circle.fill")
            }
            .disabled(voice.isDownloading)
        }
    }

    /// Кто читает английские книги; пока выбор не сделан — тот, кто сейчас читает на самом деле
    private var englishBooksVoice: Binding<String> {
        Binding(get: { voice.englishBooksVoice.isEmpty ? (voice.kokoroTooSlow ? "piper" : "kokoro") : voice.englishBooksVoice },
                set: { voice.setEnglishBooksVoice($0) })
    }
}
