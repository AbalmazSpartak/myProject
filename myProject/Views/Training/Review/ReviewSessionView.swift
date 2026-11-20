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
        .onAppear { NeuralVoice.shared.warmUp() }
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
            if word != nil {
                Text("\(index + 1) из \(queue.count)")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(Color.brandMuted)
                    .padding(.leading, 16)
            }
            Spacer()
            LXTextButton(title: "Закрыть", isMuted: true) { dismiss() }
                .padding(.trailing, 6)
        }
        .padding(.top, 6)
        .frame(minHeight: 52)
    }

    // MARK: - Карточка

    private func card(_ word: Word) -> some View {
        VStack(spacing: 0) {
            TrainingCard(score: "Знаю \(known.count) · Не знаю \(unknown.count)", level: word.cefrLevel) {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text(showEnglish ? word.english : word.russian)
                                .scaledFont(size: 44, weight: .medium, design: .serif)
                                .foregroundStyle(Color.brandDark)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.5)
                            // Транскрипция и часть речи — одной строкой; без транскрипции — только часть речи
                            HStack(spacing: 8) {
                                if showEnglish, !word.displayTranscription.isEmpty {
                                    Text(word.displayTranscription)
                                        .scaledFont(size: 17)
                                        .foregroundStyle(Color.brandMuted)
                                }
                                PartOfSpeechBadge(word: word)
                            }
                            if showEnglish || isRevealed {
                                Button { TextToSpeechManager.shared.speak(word.english) } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .scaledFont(size: 20)
                                        .foregroundStyle(Color.brandOnSoft)
                                        .frame(width: 48, height: 48)
                                        .background(Circle().fill(Color.brandAccent))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Произнести")
                            }
                        }
                        .padding(.top, 12)

                        if isRevealed {
                            VStack(spacing: 14) {
                                if showWordImages { WordImageView(word: word) }
                                Text(showEnglish ? word.russian : word.english)
                                    .scaledFont(size: 30, weight: .medium, design: .serif)
                                    .foregroundStyle(Color.brandDark)
                                    .multilineTextAlignment(.center)
                                if !showEnglish, !word.displayTranscription.isEmpty {
                                    Text(word.displayTranscription)
                                        .scaledFont(size: 15)
                                        .foregroundStyle(Color.brandMuted)
                                }
                                if !word.example.isEmpty {
                                    FlashcardExample(word: word)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, 16)

            Group {
                if isRevealed {
                    HStack(spacing: 10) {
                        LXButton(title: "Не знаю", style: .outline) { answer(known: false) }
                        LXButton(title: "Знаю") { answer(known: true) }
                    }
                } else {
                    LXButton(title: "Показать ответ") {
                        withAnimation(.easeOut(duration: 0.2)) { isRevealed = true }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .task(id: word.persistentModelID) {
            guard showWordImages else { return }
            await WordImageLoader.loadIfNeeded(word)
        }
    }

    // MARK: - Итог подхода

    private var summary: some View {
        TrainingSummary(
            subtitle: index >= queue.count ? "Повторение пройдено." : "Подход завершён.",
            tiles: [
                .init(symbol: "checkmark.circle", color: .statusKnown, value: known.count, title: "Знаю"),
                .init(symbol: "xmark.circle", color: .statusLearning, value: unknown.count, title: "Не знаю")
            ],
            laterTitle: "Не знаю",
            later: unknown,
            showsContinue: index < queue.count,
            extraTitle: unknown.isEmpty ? nil : "Повторить «Не знаю» · \(unknown.count)",
            onExtra: {
                queue = unknown.shuffled()
                index = 0
                known = []
                unknown = []
                isApproachDone = false
            },
            onContinue: { isApproachDone = false },
            onExit: { dismiss() }
        )
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
