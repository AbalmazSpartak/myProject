import SwiftUI
import Observation

/// Найденное поиском место в открытой главе: абзац и слово в нём (UTF-16, как NSRange).
/// Подсвечивается несколько секунд; jump растёт при каждом переходе — по нему открытая глава прокручивается или листается к месту
@MainActor
@Observable
final class ReaderMark {
    private(set) var paragraph: Int?
    private(set) var range: NSRange?
    private(set) var jump = 0
    @ObservationIgnored private var clearing: Task<Void, Never>?

    /// Не жёлтый, как у чтения вслух, и не цвета правил чтения — чтобы не путать
    static let color = Color.pink.opacity(0.4)

    func show(paragraph: Int, range: NSRange) {
        self.paragraph = paragraph
        self.range = range
        jump += 1
        clearing?.cancel()
        clearing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.clear()
        }
    }

    func clear() {
        clearing?.cancel()
        paragraph = nil
        range = nil
    }
}

/// Совпадение в книге: глава, абзац, где слово, и кусок текста вокруг для списка
nonisolated struct BookSearchResult: Identifiable, Sendable {
    let id: Int
    let chapter: Int
    let paragraph: Int
    let range: NSRange
    let snippet: AttributedString
}

/// Поиск слова или фразы по тексту книги: без учёта регистра, только целые слова (по «cat» не найдётся «catch»)
nonisolated enum BookSearch {
    /// Больше списку не нужно: такое слово проще искать точнее
    static let limit = 500

    static func search(_ query: String, in chapters: [BookChapter]) -> [BookSearchResult] {
        let trimmed = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard trimmed.count >= 2 else { return [] }
        // Между словами фразы — любые пробелы и переносы
        let words = trimmed.split(whereSeparator: \.isWhitespace).map { NSRegularExpression.escapedPattern(for: String($0)) }
        let pattern = "(?<![\\p{L}\\p{N}])" + words.joined(separator: "\\s+") + "(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        var results: [BookSearchResult] = []
        for (chapterIndex, chapter) in chapters.enumerated() {
            for (paragraphIndex, paragraph) in chapter.paragraphs.enumerated() {
                let text = normalized(paragraph)
                for match in regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) {
                    results.append(BookSearchResult(id: results.count, chapter: chapterIndex, paragraph: paragraphIndex,
                                                    range: match.range, snippet: snippet(paragraph, around: match.range)))
                    if results.count >= limit { return results }
                }
            }
        }
        return results
    }

    /// Апостроф ’ как ', ё как е — замена символа на символ, места совпадений в тексте не сдвигаются
    private static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "Ё", with: "Е")
    }

    /// Кусок абзаца вокруг совпадения, совпадение — жирным
    private static func snippet(_ text: String, around range: NSRange) -> AttributedString {
        let ns = text as NSString
        let start = max(0, range.location - 50)
        let end = min(ns.length, NSMaxRange(range) + 80)
        var before = ns.substring(with: NSRange(location: start, length: range.location - start))
        var after = ns.substring(with: NSRange(location: NSMaxRange(range), length: end - NSMaxRange(range)))
        // Обрезано посреди слова — начинаем и заканчиваем на целых словах
        if start > 0 { before = "…" + before.drop { !$0.isWhitespace }.drop(while: \.isWhitespace) }
        if end < ns.length { after = String(after.reversed().drop { !$0.isWhitespace }.reversed()) + "…" }
        var found = AttributedString(ns.substring(with: range))
        found.font = .subheadline.bold()
        return AttributedString(before) + found + AttributedString(after)
    }
}

/// Шторка «Поиск по книге»: совпадения по главам, нажатие — переход к месту в читалке
struct BookSearchView: View {
    let chapters: [BookChapter]
    @Binding var query: String
    let onSelect: (BookSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var results: [BookSearchResult] = []
    @State private var searchedQuery = ""
    @FocusState private var isFocused: Bool

    private struct ChapterGroup: Identifiable {
        let chapter: Int
        let items: [BookSearchResult]
        var id: Int { chapter }
    }

    private var groups: [ChapterGroup] {
        Dictionary(grouping: results, by: \.chapter)
            .map { ChapterGroup(chapter: $0.key, items: $0.value) }
            .sorted { $0.chapter < $1.chapter }
    }

    var body: some View {
        NavigationStack {
            List {
                if !results.isEmpty {
                    Text(results.count >= BookSearch.limit
                         ? "Показаны первые \(BookSearch.limit) совпадений"
                         : "Найдено: \(results.count)")
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .listRowBackground(Color.clear)
                }
                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { result in
                            Button {
                                onSelect(result)
                                dismiss()
                            } label: {
                                Text(result.snippet)
                                    .font(.subheadline)
                                    .foregroundColor(.brandDark)
                                    .lineLimit(3)
                            }
                        }
                    } header: {
                        Text("\(chapterTitle(group.chapter)) — \(group.items.count)")
                            .textCase(nil)
                    }
                    .listRowBackground(Color.cardBackground)
                }
            }
            .brandListBackground()
            .overlay {
                if results.isEmpty, searchedQuery.count >= 2 {
                    ContentUnavailableView.search(text: searchedQuery)
                } else if results.isEmpty {
                    ContentUnavailableView("Поиск по книге", systemImage: "magnifyingglass",
                                           description: Text("Слово или фраза — найдутся все места в книге, без учёта регистра."))
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Слово или фраза")
            .searchFocused($isFocused)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationTitle("Поиск по книге")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .onAppear { if query.isEmpty { isFocused = true } }
            // Ищем, когда перестали печатать; книга — в фоне, экран не тормозит
            .task(id: query) {
                if !searchedQuery.isEmpty || !results.isEmpty {
                    try? await Task.sleep(for: .milliseconds(250))
                }
                guard !Task.isCancelled else { return }
                let text = query, chapters = chapters
                let found = await Task.detached(priority: .userInitiated) { BookSearch.search(text, in: chapters) }.value
                guard !Task.isCancelled else { return }
                results = found
                searchedQuery = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private func chapterTitle(_ index: Int) -> String {
        let title = chapters.indices.contains(index) ? chapters[index].title.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return title.isEmpty ? "Глава \(index + 1)" : title
    }
}
