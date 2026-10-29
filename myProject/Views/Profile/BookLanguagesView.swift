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

/// Голос Piper для книг на одном языке: выбор, скачать, прослушать, удалить, назначить читать книги
struct BookLanguageVoiceView: View {
    let code: String
    let title: String

    @State private var voice = NeuralVoice.shared
    @State private var choice: NeuralVoice.PiperVoice
    @State private var isConfirmingRemove = false

    init(code: String, title: String) {
        self.code = code
        self.title = title
        _choice = State(initialValue: NeuralVoice.installedPiper(language: code) ?? NeuralVoice.PiperVoice.voices(for: code)[0])
    }

    var body: some View {
        List {
            Section {
                Picker("Голос", selection: $choice) {
                    ForEach(NeuralVoice.PiperVoice.voices(for: code)) { Text($0.summary).tag($0) }
                }
                status
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
            Text("Книги на этом языке снова будет читать системный голос. Скачать можно заново.")
        }
    }

    private var choiceKey: String { "piper:\(choice.rawValue)" }

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
            if voice.bookChoice(code) == choiceKey {
                Label("Читает книги", systemImage: "checkmark")
                    .foregroundColor(.gray)
            } else {
                Button("Читать книги этим голосом") { voice.setBookChoice(code, choiceKey) }
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
}

/// Озвучка → «Книги» → «Голос»: чем читать книги на языке — системным голосом, скачанным Piper или Kokoro (английский)
struct BookVoicePickerView: View {
    let code: String
    let title: String

    @State private var voice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared

    private var hasKokoro: Bool { voice.phase == .ready || kokoroML.isReady }

    var body: some View {
        List {
            Section {
                row("Системный голос iPhone", choice: "system")
            } footer: {
                Text(code == "en" ? "Голос и акцент — из блока «Слова»." : "Лучший скачанный в iPhone голос этого языка.")
                    .textSelection(.enabled)
            }
            .listRowBackground(Color.cardBackground)

            if let piper = NeuralVoice.installedPiper(language: code), voice.piperPhase(code) == .ready {
                Section("Piper") {
                    row(piper.summary, choice: "piper:\(piper.rawValue)")
                }
                .listRowBackground(Color.cardBackground)
            }

            if code == "en", hasKokoro {
                Section("Kokoro") {
                    ForEach(NeuralVoice.voices) { item in
                        row(item.title, choice: "kokoro:\(item.id)")
                    }
                }
                .listRowBackground(Color.cardBackground)
            }

            Section {
                NavigationLink("Скачать голоса Piper") {
                    BookLanguageVoiceView(code: code, title: title)
                }
                if code == "en" && !hasKokoro {
                    NavigationLink("Скачать Kokoro") { NeuralVoiceSettingsView() }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .textCase(nil)
        .navigationTitle("Голос · \(title)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ name: String, choice: String) -> some View {
        Button {
            voice.setBookChoice(code, choice)
        } label: {
            HStack {
                Text(name)
                    .foregroundColor(.primary)
                Spacer()
                if voice.bookChoice(code) == choice {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}
