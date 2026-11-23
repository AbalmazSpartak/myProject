import SwiftUI

/// Имя или название из книги — герой, место: сколько раз встречается и где впервые
nonisolated struct BookName: Identifiable, Sendable {
    struct Mention: Sendable {
        let chapter: Int
        let paragraph: Int
        let range: NSRange
    }

    let id: Int
    let name: String
    /// Номера абзацев с начала книги, по возрастанию, — как book.position
    let positions: [Int]
    let first: Mention
}

/// «Герои и места»: имена с большой буквы, которые встречаются в тексте не случайно.
/// Без ИИ: кто это — герой или город — программа не знает, зато видно, сколько раз имя встречается и где оно впервые
nonisolated enum BookNames {
    private static let minimum = 3
    private static let limit = 80
    /// Названия дней и месяцев, обращения — с большой буквы, но не имена
    private static let skipped: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
        "mr", "mrs", "ms", "miss", "sir", "madam", "dr", "chapter", "contents", "diary", "journal", "letter", "god", "lord",
    ]
    private static let titles = "Mr|Mrs|Ms|Dr|St|Mme|Mlle"

    private struct Entry {
        var words: [String]
        var positions: [Int] = []
        var first: BookName.Mention?
        /// Упоминания не в начале предложения: там слово с большой буквы может быть просто началом фразы
        var inside = 0
    }

    static func find(in chapters: [BookChapter]) -> [BookName] {
        let word = "\\p{Lu}\\p{Ll}+(?:-\\p{Lu}\\p{Ll}+)?"
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}'’])(?:(?:\(titles))\\. )?\(word)(?: \(word)){0,2}(?![\\p{L}\\p{N}])"),
              let lowerRegex = try? NSRegularExpression(pattern: "\\p{Ll}+") else { return [] }

        // Сколько раз слово встречается с маленькой буквы: «the», «count» — обычные слова, а не имена
        var lower: [String: Int] = [:]
        for chapter in chapters {
            for paragraph in chapter.paragraphs {
                let ns = paragraph as NSString
                for match in lowerRegex.matches(in: paragraph, range: NSRange(location: 0, length: ns.length)) {
                    // Только слова целиком: «ing» из «Harker’s» и подобное не считаем
                    let start = match.range.location
                    if start > 0, let before = Unicode.Scalar(ns.character(at: start - 1)), CharacterSet.letters.contains(before) { continue }
                    lower[ns.substring(with: match.range), default: 0] += 1
                }
            }
        }

        var entries: [String: Entry] = [:]
        var offset = 0
        for (chapterIndex, chapter) in chapters.enumerated() {
            for (paragraphIndex, paragraph) in chapter.paragraphs.enumerated() {
                let ns = paragraph as NSString
                for match in regex.matches(in: paragraph, range: NSRange(location: 0, length: ns.length)) {
                    var range = match.range
                    var words = ns.substring(with: range).components(separatedBy: " ")
                    // Обычные слова в начале («The Count», «Then Mina») — не часть имени
                    while let head = words.first, !isTitle(head), (lower[head.lowercased()] ?? 0) >= minimum {
                        range = NSRange(location: range.location + head.utf16.count + 1, length: range.length - head.utf16.count - 1)
                        words.removeFirst()
                    }
                    guard !words.isEmpty, !(words.count == 1 && skipped.contains(words[0].lowercased())) else { continue }
                    let key = words.joined(separator: " ")
                    let isSingle = words.count == 1
                    // Одно слово: если с маленькой буквы оно встречается часто — это не имя
                    if isSingle, (lower[words[0].lowercased()] ?? 0) * 3 > minimum { continue }
                    var entry = entries[key] ?? Entry(words: words)
                    entry.positions.append(offset + paragraphIndex)
                    if entry.first == nil { entry.first = .init(chapter: chapterIndex, paragraph: paragraphIndex, range: range) }
                    if !startsSentence(ns, at: range.location) { entry.inside += 1 }
                    entries[key] = entry
                }
            }
            offset += chapter.paragraphs.count
        }

        // Имя, которое встретилось только в начале предложений, — скорее всего обычное слово
        var kept = entries.filter { $0.value.words.count > 1 ? $0.value.positions.count >= minimum : $0.value.inside >= minimum }
        merge(&kept)
        let result = kept.values.compactMap { entry -> BookName? in
            guard let first = entry.first else { return nil }
            return BookName(id: 0, name: entry.words.joined(separator: " "), positions: entry.positions.sorted(), first: first)
        }
        .sorted { $0.positions.count > $1.positions.count }
        .prefix(limit)
        return result.enumerated().map { BookName(id: $0.offset, name: $0.element.name, positions: $0.element.positions, first: $0.element.first) }
    }

    private static func isTitle(_ word: String) -> Bool {
        titles.split(separator: "|").contains { word.hasPrefix($0 + ".") }
    }

    /// «Harker» → к «Jonathan Harker», если такое имя единственное
    private static func merge(_ entries: inout [String: Entry]) {
        let singles = entries.filter { $0.value.words.count == 1 }
        for (key, single) in singles {
            let containing = entries.filter { $0.value.words.count > 1 && $0.value.words.contains(single.words[0]) }
            let ranked = containing.sorted { $0.value.positions.count > $1.value.positions.count }
            guard let best = ranked.first,
                  ranked.count == 1 || best.value.positions.count >= (ranked[1].value.positions.count) * 2 else { continue }
            var target = best.value
            target.positions += single.positions
            if let first = single.first, let current = target.first, first.chapter < current.chapter
                || (first.chapter == current.chapter && first.paragraph < current.paragraph) {
                target.first = first
            }
            entries[best.key] = target
            entries[key] = nil
        }
    }

    /// Перед словом — начало абзаца, конец предложения или открывающая кавычка
    private static func startsSentence(_ text: NSString, at location: Int) -> Bool {
        var index = location - 1
        while index >= 0 {
            let character = Character(Unicode.Scalar(text.character(at: index)) ?? " ")
            if character == " " || character == "\u{00A0}" { index -= 1; continue }
            return ".!?:—–“”\"‘«(…".contains(character)
        }
        return true
    }
}

/// Шторка «Герои и места»: имена, которые встретились до места, где вы остановились, — без спойлеров
struct BookNamesView: View {
    let chapters: [BookChapter]
    /// Абзац с начала книги: что дальше, не показываем
    let position: Int
    @Binding var names: [BookName]?
    let onSelect: (BookName.Mention) -> Void
    let onSearch: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var visible: [(name: BookName, count: Int)] {
        (names ?? []).compactMap { name in
            let count = name.positions.prefix { $0 <= position }.count
            return count >= 1 ? (name, count) : nil
        }
        .sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            List {
                if !visible.isEmpty {
                    Text("Имена с большой буквы, которые встречаются в прочитанном — герои и места. Кто есть кто, программа не определяет. То, что дальше места, где вы остановились, не показывается.")
                        .scaledFont(size: 13)
                        .foregroundColor(Color.brandMuted)
                        .listRowBackground(Color.clear)
                }
                ForEach(visible, id: \.name.id) { item in
                    HStack {
                        Button {
                            onSelect(item.name.first)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name.name)
                                    .scaledFont(size: 17, weight: .semibold)
                                    .foregroundColor(.brandDark)
                                Text("Упоминаний: \(item.count) · впервые: \(chapterTitle(item.name.first.chapter))")
                                    .scaledFont(size: 13)
                                    .foregroundColor(Color.brandMuted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            onSearch(item.name.name)
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.brandTint)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Все места, где встречается «\(item.name.name)»")
                    }
                    .lxRowPlate()
                }
            }
            .brandListBackground()
            .overlay {
                if names == nil {
                    ProgressView("Ищу имена…")
                } else if visible.isEmpty {
                    ContentUnavailableView("Пока нет имён", systemImage: "person.2",
                                           description: Text("Имена появятся по мере чтения."))
                }
            }
            .navigationTitle("Герои и места")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .task {
                guard names == nil else { return }
                let chapters = chapters
                names = await Task.detached(priority: .userInitiated) { BookNames.find(in: chapters) }.value
            }
        }
    }

    private func chapterTitle(_ index: Int) -> String {
        let title = chapters.indices.contains(index) ? chapters[index].title.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return title.isEmpty ? "глава \(index + 1)" : title
    }
}
