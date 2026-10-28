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
                             footer: "Лёгкий голос Piper: читает без пауз даже там, где Kokoro не успевает (iPhone 12, iPad Air 4 и старше). Без интернета, свободная лицензия. Скачивается отдельно (\(NeuralVoice.piperDownloadSize)); при скачивании другого голоса прежний удаляется. Скачали — английские книги читает он; вернуть Kokoro можно здесь же.")

                piperSection(language: "ru", choice: $russianChoice, header: "Русские книги",
                             footer: "Голос Piper для чтения русских книг вслух, мужской, без интернета. Скачивается отдельно (\(NeuralVoice.piperDownloadSize)); при скачивании другого голоса прежний удаляется.")

                // Один раздел: выбор голоса, прослушать, «Голос скачан» (или скачать), удалить
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
                    Text(kokoroFooter)
                }

                if KokoroML.isSupported {
                    Section {
                        kokoroMLStatus
                    } header: {
                        Text("Kokoro на нейроядре — для книг")
                    } footer: {
                        Text("Тот же голос Kokoro (выбор голоса — выше), но на нейроядре iPhone: читает английские книги без пауз даже на iPhone 12, подсвечивается каждое слово. Скачивается отдельно (\(KokoroML.downloadSize)); в память загружается около 25 секунд — при открытии английской книги, а с «Загружать при запуске» в режиме «Чтение» — сразу при запуске приложения, если последняя книга английская. В памяти занимает ~700 МБ; через 10 минут без чтения выгружается.")
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Нейросетевой голос")
        .navigationBarTitleDisplayMode(.inline)
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

    private var kokoroFooter: String {
        let about = "Голос Kokoro звучит живее системного и работает без интернета. Скачивается один раз (\(NeuralVoice.downloadSize)), в резервную копию iCloud не попадает. Пока голос не скачан или выключен — говорит системный."
        guard voice.phase == .ready else { return about }
        let state = voice.kokoroTooSlow
            ? "На этом устройстве Kokoro не успевает читать книги без пауз — их читает голос Piper (если скачан) или системный. Слова Kokoro озвучивает как раньше."
            : "Фраза готовится от полусекунды до нескольких секунд — на новых iPhone быстрее; уже сказанные слова повторяются сразу."
        return state + "\n\n" + about
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
            Label(kokoroML.isLoaded ? "Скачан, в памяти" : "Скачан", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
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
