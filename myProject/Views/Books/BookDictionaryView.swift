import SwiftUI
import SwiftData

/// «Словарь из книги»: как слова из файла — до 5000 самых частых, частые учатся первыми.
/// Словарь — тот же, что у слов, добавленных нажатием («В словарь книги»)
struct BookDictionaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let book: Book

    @State private var candidates: [ScanCandidate]?
    @State private var isEmpty = false

    var body: some View {
        NavigationStack {
            Group {
                if let candidates {
                    ScanResultsView(candidates: candidates, fileName: book.title) { _ in dismiss() }
                } else if isEmpty {
                    ContentUnavailableView("Нет слов", systemImage: "text.book.closed",
                                           description: Text("В книге не нашлось английских слов для изучения."))
                } else {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Ищу самые частые слова книги…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brandBackground)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .task { await analyze() }
    }

    private func analyze() async {
        guard candidates == nil else { return }
        let chapters = book.chapters
        let limit = TextScanView.maxFileWords
        let found = await Task.detached(priority: .userInitiated) { () -> [ExtractedWord] in
            let text = chapters.flatMap(\.paragraphs).joined(separator: "\n")
            let limited = String(text.prefix(FileTextReader.maxCharacters))
            return Array(TextWordExtractor.extract(from: limited).sorted { $0.count > $1.count }.prefix(limit))
        }.value
        if found.isEmpty {
            isEmpty = true
        } else {
            candidates = ScanMatcher.match(found, in: modelContext.fetchAllWords())
        }
    }
}
