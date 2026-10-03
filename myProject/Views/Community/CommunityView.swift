import SwiftUI
import SwiftData

/// «Сообщество»: темы по разделам («Английский по кино», «Подборки слов», свои — «Грамматика» …)
/// и для примера — ленты «Ваши подборки» и «Английский по кино», как на «Обзоре»
struct CommunityView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CommunityTopic.createdAt, order: .reverse) private var topics: [CommunityTopic]
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]
    @Query(sort: \Category.name) private var categories: [Category]

    @State private var route: Route?
    @State private var isCreatingTopic = false

    private enum Route: Hashable {
        case topic(CommunityTopic)
        case collection(DictionaryFilter)
        case movies
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Создавайте темы с текстом и словами — их можно добавить себе в словарь. Пока темы хранятся только на этом телефоне.")
                        .scaledFont(size: 15)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)

                    ForEach(sectionsWithTopics, id: \.self) { section in
                        topicRibbon(section)
                    }

                    createTopicCard

                    examplesTitle

                    collectionsRibbon
                    moviesRibbon
                }
                .padding(.vertical, 12)
                .padding(.bottom, 30)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationDestination(item: $route) { route in
            destination(for: route)
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isCreatingTopic) {
            TopicEditorView(sections: CommunitySections.all(from: topics))
                .appThemedColorScheme()
        }
    }

    // MARK: - Шапка

    private var header: some View {
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
            HStack(spacing: 16) {
                HelpButton(topic: .community)
                Button { isCreatingTopic = true } label: {
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

    /// Разделы, в которых уже есть темы: встроенные — первыми
    private var sectionsWithTopics: [String] {
        let used = Set(topics.map(\.section))
        return CommunitySections.all(from: topics).filter(used.contains)
    }

    private func topicRibbon(_ section: String) -> some View {
        Ribbon(title: section) {
            ForEach(topics.filter { $0.section == section }) { topic in
                TopicCard(topic: topic) { route = .topic(topic) }
            }
        }
    }

    private var createTopicCard: some View {
        Button { isCreatingTopic = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.pencil")
                    .scaledFont(size: 24, weight: .semibold)
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topics.isEmpty ? "Создать первую тему" : "Создать тему")
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                    Text("В готовый раздел или в новый — например, «Грамматика»")
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

    // MARK: - Примеры

    private var examplesTitle: some View {
        Text("Например")
            .scaledFont(size: 22, weight: .semibold, design: .serif)
            .foregroundColor(.brandDark)
            .padding(.horizontal, 20)
    }

    private var collectionsRibbon: some View {
        Ribbon(title: "Ваши подборки") {
            ForEach(lists) { list in
                CollectionCard(name: list.name, words: list.words) { route = .collection(.list(list)) }
            }
            ForEach(categories) { category in
                CollectionCard(name: category.name, words: category.words) { route = .collection(.category(category)) }
            }
        }
    }

    private var moviesRibbon: some View {
        Ribbon(title: "Английский по кино", onTitleTap: { route = .movies }) {
            ForEach(OverviewView.movieGenres, id: \.name) { genre in
                TileCard(title: genre.name, icon: genre.icon, color: genre.color) { route = .movies }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .topic(let topic):
            TopicView(topic: topic)
        case .collection(let filter):
            DictionaryView(initialFilter: filter, backTitle: "Сообщество")
        case .movies:
            StubView(title: "Английский по кино", message: OverviewView.moviesStubMessage, backTitle: "Сообщество")
        }
    }
}

/// Карточка темы в ленте раздела
private struct TopicCard: View {
    let topic: CommunityTopic
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.title)
                    .scaledFont(size: 19, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(topic.text)
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
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
