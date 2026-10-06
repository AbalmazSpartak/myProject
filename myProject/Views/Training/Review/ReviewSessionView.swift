import SwiftUI
import SwiftData

/// Прогон слов «Повторения»: слово → «Показать ответ» → «Знаю» / «Не знаю».
/// Расписание FSRS не меняется; «Не знаю» отмечает слово ошибкой, ответы идут в график профиля
struct ReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("show_word_images") private var showWordImages = true
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue

    let showEnglish: Bool
    let autoSpeak: Bool

    @State private var queue: [Word]
    @State private var index = 0
    @State private var isRevealed = false
    @State private var known: [Word] = []
    @State private var unknown: [Word] = []

    init(words: [Word], showEnglish: Bool, autoSpeak: Bool) {
        self.showEnglish = showEnglish
        self.autoSpeak = autoSpeak
        _queue = State(initialValue: words)
    }

    /// Подход заканчивается по настройке «Слов за подход» (0 — без остановки) и в конце списка
    @State private var isApproachDone = false

    private var word: Word? {
        index < queue.count && !isApproachDone ? queue[index] : nil
    }


    var body: some View {
        VStack(spacing: 0) {
            header
            if let word {
                card(word)
            } else {
                summary
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onChange(of: word?.persistentModelID, initial: true) { _, _ in
            guard autoSpeak, showEnglish, let word else { return }
            TextToSpeechManager.shared.speak(word.english)
        }
        .onChange(of: isRevealed) { _, revealed in
            guard revealed, autoSpeak, !showEnglish, let word else { return }
            TextToSpeechManager.shared.speak(word.english)
        }
    }

    private var header: some View {
        HStack {
            Button("Закрыть") { dismiss() }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            Spacer()
            if word != nil {
                Text("\(index + 1) из \(queue.count)")
                    .scaledFont(size: 15, weight: .semibold, design: .rounded)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("✓ \(known.count)  ✗ \(unknown.count)")
                .scaledFont(size: 14, weight: .semibold, design: .rounded)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Карточка

    private func card(_ word: Word) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Text(showEnglish ? word.english : word.russian)
                            .scaledFont(size: 34, weight: .semibold, design: .serif)
                            .foregroundColor(.brandDark)
                            .multilineTextAlignment(.center)
                        if showEnglish || isRevealed {
                            Button { TextToSpeechManager.shared.speak(word.english) } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .scaledFont(size: 18, weight: .semibold)
                                    .foregroundColor(.brandDark)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.brandFill))
                            }
                            .accessibilityLabel("Произнести")
                        }
                    }
                    if showEnglish, !word.displayTranscription.isEmpty {
                        Text(word.displayTranscription)
                            .scaledFont(size: 16, weight: .medium, design: .rounded)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 30)

                if isRevealed {
                    VStack(spacing: 16) {
                        if showWordImages { WordImageView(word: word) }
                        Text(showEnglish ? word.russian : word.english)
                            .scaledFont(size: 26, weight: .regular, design: .serif)
                            .foregroundColor(.brandDark)
                            .multilineTextAlignment(.center)
                        if !showEnglish, !word.displayTranscription.isEmpty {
                            Text(word.displayTranscription)
                                .scaledFont(size: 15, weight: .medium, design: .rounded)
                                .foregroundColor(.gray)
                        }
                        if !word.example.isEmpty {
                            Text(word.attributedExample)
                                .scaledFont(size: 16, design: .serif)
                                .foregroundColor(.brandDark)
                                .multilineTextAlignment(.center)
                                .padding(14)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.brandAccent))
                        }
                        HStack(spacing: 12) {
                            answerButton("Не знаю", color: FSRSRating.again.color) { answer(known: false) }
                            answerButton("Знаю", color: FSRSRating.easy.color) { answer(known: true) }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isRevealed = true }
                    } label: {
                        Text("Показать ответ")
                            .scaledFont(size: 18, weight: .bold)
                            .foregroundColor(.brandBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.brandDark))
                    }
                    .padding(.top, 20)
                }
            }
            .padding(20)
        }
        .task(id: word.persistentModelID) {
            guard showWordImages else { return }
            await WordImageLoader.loadIfNeeded(word)
        }
    }

    /// Как кнопки оценок в карточках: бледный фон и надпись цветом
    private func answerButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 17, weight: .bold, design: .rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(14)
        }
    }

    // MARK: - Итог подхода

    private var summary: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundColor(FSRSRating.easy.color)
            Text(index >= queue.count ? "Повторение пройдено" : "Подход завершён")
                .scaledFont(size: 26, design: .serif)
                .foregroundColor(.brandDark)
            Text("Знаю: \(known.count) · Не знаю: \(unknown.count)")
                .scaledFont(size: 17)
                .foregroundColor(.gray)
            Spacer()
            if index < queue.count {
                bigButton("Ещё подход") {
                    isApproachDone = false
                }
            }
            if !unknown.isEmpty {
                bigButton("Повторить «Не знаю» · \(unknown.count)", secondary: index < queue.count) {
                    queue = unknown.shuffled()
                    index = 0
                    known = []
                    unknown = []
                    isApproachDone = false
                }
            }
            Button("Закончить") { dismiss() }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandTint)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
    }

    private func bigButton(_ title: String, secondary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 18, weight: .bold)
                .foregroundColor(secondary ? .brandDark : .brandBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(secondary ? Color.brandFill : Color.brandDark))
        }
    }

    // MARK: - Ответ

    private func answer(known isKnown: Bool) {
        guard let word else { return }
        // Расписание FSRS не трогаем: это прогон. «Не знаю» — в ошибки, оба ответа — в график профиля
        if isKnown {
            known.append(word)
            DailyStudy.record(word, rating: .good)
        } else {
            unknown.append(word)
            word.isMistake = true
            DailyStudy.record(word, rating: .again)
            try? modelContext.save()
        }
        Haptics.tap()
        isRevealed = false
        index += 1
        if index >= queue.count || (sessionLength > 0 && index % sessionLength == 0) {
            isApproachDone = true
        }
    }
}
