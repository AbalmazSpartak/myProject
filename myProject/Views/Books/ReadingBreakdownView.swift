import SwiftUI
import SwiftData

extension PhonicsKind {
    /// Цвет подсветки в тексте и в разборе слова — мягкий, читается и на светлой, и на тёмной теме
    nonisolated var color: Color {
        switch self {
        case .vowelTeam: return .blue
        case .magicE: return .green
        case .rVowel: return .orange
        case .consonantPair: return .purple
        case .ending: return .teal
        case .silent: return .gray
        case .plain: return .clear
        }
    }

    nonisolated static let exceptionColor = Color.red
}

/// Легенда цветов подсветки с галочками — в шторке «Оформление»: что подсвечивать в книге
struct PhonicsLegend: View {
    @Binding var selection: Set<PhonicsOption>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PhonicsOption.allCases) { option in
                Button {
                    if selection.contains(option) { selection.remove(option) } else { selection.insert(option) }
                } label: {
                    row(option)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.contains(option) ? .isSelected : [])
            }
            HStack(spacing: 8) {
                preset("Только сложное", PhonicsOption.tricky)
                preset("Все", Set(PhonicsOption.allCases))
            }
            .padding(.top, 2)
            Text("Нажмите на слово — карточка покажет, как его читать, и объяснит каждое сочетание.")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private func row(_ option: PhonicsOption) -> some View {
        let isOn = selection.contains(option)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .scaledFont(size: 20)
                .foregroundColor(isOn ? .brown : .gray.opacity(0.6))
            swatch(option)
                .scaledFont(size: 16, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
                .frame(minWidth: 64, alignment: .leading)
                .opacity(isOn ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 1) {
                Text(title(option))
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(.brandDark)
                Text(detail(option))
                    .scaledFont(size: 12)
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func swatch(_ option: PhonicsOption) -> some View {
        switch option {
        case .silent:
            Text("k").foregroundColor(.gray.opacity(0.55)) + Text("nife")
        case .exception:
            Text("one").underline(pattern: .dot, color: PhonicsKind.exceptionColor)
        default:
            let kind = PhonicsKind(rawValue: option.rawValue) ?? .plain
            Text(kind.example.components(separatedBy: ",").first ?? "")
                .padding(.horizontal, 4)
                .background(kind.color.opacity(0.28))
                .cornerRadius(4)
        }
    }

    private func title(_ option: PhonicsOption) -> String {
        switch option {
        case .silent: return "Немые буквы"
        case .exception: return "Исключения"
        default: return PhonicsKind(rawValue: option.rawValue)?.title ?? ""
        }
    }

    private func detail(_ option: PhonicsOption) -> String {
        switch option {
        case .silent: return "бледные — не читаются: knife, write, light"
        case .exception: return "читается не по правилу; красная подсветка — где именно"
        default: return PhonicsKind(rawValue: option.rawValue)?.example ?? ""
        }
    }

    private func preset(_ title: String, _ options: Set<PhonicsOption>) -> some View {
        Button(title) { selection = options }
            .scaledFont(size: 14, weight: .semibold)
            .buttonStyle(.bordered)
            .tint(.brown)
            .disabled(selection == options)
    }
}

/// «Как читать»: слово по сочетаниям букв — звук каждого, правило, исключения и происхождение
struct ReadingBreakdownView: View {
    @Environment(\.modelContext) private var modelContext

    /// Слово как в тексте; если его нет в словаре произношения — словарная форма
    let word: String
    let lemma: String
    /// Транскрипция из основной базы, если слово там есть
    let transcription: String?
    /// Перевод — для списка «Отложенные» в «Произнеси»
    var translation = ""
    /// Кнопка «В тренировку произношения»; в самой тренировке не нужна
    var showsPracticeButton = true

    @State private var reading: WordReading?
    @State private var topic: CommunityTopic?
    @State private var isQueued = false

    var body: some View {
        // Пустой Group на экране не появляется — и .task у него не срабатывал: разбор не показывался никогда.
        // Невидимая заглушка, пока разбора нет
        VStack(spacing: 0) {
            if let reading {
                content(reading)
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .task(id: word + "|" + lemma) { analyze() }
        .sheet(item: $topic) { topic in
            TopicView(topic: topic, backTitle: "Слово")
                .appThemedColorScheme()
        }
    }

    private func analyze() {
        let tapped = ReadingRules.reading(for: word)
        if let tapped, !tapped.isGuess || lemma.isEmpty {
            reading = tapped
        } else {
            reading = ReadingRules.reading(for: lemma) ?? tapped
        }
        isQueued = reading.map { PronunciationQueue.contains($0.word) } ?? false
    }

    /// Слово — в список «Отложенные» тренировки «Произнеси»
    @ViewBuilder
    private func practiceButton(_ reading: WordReading) -> some View {
        if showsPracticeButton {
            Button {
                let sounds = transcription.flatMap { $0.isEmpty ? nil : $0 } ?? (reading.isGuess ? "" : ReadingRules.ipa(reading.phones))
                PronunciationQueue.add(reading.word, russian: translation, transcription: sounds)
                isQueued = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label(isQueued ? "В тренировке «Произнеси»" : "В тренировку произношения",
                      systemImage: isQueued ? "checkmark.circle.fill" : "mic.badge.plus")
                    .scaledFont(size: 14, weight: .semibold)
            }
            .tint(isQueued ? .green : .orange)
            .disabled(isQueued)
        }
    }

    private func content(_ reading: WordReading) -> some View {
        let exception = exceptionInfo(reading)
        return VStack(alignment: .leading, spacing: 14) {
            if let exception {
                exceptionBanner(exception, reading: reading)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Как читать")
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                Spacer()
                Button {
                    TextToSpeechManager.shared.speak(reading.word, slow: true)
                } label: {
                    Label("Медленно", systemImage: "tortoise.fill")
                        .scaledFont(size: 14, weight: .semibold)
                }
                .tint(.brown)
            }

            pronunciation(reading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(reading.chunks) { chunk in
                        chunkTile(chunk)
                    }
                }
            }

            notes(reading, skipping: exception?.text)

            if reading.isGuess {
                Text("Слова нет в словаре произношения — разбор по общим правилам, звучание может отличаться. Послушайте озвучку.")
                    .scaledFont(size: 12)
                    .foregroundColor(.gray)
            }

            topicLinks(reading)

            // У исключения кнопка — в плашке сверху
            if exception == nil {
                practiceButton(reading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    /// Транскрипция и примерное звучание по-русски
    private func pronunciation(_ reading: WordReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                if let transcription, !transcription.isEmpty, reading.word.caseInsensitiveCompare(lemma) == .orderedSame || lemma.isEmpty {
                    Text("[\(transcription)]")
                } else if !reading.isGuess {
                    Text("[\(ReadingRules.ipa(reading.phones))]")
                }
                Text("≈ «\(ReadingRules.russian(reading.phones))»")
                    .foregroundColor(.brandDark)
            }
            .scaledFont(size: 17, design: .serif)
            .foregroundColor(.gray)
            if reading.isException {
                Label("Читается не по правилам — красным отмечено, где именно", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(PhonicsKind.exceptionColor)
            }
        }
    }

    /// Плитка сочетания: буквы (немые — бледные), звук по-русски и в транскрипции
    private func chunkTile(_ chunk: PhonicsChunk) -> some View {
        let tint = chunk.irregular ? PhonicsKind.exceptionColor : chunk.kind.color
        return VStack(spacing: 4) {
            letters(chunk)
                .scaledFont(size: 22, weight: .semibold, design: .serif)
            Text(chunk.phones.isEmpty ? "—" : ReadingRules.russian(chunk.phones))
                .scaledFont(size: 14, weight: .semibold)
                .foregroundColor(.brandDark)
            Text(chunk.phones.isEmpty ? " " : ReadingRules.ipa(chunk.phones))
                .scaledFont(size: 11)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 40)
        .background(tint == .clear ? Color.brandBackground : tint.opacity(0.18))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(chunk.irregular ? tint : .clear, lineWidth: 1.5))
        .cornerRadius(10)
    }

    private func letters(_ chunk: PhonicsChunk) -> Text {
        chunk.range.reduce(Text("")) { text, index in
            let letter = Text(String(chunk.letters[chunk.letters.index(chunk.letters.startIndex, offsetBy: index - chunk.range.lowerBound)]))
            return text + (chunk.silent.contains(index) ? letter.foregroundColor(.gray.opacity(0.45)).strikethrough() : letter.foregroundColor(.brandDark))
        }
    }

    // MARK: - Исключение

    /// Коротко, в чём слово нарушает правило, и урок именно про этот случай
    private struct ExceptionInfo {
        let text: String
        let lesson: (id: UUID, title: String)
    }

    private func exceptionInfo(_ reading: WordReading) -> ExceptionInfo? {
        let contraction = reading.word.contains("'") || reading.word.contains("’")
        guard reading.isException, !reading.isGuess, !contraction,
              let chunk = reading.chunks.first(where: \.irregular) else { return nil }
        let key = reading.word.lowercased().filter { $0.isASCII && $0.isLetter }
        let text: String
        if let curated = ReadingNotes.words[key] {
            text = curated
        } else {
            var line = chunk.phones.isEmpty
                ? "\(chunk.letters) здесь не читается"
                : "\(chunk.letters) здесь читается как «\(ReadingRules.russian(chunk.phones))»"
            let said = ReadingRules.russian(chunk.phones.map(ReadingRules.base))
            if let usual = ReadingRules.usualReading(of: chunk.letters), usual != said {
                line += ", хотя обычно — «\(usual)»"
            }
            if let examples = chunk.examples, examples.lowercased() != key { line += ". Так же: \(examples)" }
            text = line + "."
        }
        return ExceptionInfo(text: text, lesson: lesson(for: chunk))
    }

    /// Урок по типу ошибки: немые буквы, th — свои темы, остальное — «Слова-исключения»
    private func lesson(for chunk: PhonicsChunk) -> (id: UUID, title: String) {
        if chunk.origin == nil, chunk.phones.isEmpty || chunk.kind == .silent {
            return (BuiltInTopics.silentLettersID, "Немые буквы")
        }
        if chunk.letters == "th" { return (BuiltInTopics.thSoundID, "Звук th") }
        return (BuiltInTopics.readingExceptionsID, "Слова-исключения")
    }

    private func exceptionBanner(_ info: ExceptionInfo, reading: WordReading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(PhonicsKind.exceptionColor)
                (Text("Исключение: ").bold() + Text(info.text))
                    .scaledFont(size: 14)
                    .foregroundColor(.brandDark)
            }
            Button {
                openTopic(info.lesson.id)
            } label: {
                Label("Урок: «\(info.lesson.title)»", systemImage: "book.pages")
                    .scaledFont(size: 14, weight: .semibold)
            }
            .tint(.brown)
            practiceButton(reading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PhonicsKind.exceptionColor.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PhonicsKind.exceptionColor.opacity(0.35), lineWidth: 1))
        .cornerRadius(12)
    }

    /// Правила для особых сочетаний и пояснения к слову целиком; skipping — уже показано в плашке исключения
    private func notes(_ reading: WordReading, skipping shown: String? = nil) -> some View {
        let explained = reading.chunks.filter { $0.kind != .plain || $0.irregular || !$0.silent.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(explained) { chunk in
                if let note = chunk.note {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(chunk.letters)
                            .scaledFont(size: 15, weight: .bold, design: .serif)
                            .foregroundColor(chunk.irregular ? PhonicsKind.exceptionColor : .brandDark)
                            .frame(minWidth: 34, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note)
                                .scaledFont(size: 14)
                                .foregroundColor(.brandDark)
                            if let examples = chunk.examples {
                                Text(examples)
                                    .scaledFont(size: 12)
                                    .italic()
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            ForEach(reading.notes.filter { $0 != shown }, id: \.self) { note in
                Label {
                    Text(note)
                        .scaledFont(size: 14)
                        .foregroundColor(.brandDark)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                }
            }
        }
    }

    /// Ссылки на темы «Сообщества» о произношении — по тому, что встретилось в слове
    @ViewBuilder
    private func topicLinks(_ reading: WordReading) -> some View {
        let links = topicIDs(reading)
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(links, id: \.id) { link in
                    Button {
                        openTopic(link.id)
                    } label: {
                        Label("Подробнее: «\(link.title)»", systemImage: "book.pages")
                            .scaledFont(size: 14, weight: .semibold)
                    }
                    .tint(.brown)
                }
            }
        }
    }

    private func topicIDs(_ reading: WordReading) -> [(id: UUID, title: String)] {
        var result: [(UUID, String)] = []
        let kinds = Set(reading.chunks.map(\.kind))
        let hasSilent = reading.chunks.contains { !$0.silent.isEmpty && $0.kind != .magicE }
        if hasSilent { result.append((BuiltInTopics.silentLettersID, "Немые буквы")) }
        if kinds.contains(.magicE) || kinds.contains(.vowelTeam) || kinds.contains(.rVowel) {
            result.append((BuiltInTopics.vowelReadingID, "Как читаются гласные"))
        }
        if reading.chunks.contains(where: { $0.letters == "th" }) { result.append((BuiltInTopics.thSoundID, "Звук th")) }
        if reading.isException, !reading.isGuess { result.append((BuiltInTopics.readingExceptionsID, "Слова-исключения")) }
        if reading.phones.contains(where: { ["IY1", "IH1", "UW1", "UH1"].contains($0) }) {
            result.append((BuiltInTopics.minimalPairsID, "Долгие и краткие звуки"))
        }
        return result.map { (id: $0.0, title: $0.1) }
    }

    private func openTopic(_ id: UUID) {
        var descriptor = FetchDescriptor<CommunityTopic>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        topic = try? modelContext.fetch(descriptor).first
    }
}
