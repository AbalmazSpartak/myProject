import SwiftUI

/// Настройки → «Озвучка»: акцент, голос, скорость и нейросетевой голос
struct SpeechSettingsView: View {
    let mode: AppMode

    @AppStorage(SpeechSettings.accentKey) private var speechAccent = SpeechSettings.defaultAccent
    @AppStorage(SpeechSettings.voiceKey) private var speechVoice = ""
    @AppStorage(NeuralVoice.voiceKey) private var neuralVoiceID = 1
    @AppStorage(SpeechSettings.wordsEngineKey) private var wordsEngine = ""
    @AppStorage("settings_book_language") private var bookLanguage = "en"
    /// Не читается: подписка на ключ перерисовывает экран, когда бегунок книг меняет значение
    @AppStorage(SpeechSettings.bookRateKey) private var bookRateValue = 0.0
    @AppStorage(SpeechSettings.rateKey) private var speechRate = SpeechSettings.defaultRate
    @AppStorage(SpeechSettings.autoSpeakKey) private var autoSpeak = false
    @State private var neuralVoice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared

    /// Что видно у строки «Нейросетевой голос»: скачано ли что-то
    private var neuralVoiceSummary: String { hasNeuralVoice ? "скачан" : "не скачан" }
    /// Скачан хоть один нейроголос — Kokoro (процессор или нейроядро) или Piper
    private var hasNeuralVoice: Bool {
        neuralVoice.phase == .ready || kokoroML.isReady
            || neuralVoice.hasPiper
    }

    /// Озвучка
    @ViewBuilder
    private var voiceSection: some View {
        Section {
            Picker("Акцент", selection: $speechAccent) {
                Text("Американский").tag("en-US")
                Text("Британский").tag("en-GB")
            }
            .pickerStyle(.segmented)
            // Голос Kokoro другого акцента не подходит — берём первый голос нового акцента
            .onChange(of: speechAccent) { _, _ in NeuralVoice.alignWithAccent() }
            .onAppear { NeuralVoice.alignWithAccent() }

            NavigationLink {
                VoicePickerView()
            } label: {
                LabeledContent("Голос", value: VoiceSummary.current(accent: speechAccent, voiceID: speechVoice,
                                                                         neuralID: neuralVoiceID, wordsEngine: wordsEngine))
            }

            SpeechRateSlider(rate: $speechRate)

            Button {
                TextToSpeechManager.shared.speak("Hello! This is how English words will sound.")
            } label: {
                Label("Прослушать", systemImage: "speaker.wave.2.fill")
            }
        } header: {
            Text("Слова")
        } footer: {
            Text("Как приложение произносит слова: в карточках, тренировках и при нажатии на слово.")
                .textSelection(.enabled)
        }
    }

    /// «Озвучивать слово сразу» — только в «Изучении»
    @ViewBuilder
    private var autoSpeakSection: some View {
        if mode == .learning {
            Section {
                Toggle("Озвучивать слово сразу", isOn: $autoSpeak)
            } footer: {
                Text("При переводе с русского на английский слово звучит после ответа, чтобы не подсказывать.")
                    .textSelection(.enabled)
            }
        }
    }

    /// Нейроголос: экран со скачиванием и выбором голосов
    @ViewBuilder
    private var neuralSection: some View {
        Section {
            NavigationLink {
                NeuralVoiceSettingsView()
            } label: {
                LabeledContent("Нейросетевой голос", value: neuralVoiceSummary)
            }
        } footer: {
            Text("Скачать и настроить лёгкую озвучку Piper и Kokoro.")
                .textSelection(.enabled)
        }
    }

    /// Книги: язык, голос и скорость чтения — свои, не зависят от слов
    @ViewBuilder
    private var booksSection: some View {
        Section {
            Picker("Язык книги", selection: $bookLanguage) {
                ForEach(NeuralVoice.PiperVoice.languages, id: \.code) { Text($0.title).tag($0.code) }
            }

            NavigationLink {
                BookVoicePickerView(code: bookLanguage, title: bookLanguageTitle)
            } label: {
                LabeledContent("Голос", value: neuralVoice.bookVoiceTitle(bookLanguage))
            }

            SpeechRateSlider(rate: bookRate, title: "Скорость чтения")

            Button {
                neuralVoice.previewBook(language: bookLanguage)
            } label: {
                HStack {
                    Label("Прослушать", systemImage: "speaker.wave.2.fill")
                    if neuralVoice.isPreviewingBook {
                        Spacer()
                        ProgressView()
                    }
                }
            }
        } header: {
            Text("Книги")
        } footer: {
            Text("Как читаются книги вслух. Голос и скорость выбираются для каждого языка книги отдельно от слов.")
                .textSelection(.enabled)
        }
    }

    private var bookLanguageTitle: String {
        NeuralVoice.PiperVoice.languages.first { $0.code == bookLanguage }?.title ?? ""
    }

    private var bookRate: Binding<Double> {
        Binding(get: { SpeechSettings.bookRate }, set: { UserDefaults.standard.set($0, forKey: SpeechSettings.bookRateKey) })
    }

    var body: some View {
        Form {
            Group {
                // Слова — только в «Изучении»; в «Чтении» их нет
                if mode == .learning { voiceSection }
                autoSpeakSection
                booksSection
                neuralSection
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Озвучка")
        .navigationBarTitleDisplayMode(.inline)
    }
}
