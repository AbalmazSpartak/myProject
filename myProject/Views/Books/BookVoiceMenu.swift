import SwiftUI

/// Какой голос сейчас читает книгу: нейросетевой (выбор как в «Озвучке») или живая запись LibriVox
enum BookVoiceChoice: Equatable {
    case neural(String)
    case live(Int)
}

/// Записи LibriVox для книги: сохранённая и найденные. Поиск в LibriVox медленный — найденное помним, пока приложение открыто
enum LiveAudioLookup {
    private static var cache: [Int: [LibriVox.Audiobook]] = [:]

    static func cached(gutenbergID: Int?) -> [LibriVox.Audiobook]? {
        gutenbergID.flatMap { cache[$0] }
    }

    static func recordings(for book: Book) async -> [LibriVox.Audiobook] {
        guard let id = book.gutenbergID else { return [] }
        if let cached = cache[id] { return cached }
        let found = (try? await LibriVox.recordings(gutenbergID: id, title: book.title)) ?? []
        cache[id] = found
        return found
    }
}

/// Сопоставление глав текста и глав записи: по номеру («CHAPTER II» ↔ «Chapters 01-02»), по названию, иначе по доле книги
nonisolated enum ChapterMatch {
    /// Глава записи для главы текста
    static func section(chapterTitle: String, chapterIndex: Int, chapterCount: Int, sections: [LibriVox.Section]) -> Int? {
        guard !sections.isEmpty else { return nil }
        if let number = chapterNumber(chapterTitle),
           let hit = sections.first(where: { numbers($0.title).contains(number) }) {
            return hit.number
        }
        let name = letters(chapterTitle)
        if name.count >= 6, let hit = sections.first(where: {
            let other = letters($0.title)
            return other.count >= 6 && (name.contains(other) || other.contains(name))
        }) {
            return hit.number
        }
        let share = Double(chapterIndex) / Double(max(chapterCount, 1))
        return sections[min(Int(share * Double(sections.count)), sections.count - 1)].number
    }

    /// Глава текста для главы записи
    static func chapter(section: LibriVox.Section, sectionIndex: Int, sectionCount: Int, titles: [String]) -> Int {
        guard !titles.isEmpty else { return 0 }
        if let first = numbers(section.title).first,
           let hit = titles.firstIndex(where: { chapterNumber($0) == first }) {
            return hit
        }
        let name = letters(section.title)
        if name.count >= 6, let hit = titles.firstIndex(where: {
            let other = letters($0)
            return other.count >= 6 && (other.contains(name) || name.contains(other))
        }) {
            return hit
        }
        let share = Double(sectionIndex) / Double(max(sectionCount, 1))
        return min(Int(share * Double(titles.count)), titles.count - 1)
    }

    /// «CHAPTER XII. …», «Chapter 3» → номер главы
    static func chapterNumber(_ title: String) -> Int? {
        guard let match = title.firstMatch(of: /(?i)chapter\s+([0-9]+|[ivxlc]+)\b/) else { return nil }
        let value = String(match.1)
        return Int(value) ?? roman(value)
    }

    /// «Chapters 01-02» → [1, 2]; «Chapter 07» → [7]
    static func numbers(_ title: String) -> [Int] {
        if let range = title.firstMatch(of: /(\d+)\s*[-–]\s*(\d+)/), let from = Int(range.1), let to = Int(range.2), from <= to {
            return Array(from...to)
        }
        return title.firstMatch(of: /(\d+)/).flatMap { Int($0.1) }.map { [$0] } ?? []
    }

    private static func roman(_ text: String) -> Int? {
        let values: [Character: Int] = ["i": 1, "v": 5, "x": 10, "l": 50, "c": 100]
        var total = 0, previous = 0
        for character in text.lowercased().reversed() {
            guard let value = values[character] else { return nil }
            total += value < previous ? -value : value
            previous = max(previous, value)
        }
        return total > 0 ? total : nil
    }

    private static func letters(_ text: String) -> String {
        // Без слова «chapter» и номеров: «CHAPTER I. Down the Rabbit-Hole» → «downtherabbithole»
        let cleaned = text.lowercased().replacing(/chapters?\s+[0-9ivxlc]+/, with: "")
        return String(cleaned.unicodeScalars.filter { CharacterSet.letters.contains($0) }.map(Character.init))
    }
}

extension NeuralVoice {
    /// Нейросетевые голоса, которыми можно читать книгу на этом языке прямо сейчас (скачанные), — как в «Озвучке»
    func bookChoices(language: String) -> [(id: String, title: String)] {
        let code = Self.languageCode(language)
        var result: [(id: String, title: String)] = []
        if code == "en", phase == .ready || KokoroML.shared.isReady {
            result += Self.voices.map { ("kokoro:\($0.id)", "Kokoro · \($0.title)") }
        }
        if let piper = Self.installedPiper(language: code) {
            result.append(("piper:\(piper.rawValue)", "Piper · \(piper.summary)"))
        }
        result.append(("system", "Системный голос"))
        return result
    }
}

/// Кнопка «Голос ▾» в плеерах: нейроголоса и живые записи LibriVox этой книги — переключиться одним нажатием
struct BookVoiceMenu: View {
    let book: Book
    let language: String
    let current: BookVoiceChoice
    let onNeural: (String) -> Void
    let onLive: (LibriVox.Audiobook) -> Void

    @State private var recordings: [LibriVox.Audiobook] = []
    @State private var saved: LibriVox.Audiobook?
    @State private var isSearching = false

    private var neural: [(id: String, title: String)] { NeuralVoice.shared.bookChoices(language: language) }

    /// Сохранённая запись — первой, потом остальные найденные
    private var live: [LibriVox.Audiobook] {
        guard let saved else { return recordings }
        return [saved] + recordings.filter { $0.id != saved.id }
    }

    var body: some View {
        Menu {
            Section("Нейросетевой голос") {
                ForEach(neural, id: \.id) { choice in
                    Button { onNeural(choice.id) } label: {
                        checked(choice.title, current == .neural(choice.id))
                    }
                }
            }
            if !live.isEmpty || isSearching {
                Section("Живой голос · LibriVox") {
                    ForEach(live) { audiobook in
                        Button { onLive(audiobook) } label: {
                            checked("\(audiobook.readerText.capitalizedFirst) · \(LibriVox.durationText(audiobook.seconds))",
                                    current == .live(audiobook.id))
                        }
                    }
                    if isSearching { Text("Ищу записи…") }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLive ? "person.wave.2" : "waveform")
                Text(currentTitle)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .scaledFont(size: 14, weight: .medium)
            .foregroundStyle(Color.brandTint)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.brandFill))
        }
        .accessibilityLabel("Голос: \(currentTitle)")
        .task { await load() }
    }

    private var isLive: Bool {
        if case .live = current { return true }
        return false
    }

    private var currentTitle: String {
        switch current {
        case .neural(let id):
            return neural.first { $0.id == id }?.title.components(separatedBy: " · ").prefix(2).joined(separator: " · ")
                ?? NeuralVoice.shared.bookVoiceTitle(language)
        case .live(let id):
            let reader = live.first { $0.id == id }?.readers.first
            return reader.map { "Живой голос · \($0)" } ?? "Живой голос"
        }
    }

    @ViewBuilder
    private func checked(_ title: String, _ isOn: Bool) -> some View {
        if isOn { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private func load() async {
        saved = LiveAudioStore.audiobook(book: book.id)
        if let cached = LiveAudioLookup.cached(gutenbergID: book.gutenbergID) {
            recordings = cached
            return
        }
        guard book.gutenbergID != nil else { return }
        isSearching = true
        recordings = await LiveAudioLookup.recordings(for: book)
        isSearching = false
    }
}
