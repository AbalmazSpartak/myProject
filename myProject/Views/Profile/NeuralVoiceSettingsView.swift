import SwiftUI

/// Настройки → «Озвучка» → «Нейросетевой голос»: скачать модель, включить, выбрать голос, послушать, удалить;
/// книги вслух этим голосом и лёгкие голоса Piper для английских и русских книг
struct NeuralVoiceSettingsView: View {
    @AppStorage(NeuralVoice.enabledKey) private var isEnabled = false
    @AppStorage(NeuralVoice.voiceKey) private var voiceID = 1
    @AppStorage(NeuralVoice.booksKey) private var readsBooks = true
    @State private var voice = NeuralVoice.shared
    @State private var isConfirmingRemove = false
    /// Язык, голос Piper которого удаляем («en», «ru»)
    @State private var piperToRemove: String?
    @State private var englishChoice = NeuralVoice.installedPiper(language: "en") ?? .kristin
    @State private var russianChoice = NeuralVoice.installedPiper(language: "ru") ?? .dmitri

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
                        if voice.kokoroTooSlow {
                            Button("Проверить скорость снова") { voice.resetKokoroCheck() }
                        }
                    } footer: {
                        Text(voice.kokoroTooSlow
                             ? "На этом устройстве Kokoro не успевает читать книги без пауз — их читает голос Piper (если скачан) или системный. Слова Kokoro озвучивает как раньше."
                             : "Фраза готовится от полусекунды до нескольких секунд — на новых iPhone быстрее; уже сказанные слова повторяются сразу.")
                    }

                    Section {
                        Button("Удалить голос", role: .destructive) { isConfirmingRemove = true }
                    }
                }

                piperSection(language: "en", choice: $englishChoice, header: "Английские книги",
                             footer: "Лёгкий голос Piper: читает без пауз даже там, где Kokoro не успевает (iPhone 12, iPad Air 4 и старше). Без интернета, свободная лицензия. Скачивается отдельно (\(NeuralVoice.piperDownloadSize)); при скачивании другого голоса прежний удаляется. Скачали — английские книги читает он; вернуть Kokoro можно здесь же.")

                piperSection(language: "ru", choice: $russianChoice, header: "Русские книги",
                             footer: "Голос Piper для чтения русских книг вслух, мужской, без интернета. Скачивается отдельно (\(NeuralVoice.piperDownloadSize)); при скачивании другого голоса прежний удаляется.")

                if voice.phase == .ready || voice.piperPhase("en") == .ready || voice.piperPhase("ru") == .ready {
                    Section {
                        Toggle("Читать книги этим голосом", isOn: $readsBooks)
                    } footer: {
                        Text("Английские книги читает Kokoro, если устройство успевает, иначе Piper; русские — Piper. Подсвечивается всё предложение: время отдельных слов нейросеть не отдаёт. Заряда тратится больше, чем с системным голосом.")
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
        .alert("Удалить голос?", isPresented: Binding(get: { piperToRemove != nil }, set: { if !$0 { piperToRemove = nil } })) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                if let piperToRemove { voice.removePiper(language: piperToRemove) }
            }
        } message: {
            Text("Эти книги снова будет читать системный голос. Скачать можно заново.")
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

    /// Голос Piper для книг на одном языке: выбор, скачать, прослушать, удалить;
    /// у английских книг, когда скачаны оба, — кто их читает: Kokoro или Piper
    private func piperSection(language: String, choice: Binding<NeuralVoice.PiperVoice>, header: String, footer: String) -> some View {
        Section {
            if language == "en", voice.phase == .ready, voice.piperPhase("en") == .ready {
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
            Label("Голос «\(choice.title)» скачан", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
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
                Label("Скачать «\(choice.title)» (\(NeuralVoice.piperDownloadSize))", systemImage: "arrow.down.circle.fill")
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
