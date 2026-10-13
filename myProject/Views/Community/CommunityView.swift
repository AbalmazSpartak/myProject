import SwiftUI
import SwiftData

/// «Сообщество»: сверху ленты «Подборки сообщества» (новые темы из всех разделов), «Английский по кино» и «по музыке»,
/// ниже — список разделов («Английский по кино», «по музыке», «Подборки слов», «Грамматика», свои): раздел открывает все его темы
struct CommunityView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CommunityTopic.createdAt, order: .reverse) private var topics: [CommunityTopic]

    /// Одна история переходов на всё «Сообщество»: раздел → тема — по очереди в одном стеке.
    /// Раньше раздел открывал темы своим переходом внутри перехода — при быстром переключении SwiftUI зацикливался и приложение висло
    @State private var path: [CommunityRoute] = []
    /// Идёт анимация перехода. Нажать «назад» и сразу открыть другое, пока экран ещё едет, — и NavigationStack
    /// ломался: «Сообщество» оставалось пустым белым экраном (воспроизведено на симуляторе). На это время нажатия не принимаем
    @State private var isNavigating = false
    @State private var navigationTick = 0
    @State private var isCreatingTopic = false
    @State private var isShowingSubscriptionLock = false
    @AppStorage(Subscription.simulateMissingKey) private var simulateNoSubscription = false
    /// Открыто вкладкой внизу — «назад» не нужен
    var showsBackButton = true


    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationBarHidden(true)
                .navigationDestination(for: CommunityRoute.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .allowsHitTesting(!isNavigating)
        .onChange(of: path) { _, _ in
            isNavigating = true
            navigationTick += 1
            let tick = navigationTick
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                // Снимает блокировку только последний переход
                if tick == navigationTick { isNavigating = false }
            }
        }
    }

    private var home: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !topics.isEmpty {
                        latestRibbon
                    }
                    moviesRibbon
                    musicRibbon

                    sectionsList

                    createTopicCard
                }
                .padding(.vertical, 12)
                .padding(.bottom, 30)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .alert("Нужна подписка", isPresented: $isShowingSubscriptionLock) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(Subscription.lockedMessage)
        }
        .sheet(isPresented: $isCreatingTopic) {
            TopicEditorView(sections: CommunitySections.all(from: topics))
                .appThemedColorScheme()
        }
    }

    // MARK: - Шапка

    /// Создавать темы — только с подпиской
    private func createTopic() {
        if Subscription.canPost(simulatingMissing: simulateNoSubscription) {
            isCreatingTopic = true
        } else {
            isShowingSubscriptionLock = true
        }
    }

    private var header: some View {
        HStack {
            if showsBackButton {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Обзор")
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
            }
            Spacer()
            HStack(spacing: 16) {
                HelpButton(topic: .community)
                Button(action: createTopic) {
                    Image(systemName: "plus.circle.fill")
                        .scaledFont(size: 22)
                        .foregroundColor(.brandDark)
                }
                .accessibilityLabel("Создать тему")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .overlay {
            Text("Сообщество")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Темы

    /// Новые темы из всех разделов — сначала свежие
    private var latestRibbon: some View {
        Ribbon(title: "Подборки сообщества") {
            ForEach(topics.prefix(Self.latestCount)) { topic in
                TopicCard(topic: topic) { path.append(.topic(topic.id)) }
            }
        }
    }

    private static let latestCount = 10

    /// Все разделы: встроенные — всегда, свои — когда в них есть темы
    private var sectionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Разделы".uppercased())
                .scaledFont(size: 17, weight: .bold)
                .foregroundColor(.brandDark)
            Text("Создавайте темы с текстом и словами — их можно добавить себе в словарь. Пока темы хранятся только на этом телефоне.")
                .scaledFont(size: 15)
                .foregroundColor(.gray)
            ForEach(CommunitySections.all(from: topics), id: \.self) { section in
                CommunitySectionRow(section: section, topics: topics.filter { $0.section == section }) {
                    path.append(.section(section))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var createTopicCard: some View {
        Button(action: createTopic) {
            HStack(spacing: 14) {
                Image(systemName: "square.and.pencil")
                    .scaledFont(size: 24, weight: .semibold)
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topics.isEmpty ? "Создать первую тему" : "Создать тему")
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                    Text("В готовый раздел или в новый — например, «Сленг»")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Кино

    // Заглушка: жанровые карточки без постеров
    private static let movieGenres: [(name: String, icon: String, color: Color)] = [
        ("Фэнтези", "sparkles", .purple),
        ("Фантастика", "globe.americas.fill", .indigo),
        ("Комедии", "face.smiling.inverse", .orange),
        ("Драмы", "theatermasks.fill", .red),
        ("Мультфильмы", "film.fill", .teal)
    ]

    private var moviesRibbon: some View {
        Ribbon(title: "Английский по кино", onTitleTap: { path.append(.section("Английский по кино")) }) {
            if let quotes = topics.first(where: { $0.id == BuiltInTopics.movieQuotesID }) {
                TileCard(title: "10 знаменитых фраз", icon: "quote.bubble.fill", color: .yellow) { path.append(.topic(quotes.id)) }
            }
            ForEach(Self.movieGenres, id: \.name) { genre in
                // У «Фэнтези» уже есть тема — открываем её; остальные жанры пока заглушки
                if genre.name == "Фэнтези", let fantasy = topics.first(where: { $0.id == BuiltInTopics.fantasyID }) {
                    TileCard(title: genre.name, icon: genre.icon, color: genre.color) { path.append(.topic(fantasy.id)) }
                } else {
                    TileCard(title: genre.name, icon: genre.icon, color: genre.color) { path.append(.movies) }
                }
            }
        }
    }

    // MARK: - Музыка

    // Заглушка: жанровые карточки, тем пока нет
    private static let musicGenres: [(name: String, icon: String, color: Color)] = [
        ("Поп", "music.mic", .pink),
        ("Рок", "guitars.fill", .red),
        ("Хип-хоп", "headphones", .indigo),
        ("Баллады", "music.note", .teal),
        ("Классика хитов", "opticaldisc.fill", .orange)
    ]

    private var musicRibbon: some View {
        Ribbon(title: "Английский по музыке", onTitleTap: { path.append(.section("Английский по музыке")) }) {
            if let words = topics.first(where: { $0.id == BuiltInTopics.musicWordsID }) {
                TileCard(title: "Слова о музыке", icon: "music.note.list", color: .purple) { path.append(.topic(words.id)) }
            }
            if let slang = topics.first(where: { $0.id == BuiltInTopics.songSlangID }) {
                TileCard(title: "Gonna, wanna", icon: "quote.bubble.fill", color: .yellow) { path.append(.topic(slang.id)) }
            }
            ForEach(Self.musicGenres, id: \.name) { genre in
                TileCard(title: genre.name, icon: genre.icon, color: genre.color) { path.append(.music) }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: CommunityRoute) -> some View {
        switch route {
        case .topic(let id, let backTitle):
            if let topic = topics.first(where: { $0.id == id }) {
                if let backTitle { TopicView(topic: topic, backTitle: backTitle) } else { TopicView(topic: topic) }
            }
        case .section(let section):
            CommunitySectionView(section: section) { topic in path.append(.topic(topic.id, backTitle: section)) }
        case .movies:
            StubView(title: "Английский по кино", message: "Здесь будет раздел с подборками слов по фильмам", backTitle: "Сообщество")
        case .music:
            StubView(title: "Английский по музыке", message: "Здесь будут слова и фразы из песен по жанрам", backTitle: "Сообщество")
        }
    }
}

/// Куда ведёт переход в «Сообществе». Темы — по id, а не самим объектом: значение не меняется, когда тему правят
enum CommunityRoute: Hashable {
    case topic(UUID, backTitle: String? = nil)
    case section(String)
    case movies
    case music
}

/// Карточка темы в ленте раздела
struct TopicCard: View {
    let topic: CommunityTopic
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.title)
                    .scaledFont(size: 19, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(topic.previewText)
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if !topic.ratingSummary.isEmpty {
                    Text(topic.ratingSummary)
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(.orange)
                }
                if !topic.words.isEmpty {
                    Label("\(topic.words.count) \(DailyStudyCard.wordsNoun(topic.words.count))", systemImage: "text.book.closed")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundColor(.cyan)
                }
            }
            .padding(14)
            .frame(width: 200, height: 150, alignment: .topLeading)
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
