import SwiftUI

/// Настройки → «Озвучка» → «Нейросетевой голос»: скачать модель, выбрать голос, послушать, удалить;
/// лёгкие голоса Piper для английских и русских книг; переключатель «Читать книги этим голосом» — в Настройках
struct NeuralVoiceSettingsView: View {
    @AppStorage(NeuralVoice.voiceKey) private var voiceID = 1
    @State private var voice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared
    @AppStorage(KokoroML.preloadKey) private var preloadKokoro = true
    @State private var isConfirmingRemove = false
    @State private var isConfirmingMLRemove = false
    /// Язык, голос Piper которого удаляем («en», «ru»)
    @State private var piperToRemove: String?
    @State private var englishChoice = NeuralVoice.installedPiper(language: "en") ?? .kristin
    @State private var russianChoice = NeuralVoice.installedPiper(language: "ru") ?? .dmitri

    private static let sample = "Hello! This is how English words will sound."

    var body: some View {
        List {
            Group {
                piperSection(language: "en", choice: $englishChoice, header: "Английские книги",
                             footer: "Лёгкая озвучка Kokoro и Piper")

                piperSection(language: "ru", choice: $russianChoice, header: "Русские книги",
                             footer: "Лёгкий голос Piper")

                // Один раздел: выбор голоса, прослушать, удалить — или «Скачать голос», пока не скачан
                Section {
                    if voice.phase == .ready {
                        Picker("Голос", selection: $voiceID) {
                            ForEach(NeuralVoice.voices) { item in
                                Text(item.title).tag(item.id)
                            }
                        }
                        Button {
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
                        if voice.kokoroTooSlow {
                            Button("Проверить скорость снова") { voice.resetKokoroCheck() }
                        }
                    }
                    status
                    if voice.phase == .ready {
                        Button("Удалить голос", role: .destructive) { isConfirmingRemove = true }
                    }
                } header: {
                    Text("Голос Kokoro")
                } footer: {
                    Text("Звучит живее системного")
                }

                if KokoroML.isSupported {
                    Section {
                        kokoroMLStatus
                    } header: {
                        Text("Нейроядро Kokoro — для озвучки книг")
                    } footer: {
                        Text("Английские книги без пауз, подсвечивается каждое слово. Скачивается отдельно (\(KokoroML.downloadSize)).")
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        // Заголовки разделов — как написаны, а не ПРОПИСНЫМИ
        .textCase(nil)
        .navigationTitle("Нейросетевой голос")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HelpButton(topic: .neuralVoice)
            }
        }
        .onAppear { voice.warmUp() }
        .alert("Удалить голос?", isPresented: Binding(get: { piperToRemove != nil }, set: { if !$0 { piperToRemove = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let piperToRemove { voice.removePiper(language: piperToRemove) }
            }
        } message: {
            Text("Эти книги снова будет читать системный голос. Скачать можно заново.")
        }
        .alert("Удалить Kokoro на нейроядре?", isPresented: $isConfirmingMLRemove) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) { kokoroML.remove() }
        } message: {
            Text("Освободится \(KokoroML.downloadSize). Английские книги будет читать Piper или системный голос.")
        }
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
            // Идёт загрузка голоса Piper — по одной за раз
            .disabled(voice.isDownloading)
        case .downloading(let fraction):
            progressRow("Загрузка…", fraction)
        case .unpacking(let fraction):
            progressRow("Распаковка…", fraction)
        case .ready:
            // Скачан — видно по «Прослушать» и «Удалить голос», отдельной плашки не нужно
            EmptyView()
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundColor(.red)
                Button("Попробовать ещё раз") { voice.download() }
            }
        }
    }

    @ViewBuilder
    private var kokoroMLStatus: some View {
        switch kokoroML.phase {
        case .notDownloaded:
            Button {
                kokoroML.download()
            } label: {
                Label("Скачать (\(KokoroML.downloadSize))", systemImage: "arrow.down.circle.fill")
            }
        case .downloading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Скачиваю и готовлю голос — несколько минут…")
                    .foregroundColor(.gray)
            }
        case .ready:
            Toggle("Загружать при запуске", isOn: $preloadKokoro)
                .onChange(of: preloadKokoro) { _, isOn in if isOn { kokoroML.preloadIfReading() } }
            Button("Удалить", role: .destructive) { isConfirmingMLRemove = true }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundColor(.red)
                Button("Попробовать ещё раз") { kokoroML.download() }
            }
        }
    }

    /// Голос Piper для книг на одном языке: выбор, скачать, прослушать, удалить;
    /// у английских книг, когда скачаны оба, — кто их читает: Kokoro или Piper
    private func piperSection(language: String, choice: Binding<NeuralVoice.PiperVoice>, header: String, footer: String) -> some View {
        Section {
            if language == "en", voice.phase == .ready || kokoroML.isReady, voice.piperPhase("en") == .ready {
                Picker("Читает книги", selection: englishBooksVoice) {
                    Text("Kokoro").tag("kokoro")
                    Text("Piper").tag("piper")
                }
                .pickerStyle(.segmented)
            }
            Picker("Голос", selection: choice) {
                ForEach(NeuralVoice.PiperVoice.voices(for: language)) { Text($0.summary).tag($0) }
            }
            piperStatus(language: language, choice: choice.wrappedValue)
        } header: {
            Text(header)
        } footer: {
            Text(footer)
        }
    }

    @ViewBuilder
    private func piperStatus(language: String, choice: NeuralVoice.PiperVoice) -> some View {
        switch voice.piperPhase(language) {
        case .downloading(let fraction):
            progressRow("Загрузка…", fraction)
        case .unpacking(let fraction):
            progressRow("Распаковка…", fraction)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundColor(.red)
                Button("Попробовать ещё раз") { voice.downloadPiper(choice) }
            }
        case .ready where NeuralVoice.installedPiper(language: language) == choice:
            Button { voice.previewPiper(choice) } label: {
                HStack {
                    Label("Прослушать", systemImage: "speaker.wave.2.fill")
                    if voice.previewing == choice {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            Button("Удалить голос", role: .destructive) { piperToRemove = language }
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
