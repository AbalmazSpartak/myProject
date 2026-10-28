import SwiftUI

/// Закладка в книге: абзац от начала книги, когда поставлена и заметка к ней
nonisolated struct BookBookmark: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var paragraph: Int
    var created = Date()
    var note = ""
}

extension Book {
    /// Закладки по порядку в книге
    var bookmarks: [BookBookmark] {
        get { bookmarksData.flatMap { try? JSONDecoder().decode([BookBookmark].self, from: $0) } ?? [] }
        set { bookmarksData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue.sorted { $0.paragraph < $1.paragraph }) }
    }
}

/// Ленточка закладки в углу страницы
struct BookmarkRibbon: View {
    var body: some View {
        Image(systemName: "bookmark.fill")
            .font(.system(size: 22))
            .foregroundStyle(Color.red.opacity(0.75))
            .offset(y: -4)
            .accessibilityLabel("Закладка")
    }
}

/// «Закладки»: глава, начало абзаца, заметка и дата; нажатие — к месту, свайп — удалить
struct BookBookmarksView: View {
    let bookmarks: [BookBookmark]
    let chapters: [BookChapter]
    let chapterStarts: [Int]
    let onSelect: (BookBookmark) -> Void
    let onDelete: (BookBookmark) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(bookmarks) { bookmark in
                    Button {
                        onSelect(bookmark)
                        dismiss()
                    } label: {
                        row(bookmark)
                    }
                    .listRowBackground(Color.cardBackground)
                    .swipeActions {
                        Button(role: .destructive) { onDelete(bookmark) } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .brandListBackground()
            .overlay {
                if bookmarks.isEmpty {
                    ContentUnavailableView("Закладок нет", systemImage: "bookmark",
                                           description: Text("«…» → «Добавить закладку» — отметить место, которое открыто сейчас."))
                }
            }
            .navigationTitle("Закладки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func row(_ bookmark: BookBookmark) -> some View {
        let place = position(of: bookmark.paragraph)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.red.opacity(0.8))
                Text(place.chapter)
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                Spacer()
                Text(bookmark.created.formatted(date: .abbreviated, time: .omitted))
                    .scaledFont(size: 12)
                    .foregroundColor(.gray)
            }
            if !bookmark.note.isEmpty {
                Text(bookmark.note)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(.brandDark)
            }
            Text(place.text)
                .scaledFont(size: 15, design: .serif)
                .foregroundColor(.brandDark.opacity(0.8))
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    /// Название главы и начало абзаца закладки
    private func position(of paragraph: Int) -> (chapter: String, text: String) {
        guard let index = chapterStarts.lastIndex(where: { $0 <= paragraph }), chapters.indices.contains(index) else { return ("", "") }
        let local = paragraph - chapterStarts[index]
        let paragraphs = chapters[index].paragraphs
        return (chapters[index].title, paragraphs.indices.contains(local) ? paragraphs[local] : "")
    }
}
