import SwiftUI
import AVFoundation

/// Настройки → «Озвучка» → «Голос»: автоматически лучший скачанный или конкретный голос акцента.
/// Нажатие — выбрать и сразу послушать. Улучшенные и премиум-голоса скачиваются в настройках iPhone
struct VoicePickerView: View {
    @AppStorage(SpeechSettings.accentKey) private var accent = SpeechSettings.defaultAccent
    @AppStorage(SpeechSettings.voiceKey) private var voiceID = ""
    @State private var voices: [AVSpeechSynthesisVoice] = []

    private static let sample = "Hello! This is how English words will sound."

    private var groups: [(title: String, voices: [AVSpeechSynthesisVoice])] {
        [("Премиум", voices.filter { $0.quality == .premium }),
         ("Улучшенные", voices.filter { $0.quality == .enhanced }),
         ("Обычные", voices.filter { $0.quality == .default })]
            .filter { !$0.voices.isEmpty }
    }

    var body: some View {
        List {
            Group {
                Section {
                    Button {
                        voiceID = ""
                        if let voice = SpeechSettings.resolveVoice(accent: accent, identifier: "") {
                            TextToSpeechManager.shared.preview(Self.sample, voice: voice)
                        }
                    } label: {
                        row(title: "Автоматически", subtitle: autoSubtitle, isSelected: voiceID.isEmpty || !voices.contains { $0.identifier == voiceID })
                    }
                } footer: {
                    Text("Приложение само берёт лучший скачанный голос для выбранного акцента.")
                }

                ForEach(groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.voices, id: \.identifier) { voice in
                            Button {
                                voiceID = voice.identifier
                                TextToSpeechManager.shared.preview(Self.sample, voice: voice)
                            } label: {
                                row(title: voice.name, subtitle: nil, isSelected: voiceID == voice.identifier)
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
        .onAppear { voices = SpeechSettings.voices(for: accent) }
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
        let voice = SpeechSettings.resolveVoice(accent: accent, identifier: voiceID)
        let chosen = SpeechSettings.voices(for: accent).contains { $0.identifier == voiceID }
        guard let voice else { return "Авто" }
        return chosen ? voice.name : "Авто · \(voice.name)"
    }
}
