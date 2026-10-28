import SwiftUI
import AVFoundation

/// Настройки → «Озвучка» → «Голос»: автоматически лучший скачанный или конкретный голос акцента.
/// Нажатие — выбрать и сразу послушать. Улучшенные и премиум-голоса скачиваются в настройках iPhone
struct VoicePickerView: View {
    @AppStorage(SpeechSettings.accentKey) private var accent = SpeechSettings.defaultAccent
    @AppStorage(SpeechSettings.voiceKey) private var voiceID = ""
    @AppStorage(SpeechSettings.wordsEngineKey) private var wordsEngine = ""
    @AppStorage(NeuralVoice.voiceKey) private var neuralID = 1
    @State private var neuralVoice = NeuralVoice.shared
    @State private var voices: [AVSpeechSynthesisVoice] = []

    private static let sample = "Hello! This is how English words will sound."

    private var groups: [(title: String, voices: [AVSpeechSynthesisVoice])] {
        [("Премиум", voices.filter { $0.quality == .premium }),
         ("Улучшенные", voices.filter { $0.quality == .enhanced }),
         ("Обычные", voices.filter { $0.quality == .default })]
            .filter { !$0.voices.isEmpty }
    }

    /// Слова сейчас говорит Kokoro: он скачан, и системный голос не выбран
    private var neuralOn: Bool { neuralVoice.phase == .ready && wordsEngine != "system" }

    var body: some View {
        List {
            Group {
                if neuralVoice.phase == .ready {
                    Section {
                        ForEach(NeuralVoice.voices(accent: accent)) { item in
                            Button {
                                wordsEngine = ""
                                neuralID = item.id
                                TextToSpeechManager.shared.speak(Self.sample)
                            } label: {
                                row(title: item.name, subtitle: item.female ? "женский" : "мужской",
                                    isSelected: neuralOn && neuralID == item.id)
                            }
                        }
                    } header: {
                        Text("Нейросетевые · Kokoro")
                    } footer: {
                        Text("Звучат живее системных, работают без интернета. Акцент выбирается в «Озвучке».")
                    }
                }

                Section {
                    Button {
                        wordsEngine = "system"
                        voiceID = ""
                        if let voice = SpeechSettings.resolveVoice(accent: accent, identifier: "") {
                            TextToSpeechManager.shared.preview(Self.sample, voice: voice)
                        }
                    } label: {
                        row(title: "Автоматически", subtitle: autoSubtitle,
                            isSelected: !neuralOn && (voiceID.isEmpty || !voices.contains { $0.identifier == voiceID }))
                    }
                } header: {
                    if neuralVoice.phase == .ready { Text("Системные") }
                } footer: {
                    Text("Приложение само берёт лучший скачанный голос для выбранного акцента.")
                }

                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.voices, id: \.identifier) { voice in
                            Button {
                                wordsEngine = "system"
                                voiceID = voice.identifier
                                TextToSpeechManager.shared.preview(Self.sample, voice: voice)
                            } label: {
                                row(title: voice.name, subtitle: nil, isSelected: !neuralOn && voiceID == voice.identifier)
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Как скачать голоса лучше", systemImage: "arrow.down.circle")
                            .font(.headline)
                        Text("Настройки iPhone → Универсальный доступ → Устный контент → Голоса → Английский. Выберите голос с пометкой «Улучшенный» или «Премиум» и скачайте — без интернета он тоже будет работать. Затем вернитесь сюда.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text(accent == "en-GB"
                         ? "Сейчас показаны британские голоса (English — United Kingdom). Акцент меняется в «Озвучке»."
                         : "Сейчас показаны американские голоса (English — United States). Акцент меняется в «Озвучке».")
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Голос")
        .navigationBarTitleDisplayMode(.inline)
        // Скачали голос в настройках iPhone и вернулись — список обновится
        .onAppear {
            NeuralVoice.alignWithAccent()
            voices = SpeechSettings.voices(for: accent)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            voices = SpeechSettings.voices(for: accent)
        }
    }

    private var autoSubtitle: String {
        guard let voice = SpeechSettings.resolveVoice(accent: accent, identifier: "") else { return "голос iOS по умолчанию" }
        return "сейчас: \(voice.name)\(Self.qualityNote(voice.quality))"
    }

    private static func qualityNote(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return " (премиум)"
        case .enhanced: return " (улучшенный)"
        default: return ""
        }
    }

    private func row(title: String, subtitle: String?, isSelected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.brandDark)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.brandTint)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Название выбранного голоса для строки в «Озвучке»
enum VoiceSummary {
    static func current(accent: String, voiceID: String) -> String {
        // Слова говорит Kokoro — в строке его голос
        let defaults = UserDefaults.standard
        if NeuralVoice.shared.phase == .ready, defaults.string(forKey: SpeechSettings.wordsEngineKey) != "system",
           let neural = NeuralVoice.voices.first(where: { $0.id == (defaults.object(forKey: NeuralVoice.voiceKey) as? Int ?? 1) }) {
            return neural.name
        }
        let voice = SpeechSettings.resolveVoice(accent: accent, identifier: voiceID)
        let chosen = SpeechSettings.voices(for: accent).contains { $0.identifier == voiceID }
        guard let voice else { return "Авто" }
        return chosen ? voice.name : "Авто · \(voice.name)"
    }
}
