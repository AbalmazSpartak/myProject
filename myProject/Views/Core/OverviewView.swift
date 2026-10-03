import SwiftUI
import SwiftData

/// «Обзор» — главный экран в стиле журнала: слово дня, подборки, ленты тренировок и игр
struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    /// Темы сообщества, добавленные в «Ваши подборки»
    @Query(filter: #Predicate<CommunityTopic> { $0.savedAt != nil }, sort: \CommunityTopic.savedAt, order: .reverse)
    private var savedTopics: [CommunityTopic]
    @AppStorage(MainMenuLayout.storageKey) private var menuLayout = MainMenuLayout.standard

    @State private var wordsOfDay: [Word] = []

    let open: (ActiveScreen) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if !menuLayout.isHidden(.wordOfDay), !wordsOfDay.isEmpty {
                    WordOfDayCarousel(words: wordsOfDay)
                }

                if !menuLayout.isHidden(.collections) {
                    collectionsRibbon
                }

                // Ленты разделов — по настройке «Ленты «Обзора»»: каждая группа — своя лента
                ForEach(ribbons, id: \.title) { ribbon in
                    sectionRibbon(ribbon)
                }

                if !menuLayout.isHidden(.movies) {
                    moviesRibbon
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 30)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            // Скрытое «Слово дня» — слова не загружаем; включат в настройках — загрузим при возврате на «Обзор»
            if wordsOfDay.isEmpty, !menuLayout.isHidden(.wordOfDay) {
                wordsOfDay = WordOfDay.recent(days: 7, from: modelContext.fetchAllWords())
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        Text("WORDLEARNER")
            .scaledFont(size: 26, weight: .heavy)
            .foregroundColor(.brandDark)
            .padding(.horizontal, 20)
    }

    // MARK: - Подборки

    private var collectionsRibbon: some View {
        Ribbon(title: "Ваши подборки", onTitleTap: { open(.community) }) {
            AddTopicCard { open(.community) }
            ForEach(savedTopics) { topic in
                TopicCard(topic: topic) { open(.topic(topic)) }
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

    static let movieGenres: [(name: String, icon: String, color: Color)] = [
        ("Фэнтези", "sparkles", .purple),
        ("Фантастика", "globe.americas.fill", .indigo),
        ("Комедии", "face.smiling.inverse", .orange),
        ("Драмы", "theatermasks.fill", .red),
        ("Мультфильмы", "film.fill", .teal)
    ]

    static let moviesStubMessage = "Здесь будет раздел с подборками слов по фильмам"

    private var moviesRibbon: some View {
        let stub = ActiveScreen.stub(title: "Английский по кино", message: Self.moviesStubMessage)
        return Ribbon(title: "Английский по кино", onTitleTap: { open(stub) }) {
            ForEach(Self.movieGenres, id: \.name) { genre in
                TileCard(title: genre.name, icon: genre.icon, color: genre.color) { open(stub) }
            }
        }
    }
}

// MARK: - Лента

/// Заголовок прописными и горизонтальная лента карточек
struct Ribbon<Content: View>: View {
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
struct TileCard: View {
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
struct CollectionCard: View {
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

/// Первая карточка «Ваших подборок»: открывает «Сообщество», где тему можно добавить себе
private struct AddTopicCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .scaledFont(size: 30)
                    .foregroundColor(.cyan)
                Text("Добавить тему из сообщества")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(width: 200, height: 150)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.cyan.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Заглушка

/// Раздел, который ещё не сделан
struct StubView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    var backTitle = "Обзор"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(backTitle)
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
