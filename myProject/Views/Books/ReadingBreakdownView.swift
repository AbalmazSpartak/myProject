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

/// Легенда цветов подсветки — в шторке «Оформление»
struct PhonicsLegend: View {
    let all: Bool

    private var kinds: [PhonicsKind] {
        all ? [.vowelTeam, .magicE, .rVowel, .consonantPair, .ending] : [.vowelTeam, .magicE, .rVowel]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(kinds, id: \.self) { kind in
                row(swatch: Text(kind.example.components(separatedBy: ",").first ?? "")
                        .padding(.horizontal, 4)
                        .background(kind.color.opacity(0.28))
                        .cornerRadius(4),
                    title: kind.title, detail: kind.example)
            }
            row(swatch: Text("k").foregroundColor(.gray.opacity(0.55)) + Text("nife"),
                title: "Немые буквы", detail: "бледные — не читаются: knife, write, light")
            row(swatch: Text("one").underline(pattern: .dot, color: PhonicsKind.exceptionColor),
                title: "Исключение", detail: "читается не по правилу; красная подсветка — где именно")
            Text("Нажмите на слово — карточка покажет, как его читать, и объяснит каждое сочетание.")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private func row<Swatch: View>(swatch: Swatch, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            swatch
                .scaledFont(size: 16, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
                .frame(minWidth: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(.brandDark)
                Text(detail)
                    .scaledFont(size: 12)
                    .foregroundColor(.gray)
            }
        }
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

    @State private var reading: WordReading?
    @State private var topic: CommunityTopic?

    var body: some View {
        Group {
            if let reading {
                content(reading)
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
    }

    private func content(_ reading: WordReading) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

            notes(reading)

            if reading.isGuess {
                Text("Слова нет в словаре произношения — разбор по общим правилам, звучание может отличаться. Послушайте озвучку.")
                    .scaledFont(size: 12)
                    .foregroundColor(.gray)
            }

            topicLinks(reading)
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

    /// Правила для особых сочетаний и пояснения к слову целиком
    private func notes(_ reading: WordReading) -> some View {
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
            ForEach(reading.notes, id: \.self) { note in
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
