import SwiftUI

/// Настройки → «Озвучка»: акцент, голос, скорость и нейросетевой голос
struct SpeechSettingsView: View {
    let mode: AppMode

    @AppStorage(SpeechSettings.accentKey) private var speechAccent = SpeechSettings.defaultAccent
    @AppStorage(SpeechSettings.voiceKey) private var speechVoice = ""
    @AppStorage(NeuralVoice.voiceKey) private var neuralVoiceID = 1
    @AppStorage(SpeechSettings.wordsEngineKey) private var wordsEngine = ""
    @AppStorage(SpeechSettings.rateKey) private var speechRate = SpeechSettings.defaultRate
    @AppStorage(SpeechSettings.autoSpeakKey) private var autoSpeak = false
    @AppStorage(NeuralVoice.booksKey) private var neuralReadsBooks = true
    @State private var neuralVoice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared

    /// Что видно у строки «Нейросетевой голос»: слова озвучивает скачанный Kokoro; книги — Kokoro на нейроядре или Piper, если включено «Читать книги этим голосом»
    private var neuralVoiceSummary: String {
        let readsBooks = neuralReadsBooks && (kokoroML.isReady || neuralVoice.hasPiper)
        if neuralVoice.phase == .ready || readsBooks { return "используется" }
        return hasNeuralVoice ? "не используется" : "не скачан"
    }
    /// Скачан хоть один нейроголос — Kokoro (процессор или нейроядро) или Piper
    private var hasNeuralVoice: Bool {
        neuralVoice.phase == .ready || kokoroML.isReady
            || neuralVoice.hasPiper
    }

    /// Озвучка
    @ViewBuilder
    private var voiceSection: some View {
        Section(footer: mode == .learning ? nil : Text("Акцент, голос и скорость — для английских книг. Книги на других языках читает голос своего языка.")) {
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
        }
    }

    /// «Читать книги этим голосом» — на виду, не внутри экрана нейроголоса
    @ViewBuilder
    private var booksVoiceSection: some View {
        Section {
            Toggle("Читать книги этим голосом", isOn: $neuralReadsBooks)

            if neuralReadsBooks && !hasNeuralVoice {
                Label("Чтобы заработало, откройте «Нейросетевой голос» и скачайте голос. Пока его нет, книги читает обычный голос iPhone.",
                      systemImage: "info.circle")
                    .scaledFont(size: 14)
                    .foregroundColor(.orange)
            }
        } footer: {
            Text("Включено — книги читает нейросетевой голос (Kokoro или Piper), если он скачан. Выключено — обычный голос iPhone с акцентом, голосом и скоростью из «Озвучки». Нейроголос тратит больше заряда.")
        }
    }

    var body: some View {
        Form {
            Group {
                voiceSection
                autoSpeakSection
                neuralSection
                booksVoiceSection
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Озвучка")
        .navigationBarTitleDisplayMode(.inline)
    }
}
