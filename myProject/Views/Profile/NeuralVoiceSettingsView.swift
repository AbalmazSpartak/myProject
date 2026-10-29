import SwiftUI

/// Настройки → «Озвучка» → «Нейросетевой голос»: скачать модель, выбрать голос, послушать, удалить;
/// языки книг (голоса Piper) — на своём экране; переключатель «Читать книги этим голосом» — в Настройках
struct NeuralVoiceSettingsView: View {
    @AppStorage(NeuralVoice.voiceKey) private var voiceID = 1
    @AppStorage(SpeechSettings.wordsEngineKey) private var wordsEngine = ""
    @State private var voice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared
    @AppStorage(KokoroML.preloadKey) private var preloadKokoro = true
    @State private var isConfirmingRemove = false
    @State private var isConfirmingMLRemove = false

    private static let sample = "Hello! This is how English words will sound."

    var body: some View {
        List {
            Group {
                Section {
                    NavigationLink {
                        BookLanguagesView()
                    } label: {
                        LabeledContent("Языки книг", value: voice.hasPiper ? "есть голоса" : "")
                    }
                } footer: {
                    Text("Лёгкие голоса Piper для книг на английском, русском, польском, немецком и других языках. Если голоса нет, книгу читает голос iPhone.")
                }

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
        .onAppear {
            NeuralVoice.alignWithAccent()
            voice.warmUp()
        }
        // Выбрали голос Kokoro — слова снова говорит он, а не системный
        .onChange(of: voiceID) { _, id in
            wordsEngine = ""
            // Голос другого акцента — акцент в «Озвучке» следует за ним, чтобы они не расходились
            if let chosen = NeuralVoice.voices.first(where: { $0.id == id }) {
                UserDefaults.standard.set(chosen.accentCode, forKey: SpeechSettings.accentKey)
            }
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
            VoiceProgressRow(title: "Загрузка…", fraction: fraction)
        case .unpacking(let fraction):
            VoiceProgressRow(title: "Распаковка…", fraction: fraction)
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
}
