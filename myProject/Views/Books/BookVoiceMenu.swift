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

    /// nil — LibriVox не ответил (не запоминаем, в следующий раз спросим снова)
    static func recordings(for book: Book) async -> [LibriVox.Audiobook]? {
        guard let id = book.gutenbergID else { return [] }
        if let cached = cache[id] { return cached }
        guard let found = try? await LibriVox.recordings(gutenbergID: id, title: book.title) else { return nil }
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

/// Кнопка «Голос ▾» в плеерах: два голоса — по умолчанию (нейроголос из «Озвучки») и живой (запись LibriVox).
/// Видна всегда; пока запись ищется или её нет — пункт «Живой голос» с пояснением
struct BookVoiceMenu: View {
    let book: Book
    let language: String
    let current: BookVoiceChoice
    let onNeural: (String) -> Void
    let onLive: (LibriVox.Audiobook) -> Void

    private enum LiveState {
        case searching, found([LibriVox.Audiobook]), none, failed
    }

    @State private var live: LiveState = .searching

    /// Нейроголос, выбранный в «Озвучке»
    private var defaultChoice: String { NeuralVoice.shared.bookChoice(language) }

    private var isLive: Bool {
        if case .live = current { return true }
        return false
    }

    var body: some View {
        LXMenu {
            Button { onNeural(defaultChoice) } label: {
                checked("Голос по умолчанию · \(NeuralVoice.shared.bookVoiceTitle(language))", !isLive)
            }
            switch live {
            case .found(let recordings):
                Section("Живой голос") {
                    ForEach(recordings) { audiobook in
                        Button { onLive(audiobook) } label: {
                            checked("\(audiobook.readerText.capitalizedFirst) · \(LibriVox.durationText(audiobook.seconds))",
                                    current == .live(audiobook.id))
                        }
                    }
                }
            case .searching:
                Text("Живой голос — ищу запись…")
            case .none:
                Text(book.gutenbergID == nil ? "Живой голос — только для книг из каталога" : "Живой голос — для этой книги записи нет")
            case .failed:
                Button { Task { await load() } } label: {
                    Label("Живой голос — LibriVox не ответил. Попробовать снова", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isLive ? "person.wave.2" : "waveform")
                Text(isLive ? "Живой голос" : "Голос по умолчанию")
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
        .accessibilityLabel(isLive ? "Голос: живой" : "Голос: по умолчанию")
        .task { await load() }
    }

    @ViewBuilder
    private func checked(_ title: String, _ isOn: Bool) -> some View {
        if isOn { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    /// Все записи книги: выбранная — первой, дальше найденные (сначала те, где читает один человек)
    private func load() async {
        let saved = LiveAudioStore.audiobook(book: book.id)
        func merged(_ found: [LibriVox.Audiobook]) -> [LibriVox.Audiobook] {
            guard let saved else { return found }
            return [saved] + found.filter { $0.id != saved.id }
        }
        if let saved { live = .found([saved]) }
        guard book.gutenbergID != nil else {
            if saved == nil { live = .none }
            return
        }
        if let cached = LiveAudioLookup.cached(gutenbergID: book.gutenbergID) {
            let all = merged(cached)
            live = all.isEmpty ? .none : .found(all)
            return
        }
        if saved == nil { live = .searching }
        guard let found = await LiveAudioLookup.recordings(for: book) else {
            // Выбранная запись есть — её и оставляем, без «не ответил»
            if saved == nil { live = .failed }
            return
        }
        let all = merged(found)
        live = all.isEmpty ? .none : .found(all)
    }
}
