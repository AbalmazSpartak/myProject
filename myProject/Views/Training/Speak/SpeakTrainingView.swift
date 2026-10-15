import SwiftUI
import SwiftData

/// «Произнеси»: слово на экране — послушать образец, сказать в микрофон, телефон распознаёт и проверяет.
/// Расписание повторений не меняется — это отдельная тренировка произношения
struct SpeakTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage("speak_source") private var source = Source.learning

    enum Source: String, CaseIterable, Identifiable {
        case saved, learning, all, mistakes

        var id: String { rawValue }

        var title: String {
            switch self {
            case .saved: return "Отложенные"
            case .learning: return "Изучаемые"
            case .all: return "Все"
            case .mistakes: return "Ошибки"
            }
        }
    }

    /// Слово для тренировки: из словаря или из «Отложенных» (слово из книги может быть не в словаре)
    private struct PracticeItem: Identifiable {
        let id: String
        let english: String
        let transcription: String
        let russian: String

        init(_ word: Word) {
            id = word.english.lowercased()
            english = word.english
            transcription = word.transcription
            russian = word.russian
        }

        init(_ entry: PronunciationQueue.Entry) {
            id = entry.english.lowercased()
            english = entry.english
            transcription = entry.transcription
            russian = entry.russian
        }

        var displayTranscription: String {
            let bare = Word.bareTranscription(transcription)
            return bare.isEmpty ? "" : "/\(bare)/"
        }
    }

    private enum Phase { case setup, practice, summary }

    /// Ответ по слову: получилось ли с первой попытки и получилось ли вообще
    private struct Outcome {
        let item: PracticeItem
        var firstTry: Bool
        var passed: Bool
    }

    static let sessionLength = 10

    @State private var phase = Phase.setup
    @State private var words: [PracticeItem] = []
    @State private var index = 0
    @State private var outcomes: [Outcome] = []
    @State private var attempts = 0
    /// Результат последней попытки: nil — ещё не говорили
    @State private var passed: Bool?
    @State private var checker = SpeechChecker()
    @State private var emptyMessage: String?

    private var word: PracticeItem? { words.indices.contains(index) ? words[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            switch phase {
            case .setup: setup
            case .practice: practice
            case .summary: summary
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onDisappear { checker.cancel() }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            // Из тренировки и итога — к выбору слов, оттуда — на «Обзор»
            Button {
                checker.cancel()
                if phase == .setup { dismiss() } else { phase = .setup }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text(phase == .setup ? "Обзор" : "Назад")
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            }
            Spacer()
            HelpButton(topic: .speak) { checker.cancel() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .overlay {
            Text(phase == .practice ? "\(min(index + 1, words.count)) из \(words.count)" : "Произнеси")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Выбор слов

    private var setup: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "mic.circle.fill")
                    .scaledFont(size: 64)
                    .foregroundColor(.orange)
                Text("Послушайте слово, произнесите его в микрофон — телефон распознает речь и скажет, понятно ли получилось.")
                    .scaledFont(size: 16)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.center)

                Picker("Слова", selection: $source) {
                    ForEach(Source.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if source == .saved {
                    Text(savedHint)
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                if let emptyMessage {
                    Text(emptyMessage)
                        .scaledFont(size: 14)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: begin) {
                    Text("Начать — \(Self.sessionLength) слов")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundStyle(Color.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandDark)

                Text("Распознавание проверяет, понятно ли слово на слух, а не каждый звук. Работает на телефоне, без интернета. Расписание повторений слов не меняется.")
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }

    private var savedHint: String {
        let count = PronunciationQueue.entries().count
        return count == 0
            ? "Отложенных слов нет. Добавить: в читалке нажмите на слово → «В тренировку произношения»."
            : "Отложено слов: \(count). Слово, сказанное верно с первой попытки, уходит из списка."
    }

    private func begin() {
        let inScope = StudyWords.scope(studyScope)
        let picked: [PracticeItem]
        switch source {
        case .saved:
            picked = PronunciationQueue.entries().shuffled().prefix(Self.sessionLength).map(PracticeItem.init)
        case .learning:
            picked = StudyWords.random(StudyWords.all(inScope, #Predicate<Word> { $0.reps > 0 }), limit: Self.sessionLength, in: modelContext)
                .map(PracticeItem.init)
        case .all:
            picked = StudyWords.random(inScope, limit: Self.sessionLength, in: modelContext).map(PracticeItem.init)
        case .mistakes:
            picked = StudyWords.random(StudyWords.all(inScope, #Predicate<Word> { $0.isMistake }), limit: Self.sessionLength, in: modelContext)
                .map(PracticeItem.init)
        }
        guard !picked.isEmpty else {
            switch source {
            case .saved: emptyMessage = "Отложенных слов нет — выберите другие слова."
            case .learning: emptyMessage = "Пока нет слов, которые вы уже учите. Выберите «Все»."
            case .mistakes: emptyMessage = "Ошибок нет — выберите другие слова."
            case .all: emptyMessage = "В словаре нет слов."
            }
            return
        }
        emptyMessage = nil
        Haptics.tap()
        words = picked
        index = 0
        outcomes = []
        startWord()
        phase = .practice
    }

    private func startWord() {
        attempts = 0
        passed = nil
        checker.reset()
    }

    // MARK: - Тренировка

    @ViewBuilder
    private var practice: some View {
        if let word {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(word.english)
                            .scaledFont(size: 38, weight: .semibold, design: .serif)
                            .foregroundColor(.brandDark)
                            .multilineTextAlignment(.center)
                        if !word.displayTranscription.isEmpty {
                            Text(word.displayTranscription)
                                .scaledFont(size: 17, design: .serif)
                                .foregroundColor(.gray)
                        }
                        Text(word.russian)
                            .scaledFont(size: 16)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    HStack(spacing: 12) {
                        listenButton("Послушать", icon: "speaker.wave.2.fill") { TextToSpeechManager.shared.speak(word.english) }
                        listenButton("Медленно", icon: "tortoise.fill") { TextToSpeechManager.shared.speak(word.english, slow: true) }
                    }

                    micButton(for: word)

                    resultBlock(for: word)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }

    private func listenButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .scaledFont(size: 15, weight: .semibold)
                .foregroundColor(.brandDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.cardBackground))
        }
        .buttonStyle(.plain)
        .disabled(checker.phase == .listening)
    }

    /// Большая кнопка: нажать — слушаем; во время записи нажать ещё раз — хватит
    private func micButton(for word: PracticeItem) -> some View {
        let listening = checker.phase == .listening
        return VStack(spacing: 10) {
            Button {
                if listening {
                    checker.stop()
                } else {
                    Haptics.tap()
                    Task { await checker.listen(expecting: word.english) { heard in check(heard, word: word) } }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(listening ? Color.red : Color.orange)
                        .frame(width: 96, height: 96)
                        .shadow(color: (listening ? Color.red : Color.orange).opacity(0.35), radius: listening ? 14 : 6)
                    if checker.phase == .processing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: listening ? "stop.fill" : "mic.fill")
                            .scaledFont(size: 36, weight: .semibold)
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(listening ? 1.06 : 1)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: listening)
            }
            .buttonStyle(.plain)
            .disabled(checker.phase == .processing)
            .accessibilityLabel(listening ? "Остановить" : "Сказать слово")

            Text(listening ? (checker.heard.isEmpty ? "Говорите…" : checker.heard) : (passed == nil ? "Нажмите и скажите слово" : " "))
                .scaledFont(size: 15)
                .foregroundColor(.gray)
                .lineLimit(2)
        }
    }

    private func check(_ heard: String, word: PracticeItem) {
        attempts += 1
        let ok = SpeechChecker.matches(heard, word.english)
        passed = ok
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .warning)
        if let position = outcomes.firstIndex(where: { $0.item.id == word.id }) {
            outcomes[position].passed = outcomes[position].passed || ok
        } else {
            outcomes.append(Outcome(item: word, firstTry: ok, passed: ok))
        }
        // Отложенное слово получилось сразу — из списка
        if ok, attempts == 1, source == .saved { PronunciationQueue.remove(word.english) }
    }

    @ViewBuilder
    private func resultBlock(for word: PracticeItem) -> some View {
        if checker.isDenied {
            VStack(spacing: 10) {
                Text("Нужен доступ к микрофону и распознаванию речи.")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .tint(.brown)
            }
        } else if checker.isUnavailable {
            Text("Распознавание речи сейчас недоступно. Проверьте, что в настройках iPhone есть английский язык для диктовки, и попробуйте ещё раз.")
                .scaledFont(size: 14)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        } else if let passed, checker.phase == .finished {
            VStack(spacing: 14) {
                if passed {
                    Label("Понятно! Так и звучит", systemImage: "checkmark.circle.fill")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundColor(.green)
                } else {
                    VStack(spacing: 4) {
                        Label("Не совсем", systemImage: "xmark.circle.fill")
                            .scaledFont(size: 18, weight: .bold)
                            .foregroundColor(.red)
                        Text(checker.heard.isEmpty ? "Ничего не расслышал — говорите чуть громче и ближе к телефону" : "Услышано: «\(checker.heard)»")
                            .scaledFont(size: 15)
                            .foregroundColor(.brandDark)
                            .multilineTextAlignment(.center)
                    }
                    // Подсказка, как читается слово, — из «Правил чтения»
                    ReadingBreakdownView(word: word.english, lemma: "", transcription: word.transcription,
                                         showsPracticeButton: false)
                }

                HStack(spacing: 12) {
                    if !passed {
                        Button {
                            self.passed = nil
                            checker.reset()
                        } label: {
                            Text("Ещё раз")
                                .scaledFont(size: 16, weight: .semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.brandDark)
                    }
                    Button(action: nextWord) {
                        Text(index + 1 < words.count ? "Дальше" : "Итог")
                            .scaledFont(size: 16, weight: .bold)
                            .foregroundStyle(Color.brandBackground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandDark)
                }
            }
        }
    }

    private func nextWord() {
        if index + 1 < words.count {
            index += 1
            startWord()
        } else {
            checker.cancel()
            phase = .summary
        }
    }

    // MARK: - Итог

    private var summary: some View {
        let firstTry = outcomes.filter(\.firstTry).count
        return ScrollView {
            VStack(spacing: 18) {
                Text("С первой попытки")
                    .scaledFont(size: 16)
                    .foregroundColor(.gray)
                Text("\(firstTry) из \(outcomes.count)")
                    .scaledFont(size: 48, weight: .bold, design: .rounded)
                    .foregroundColor(.brandDark)

                VStack(spacing: 8) {
                    ForEach(outcomes, id: \.item.id) { outcome in
                        HStack {
                            Image(systemName: outcome.firstTry ? "checkmark.circle.fill" : outcome.passed ? "arrow.uturn.right.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(outcome.firstTry ? .green : outcome.passed ? .orange : .red)
                            Text(outcome.item.english)
                                .scaledFont(size: 17, weight: .semibold, design: .serif)
                                .foregroundColor(.brandDark)
                            Spacer()
                            Button {
                                TextToSpeechManager.shared.speak(outcome.item.english)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.brown)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Послушать \(outcome.item.english)")
                        }
                        .padding(12)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                    }
                }
                Text("✅ — с первой попытки, ↪︎ — со второй и дальше, ✗ — не получилось")
                    .scaledFont(size: 12)
                    .foregroundColor(.gray)

                Button(action: begin) {
                    Text("Ещё подход")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundStyle(Color.brandBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandDark)
                Button("К выбору слов") { phase = .setup }
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(.brandDark)
            }
            .padding(24)
        }
    }
}
