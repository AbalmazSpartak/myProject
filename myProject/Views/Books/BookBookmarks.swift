import SwiftUI

/// Ленточка закладки в углу страницы
struct BookmarkRibbon: View {
    var body: some View {
        Image(systemName: "bookmark.fill")
            .font(.system(size: 22))
            .foregroundStyle(Color.brandTint)
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
            Group {
                if AppDesign.isSketch { sketchList } else { classicList }
            }
            .overlay {
                if bookmarks.isEmpty {
                    ContentUnavailableView("Закладок нет", systemImage: "bookmark",
                                           description: Text("«Меню» → «Закладка здесь» — отметить место, которое открыто сейчас."))
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

    /// «Скетч»: закладки одной группой с контуром, удаление — долгим нажатием
    private var sketchList: some View {
        ScrollView {
            if !bookmarks.isEmpty {
                LXGroup {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            onSelect(bookmark)
                            dismiss()
                        } label: {
                            row(bookmark)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { onDelete(bookmark) } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }

    private var classicList: some View {
            List {
                ForEach(bookmarks) { bookmark in
                    Button {
                        onSelect(bookmark)
                        dismiss()
                    } label: {
                        row(bookmark)
                    }
                    .lxRowPlate()
                    .swipeActions {
                        Button(role: .destructive) { onDelete(bookmark) } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .brandListBackground()
    }

    private func row(_ bookmark: BookBookmark) -> some View {
        let place = position(of: bookmark.paragraph)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bookmark")
                    .foregroundColor(Color.brandTint)
                Text(place.chapter)
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(Color.brandMuted)
                    .lineLimit(1)
                Spacer()
                Text(bookmark.created.formatted(date: .abbreviated, time: .omitted))
                    .scaledFont(size: 12)
                    .foregroundColor(Color.brandMuted)
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
        return (ChapterNumbering.cleanTitle(chapters[index].title) ?? chapters[index].title, paragraphs.indices.contains(local) ? paragraphs[local] : "")
    }
}
