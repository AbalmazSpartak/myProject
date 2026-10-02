import SwiftUI
import SwiftData

/// «Обзор» — главный экран в стиле журнала: слово дня, подборки, ленты тренировок и игр
struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    @Query(sort: \Category.name) private var categories: [Category]
    @AppStorage(MainMenuLayout.storageKey) private var menuLayout = MainMenuLayout.standard

    @State private var wordsOfDay: [Word] = []

    let open: (ActiveScreen) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if !wordsOfDay.isEmpty {
                    WordOfDayCarousel(words: wordsOfDay)
                }

                collectionsRibbon

                // Ленты разделов — по настройке «Главное меню»: каждая группа — своя лента
                ForEach(ribbons, id: \.title) { ribbon in
                    sectionRibbon(ribbon)
                }

                moviesRibbon
            }
            .padding(.vertical, 12)
            .padding(.bottom, 30)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            if wordsOfDay.isEmpty {
                wordsOfDay = WordOfDay.recent(days: 7, from: modelContext.fetchAllWords())
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack {
            Text("WORDLEARNER")
                .scaledFont(size: 26, weight: .heavy)
                .foregroundColor(.brandDark)
            Spacer()
            Button { open(.profile) } label: {
                Image(systemName: "person.crop.circle")
                    .scaledFont(size: 26)
                    .foregroundColor(.brandDark)
            }
            .accessibilityLabel("Мой профиль")
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Подборки

    private var collectionsRibbon: some View {
        Ribbon(title: "Ваши подборки", onTitleTap: { open(.dictionary) }) {
            ForEach(lists) { list in
                CollectionCard(name: list.name, words: list.words) { open(.collection(.list(list))) }
            }
            ForEach(categories) { category in
                CollectionCard(name: category.name, words: category.words) { open(.collection(.category(category))) }
            }
        }
    }

    // MARK: - Разделы

    private struct SectionRibbon {
        let title: String
        let sections: [MenuSection]
    }

    /// Группы — отдельными лентами по порядку меню; разделы вне групп — одной лентой «Разделы»
    /// на месте первого из них
    private var ribbons: [SectionRibbon] {
        var result: [SectionRibbon] = []
        var loose: [MenuSection] = []
        var looseIndex: Int?
        for item in menuLayout.visibleItems {
            switch item {
            case .group(let id):
                guard let group = menuLayout.groups[id] else { continue }
                result.append(SectionRibbon(title: group.name, sections: menuLayout.visibleSections(in: id)))
            case .section(let section):
                if looseIndex == nil { looseIndex = result.count }
                loose.append(section)
            }
        }
        if let looseIndex {
            result.insert(SectionRibbon(title: "Разделы", sections: loose), at: looseIndex)
        }
        return result
    }

    private func sectionRibbon(_ ribbon: SectionRibbon) -> some View {
        Ribbon(title: ribbon.title) {
            ForEach(ribbon.sections, id: \.self) { section in
                TileCard(title: section.title, icon: section.icon, color: section.color) { open(section.screen) }
            }
        }
    }

    // MARK: - Кино (заглушка)

    private static let movieGenres: [(name: String, icon: String, color: Color)] = [
        ("Фэнтези", "sparkles", .purple),
        ("Фантастика", "globe.americas.fill", .indigo),
        ("Комедии", "face.smiling.inverse", .orange),
        ("Драмы", "theatermasks.fill", .red),
        ("Мультфильмы", "film.fill", .teal)
    ]

    private var moviesRibbon: some View {
        let stub = ActiveScreen.stub(title: "Английский по кино", message: "Здесь будет раздел с подборками слов по фильмам")
        return Ribbon(title: "Английский по кино", onTitleTap: { open(stub) }) {
            ForEach(Self.movieGenres, id: \.name) { genre in
                TileCard(title: genre.name, icon: genre.icon, color: genre.color) { open(stub) }
            }
        }
    }
}

// MARK: - Лента

/// Заголовок прописными и горизонтальная лента карточек
private struct Ribbon<Content: View>: View {
    let title: String
    var onTitleTap: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let onTitleTap {
                    Button(action: onTitleTap) {
                        HStack(spacing: 4) {
                            titleText
                            Image(systemName: "chevron.right")
                                .scaledFont(size: 14, weight: .bold)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    titleText
                }
            }
            .foregroundColor(.brandDark)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var titleText: some View {
        Text(title.uppercased())
            .scaledFont(size: 17, weight: .bold)
    }
}

/// Карточка раздела или жанра: цветная плашка с иконкой и подпись
private struct TileCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(0.18))
                    .frame(width: 150, height: 96)
                    .overlay {
                        Image(systemName: icon)
                            .scaledFont(size: 30, weight: .semibold)
                            .foregroundColor(color)
                    }
                Text(title)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Подборка: обложка — картинка одного из её слов, если уже загружена; иначе градиент
private struct CollectionCard: View {
    let name: String
    let words: [Word]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                cover
                    .frame(width: 150, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(name)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 150, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cover: some View {
        // Смотрим только первые слова — картинки хранятся отдельно, всю подборку не перебираем
        if let data = words.prefix(12).lazy.compactMap(\.imageData).first, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            let color = MenuPalette.colors[Self.stableIndex(of: name, count: MenuPalette.colors.count)].color
            LinearGradient(colors: [color.opacity(0.75), color.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Image(systemName: "text.book.closed.fill")
                        .scaledFont(size: 26)
                        .foregroundColor(.white.opacity(0.9))
                }
        }
    }

    /// Один и тот же цвет для подборки при каждом запуске (hashValue меняется между запусками)
    private static func stableIndex(of name: String, count: Int) -> Int {
        Int(name.unicodeScalars.reduce(UInt32(0)) { $0 &* 31 &+ $1.value } % UInt32(count))
    }
}

// MARK: - Заглушка

/// Раздел, который ещё не сделан
struct StubView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Обзор")
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(title)
                    .scaledFont(size: 26, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text(message)
                    .scaledFont(size: 17)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }
}
