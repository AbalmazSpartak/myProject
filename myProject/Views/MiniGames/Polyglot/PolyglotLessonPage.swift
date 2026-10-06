import SwiftUI

/// Каркас урока «Полиглота»: «‹ Полиглот», номер и название, видео-урок, содержимое и кнопка упражнения
struct PolyglotLessonPage<Content: View, Scheme: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isExercising = false

    let number: Int
    let title: String
    let videoURL: URL?
    let makeRound: () -> [PolyglotTask]
    @ViewBuilder let content: () -> Content
    /// Подсказка «Схема» во время упражнения
    @ViewBuilder let scheme: () -> Scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Полиглот")
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Урок \(number)")
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundColor(.gray)
                        Text(title)
                            .scaledFont(size: 30, design: .serif)
                            .foregroundColor(.brandDark)
                    }

                    if let videoURL {
                        // Встраивать эти ролики их автор запретил — открываем в YouTube
                        Button { openURL(videoURL) } label: {
                            Label("Смотреть видео-урок", systemImage: "play.rectangle.fill")
                                .scaledFont(size: 16, weight: .semibold)
                                .foregroundColor(.brandDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.cardBackground)
                                .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                    }

                    content()

                    Button { isExercising = true } label: {
                        Label("Составлять фразы", systemImage: "square.grid.3x2.fill")
                            .scaledFont(size: 18, weight: .bold)
                            .foregroundColor(.brandBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.brandDark))
                    }
                    .padding(.vertical, 20)
                }
                .padding(20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .fullScreenCover(isPresented: $isExercising) {
            PolyglotExerciseView(makeRound: makeRound, scheme: scheme)
                .appThemedColorScheme()
        }
    }
}

/// Подзаголовок раздела урока
struct PolyglotHeading: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .scaledFont(size: 22, weight: .semibold, design: .serif)
            .foregroundColor(.brandDark)
            .padding(.top, 6)
    }
}

/// Абзац урока: **жирный** выделяет главное
struct PolyglotParagraph: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(TopicText.attributed(text))
            .scaledFont(size: 16)
            .foregroundColor(.brandDark)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Примеры: английская фраза и перевод, нажатие — озвучка
struct PolyglotExamples: View {
    let examples: [(String, String)]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                row(example.0, example.1)
            }
        }
    }

    private func row(_ english: String, _ russian: String) -> some View {
        Button { TextToSpeechManager.shared.speak(english) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(english)
                        .scaledFont(size: 17, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                    Text(russian)
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.brandDark.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(english) — \(russian). Произнести")
    }
}
