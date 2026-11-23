import SwiftUI

/// «Мои книги» по варианту C холста «LexiStream: Библиотека»:
/// «Продолжить чтение» (последняя книга с цитатой-ориентиром и кнопками), полки «Читаю», «Новые» и «Все книги»
struct LibraryHomeView<Search: View>: View {
    /// Все книги в порядке, выбранном в чипе сортировки
    let books: [Book]
    /// Найденное по запросу
    let results: [Book]
    let isSearching: Bool
    let query: String
    @Binding var sort: BookSort
    let search: Search
    let onRead: (Book) -> Void
    let onListen: (Book) -> Void
    let onAdd: () -> Void
    let onDelete: (Book) -> Void
    let onSearchAudio: () -> Void

    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue
    /// Начало абзаца, на котором остановились в книге из «Продолжить чтение»
    @State private var quote: String?

    private var isSketch: Bool { design == AppDesign.sketch.rawValue }

    // MARK: - Какие книги на каких полках

    /// Последняя открытая книга; если ничего не открывали — последняя добавленная
    private var hero: Book? {
        books.filter { $0.lastOpenedAt != nil }.max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
            ?? books.max { $0.addedAt < $1.addedAt }
    }

    private var reading: [Book] {
        books.filter { $0.id != hero?.id && $0.lastOpenedAt != nil && $0.progress > 0 && $0.progress < 0.98 }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    private var fresh: [Book] {
        books.filter { $0.id != hero?.id && $0.lastOpenedAt == nil }.sorted { $0.addedAt > $1.addedAt }
    }

    // MARK: - Экран

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if !books.isEmpty { search }
                if isSearching {
                    searchResults
                } else if books.isEmpty {
                    emptyState
                } else {
                    if let hero { heroCard(hero) }
                    if !reading.isEmpty { shelf("Читаю", reading) }
                    freshShelf
                    allBooks
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Продолжить чтение

    private func heroCard(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                cover(book, shadow: NewStyle.yellow, offset: 5)
                    .frame(width: 108)
                    .padding(.trailing, 5)
                    .padding(.bottom, 5)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Продолжить чтение")
                        .scaledFont(size: 13, weight: .semibold, design: isSketch ? .rounded : .default)
                        .tracking(0.4)
                        .foregroundColor(Color.brandMuted)
                    Text(book.title)
                        .scaledFont(size: 21, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .scaledFont(size: 15, design: isSketch ? .rounded : .default)
                            .foregroundColor(Color.brandMuted)
                            .lineLimit(1)
                    }
                    if let quote {
                        Text("«…\(quote)…»")
                            .scaledFont(size: 14, design: .serif)
                            .italic()
                            .foregroundColor(.brandDark.opacity(0.8))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 4)
                    progressRow(book)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                Button { onRead(book) } label: { LibraryButton(title: "Читать", systemImage: "book", isMain: true) }
                    .buttonStyle(.plain)
                Button { onListen(book) } label: { LibraryButton(title: "Слушать", systemImage: "headphones") }
                    .buttonStyle(.plain)
            }
        }
        .padding(16)
        .libraryCard(isSketch)
        .padding(.trailing, 4)
        .task(id: book.id) { quote = await Self.quote(of: book) }
    }

    /// Полоса прогресса и подпись: «Не начата», процент или «Прочитана» — спокойно, без «осталось N»
    private func progressRow(_ book: Book) -> some View {
        HStack(spacing: 10) {
            if isSketch {
                SketchProgress(value: book.progress)
            } else {
                ProgressView(value: book.progress).tint(Color.brandTint)
            }
            Text(Self.progressLabel(book))
                .scaledFont(size: 13, weight: .medium)
                .foregroundColor(Color.brandMuted)
                .fixedSize()
        }
    }

    static func progressLabel(_ book: Book) -> String {
        if book.progress <= 0 { return "Не начата" }
        if book.progress >= 0.98 { return "Прочитана" }
        return "\(Int(book.progress * 100))%"
    }

    /// Первые слова абзаца, на котором остановились (у непрочитанной книги цитаты нет)
    private static func quote(of book: Book) async -> String? {
        let data = book.chaptersData, position = book.position
        guard position > 0 else { return nil }
        return await Task.detached(priority: .utility) {
            let chapters = (try? JSONDecoder().decode([BookChapter].self, from: data)) ?? []
            var index = 0
            for chapter in chapters {
                if position < index + chapter.paragraphs.count {
                    let words = chapter.paragraphs[position - index].split(whereSeparator: \.isWhitespace)
                    guard words.count >= 4 else { return nil }
                    var text = words.prefix(9).joined(separator: " ")
                    while let last = text.last, ".,;:!?…—-«»\"".contains(last) { text.removeLast() }
                    return text
                }
                index += chapter.paragraphs.count
            }
            return nil
        }.value
    }

    // MARK: - Полки

    private func shelf(_ title: String, _ items: [Book]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(items) { shelfBook($0, width: 104) }
                }
                .padding(.bottom, 6)
                .padding(.trailing, 6)
            }
            .scrollClipDisabled()
        }
    }

    /// «Новые»: первой всегда карточка «Добавить книгу»
    private var freshShelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Новые")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ShelfAddCard(isSketch: isSketch, action: onAdd)
                    ForEach(fresh) { shelfBook($0, width: 104) }
                }
                .padding(.bottom, 6)
                .padding(.trailing, 6)
            }
            .scrollClipDisabled()
        }
    }

    private var allBooks: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Все книги")
                Spacer()
                Menu {
                    Picker("Порядок", selection: $sort) {
                        ForEach(BookSort.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sort.title)
                        Image(systemName: "chevron.down")
                    }
                    .scaledFont(size: 14, weight: .medium, design: isSketch ? .rounded : .default)
                    .foregroundColor(.brandDark)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                }
                .accessibilityLabel("Порядок книг: \(sort.title)")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 130), spacing: 18, alignment: .top)], alignment: .leading, spacing: 22) {
                ForEach(books) { shelfBook($0, width: nil) }
            }
        }
    }

    private func shelfBook(_ book: Book, width: CGFloat?) -> some View {
        Button { onRead(book) } label: {
            VStack(alignment: .leading, spacing: 6) {
                cover(book, shadow: NewStyle.yellow, offset: 4)
                    .overlay(alignment: .bottomTrailing) {
                        if Self.hasAudio(book) {
                            Image(systemName: "headphones")
                                .scaledFont(size: 12, weight: .semibold)
                                .foregroundColor(isSketch ? NewStyle.onYellow : .white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(isSketch ? NewStyle.yellow : Color.brandTint))
                                .overlay(Circle().stroke(isSketch ? NewStyle.outline : .clear, lineWidth: 1.2))
                                .padding(5)
                                .accessibilityLabel("Есть озвучка")
                        }
                    }
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
                Text(book.title)
                    .scaledFont(size: 14, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Self.progressLabel(book))
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Color.brandMuted)
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onListen(book) } label: { Label("Слушать", systemImage: "headphones") }
            Button(role: .destructive) { onDelete(book) } label: { Label("Удалить книгу", systemImage: "trash") }
        }
        .accessibilityLabel("\(book.title). \(Self.progressLabel(book))")
    }

    /// Есть ли у книги озвучка на устройстве: живой голос или записанная нейроголосом
    private static func hasAudio(_ book: Book) -> Bool {
        FileManager.default.fileExists(atPath: LiveAudioStore.folder(book.id).path) || AudiobookStore.size(book: book.id) > 0
    }

    // MARK: - Поиск

    @ViewBuilder
    private var searchResults: some View {
        if results.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(Color.brandMuted)
                Text("Ничего не найдено")
                    .scaledFont(size: 20, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text("В ваших книгах нет «\(query)». Проверьте написание: ищем по названию и автору.")
                    .scaledFont(size: 15)
                    .foregroundColor(Color.brandMuted)
                    .multilineTextAlignment(.center)
                Button(action: onSearchAudio) { LibraryButton(title: "Поискать в аудиокнигах", systemImage: "headphones") }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Мои книги · найдено \(results.count)")
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundColor(Color.brandMuted)
                ForEach(results) { resultRow($0) }
            }
        }
    }

    private func resultRow(_ book: Book) -> some View {
        HStack(alignment: .top, spacing: 14) {
            cover(book, shadow: NewStyle.yellow, offset: 4)
                .frame(width: 64)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .scaledFont(size: 17, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .scaledFont(size: 14, design: isSketch ? .rounded : .default)
                        .foregroundColor(Color.brandMuted)
                        .lineLimit(1)
                }
                Text(Self.progressLabel(book))
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(Color.brandMuted)
                HStack(spacing: 10) {
                    Button { onRead(book) } label: { LibraryButton(title: "Читать", isMain: true, compact: true) }
                        .buttonStyle(.plain)
                    Button { onListen(book) } label: { LibraryButton(title: "Слушать", compact: true) }
                        .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .libraryCard(isSketch)
        .padding(.trailing, 4)
        .contextMenu {
            Button(role: .destructive) { onDelete(book) } label: { Label("Удалить книгу", systemImage: "trash") }
        }
    }

    // MARK: - Пустая библиотека

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("Продолжить чтение")
                .scaledFont(size: 13, weight: .semibold, design: isSketch ? .rounded : .default)
                .tracking(0.4)
                .foregroundColor(Color.brandMuted)
            Text("Здесь будет ваша книга")
                .scaledFont(size: 26, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
                .multilineTextAlignment(.center)
            Text("Откройте любую книгу, и она будет ждать здесь, на том же месте. Никакой спешки.")
                .scaledFont(size: 16)
                .foregroundColor(Color.brandMuted)
                .multilineTextAlignment(.center)
            Button(action: onAdd) { LibraryButton(title: "Добавить книгу", systemImage: "plus", isMain: true) }
                .buttonStyle(.plain)
                .padding(.top, 8)
            Text("EPUB, FB2, TXT, PDF")
                .scaledFont(size: 14, design: isSketch ? .rounded : .default)
                .foregroundColor(Color.brandMuted)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .libraryCard(isSketch)
        .padding(.trailing, 4)
        .padding(.top, 20)
    }

    // MARK: - Общее

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .scaledFont(size: 22, weight: .semibold, design: isSketch ? .rounded : .serif)
            .foregroundColor(.brandDark)
    }

    /// Обложка 2:3: в «Скетче» с контуром и цветной тенью, иначе с мягкой тенью
    @ViewBuilder
    private func cover(_ book: Book, shadow: Color, offset: CGFloat) -> some View {
        if isSketch {
            NewCover(book: book, shadow: shadow, offset: offset)
        } else {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay { BookCover(data: book.coverData, title: book.title) }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - Мелкие части

private extension View {
    /// Карточка: в «Скетче» с контуром и голубой тенью, иначе тёплая плашка
    @ViewBuilder
    func libraryCard(_ sketch: Bool) -> some View {
        if sketch {
            newCard(radius: 18, shadow: NewStyle.blue, offset: 4)
        } else {
            background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }
}

/// Кнопка библиотеки: в «Скетче» жёлтая с контуром, иначе заливка выбранного цвета кнопок
private struct LibraryButton: View {
    let title: String
    var systemImage: String?
    var isMain = false
    var compact = false
    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue

    var body: some View {
        if design == AppDesign.sketch.rawValue {
            if compact {
                HStack(spacing: 6) {
                    if let systemImage { Image(systemName: systemImage) }
                    Text(title)
                }
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(isMain ? NewStyle.onYellow : Color.brandDark)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .newCard(radius: 12, fill: isMain ? NewStyle.yellow : Color.cardBackground, shadow: isMain ? NewStyle.yellowShadow : NewStyle.blue, offset: 3)
            } else {
                NewButtonLabel(title: title, systemImage: systemImage, isMain: isMain)
            }
        } else {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .scaledFont(size: compact ? 14 : 16, weight: .semibold)
            .foregroundStyle(isMain ? Color.brandOnButton : Color.brandDark)
            .padding(.horizontal, compact ? 14 : 0)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 44 : 50)
            .background(isMain ? Color.brandButton : Color.brandFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/// Первая карточка полки «Новые»: добавить книгу из «Файлов»
private struct ShelfAddCard: View {
    let isSketch: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .scaledFont(size: 26, weight: .medium)
                            Text("Добавить книгу")
                                .scaledFont(size: 13, weight: .semibold)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(Color.brandTint)
                        .padding(8)
                    }
                    .background(Color.brandTint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSketch ? NewStyle.outline : Color.brandTint.opacity(0.45),
                                          style: StrokeStyle(lineWidth: isSketch ? NewStyle.lineWidth : 1.5, dash: [6, 5]))
                    }
                    .background {
                        if isSketch {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(NewStyle.pastels[1]).offset(x: 4, y: 4)
                        }
                    }
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
                Text("EPUB, FB2, TXT, PDF")
                    .scaledFont(size: 12)
                    .foregroundColor(Color.brandMuted)
                    .lineLimit(2)
                Text("Из «Файлов»")
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundColor(Color.brandMuted)
            }
            .frame(width: 104)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить книгу из «Файлов»")
    }
}
