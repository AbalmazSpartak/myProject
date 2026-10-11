import SwiftUI
import SwiftData

/// Раздел «Сообщества» («Грамматика», «Произношение», свои): все его темы, сначала новые.
/// «+» создаёт тему сразу в этом разделе
struct CommunitySectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CommunityTopic.createdAt, order: .reverse) private var allTopics: [CommunityTopic]

    let section: String

    @State private var openedTopic: CommunityTopic?
    @State private var isCreatingTopic = false
    @State private var isShowingSubscriptionLock = false
    @AppStorage(Subscription.simulateMissingKey) private var simulateNoSubscription = false

    private var topics: [CommunityTopic] { allTopics.filter { $0.section == section } }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    if topics.isEmpty {
                        empty
                    }
                    ForEach(topics) { topic in
                        SectionTopicRow(topic: topic) { openedTopic = topic }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationDestination(item: $openedTopic) { topic in
            TopicView(topic: topic, backTitle: section)
                .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Нужна подписка", isPresented: $isShowingSubscriptionLock) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(Subscription.lockedMessage)
        }
        .sheet(isPresented: $isCreatingTopic) {
            TopicEditorView(sections: CommunitySections.all(from: allTopics), fixedSection: section)
                .appThemedColorScheme()
        }
    }

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
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Сообщество")
                }
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)
            }
            Spacer()
            Button(action: createTopic) {
                Image(systemName: "plus.circle.fill")
                    .scaledFont(size: 22)
                    .foregroundColor(.brandDark)
            }
            .accessibilityLabel("Создать тему в разделе «\(section)»")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .overlay {
            // Узкая середина: длинное название раздела не наезжает на кнопки
            Text(section)
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 130)
                .padding(.top, 8)
                .allowsHitTesting(false)
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: CommunitySectionRow.icon(for: section))
                .scaledFont(size: 40)
                .foregroundColor(.cyan)
            Text("В разделе пока нет тем")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)
            Button(action: createTopic) {
                Label("Создать тему", systemImage: "square.and.pencil")
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandBackground)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.brandDark))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
    }
}

/// Строка раздела на главном экране «Сообщества»: иконка, название, число тем и последняя тема
struct CommunitySectionRow: View {
    let section: String
    /// Темы раздела, сначала новые
    let topics: [CommunityTopic]
    let action: () -> Void

    /// Иконки встроенных разделов; свои — папка
    static func icon(for section: String) -> String {
        switch section {
        case "Английский по кино": return "film.fill"
        case "Подборки слов": return "text.book.closed.fill"
        case "Грамматика": return "textformat.abc"
        case "Произношение": return "waveform"
        default: return "folder.fill"
        }
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: Self.icon(for: section))
                    .scaledFont(size: 20, weight: .semibold)
                    .foregroundColor(.cyan)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.cyan.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(section)
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .lineLimit(1)
                    Text(subtitle)
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        guard let latest = topics.first else { return "Пока пусто" }
        return "\(topics.count) \(Self.topicsNoun(topics.count)) · \(latest.title)"
    }

    /// 1 тема, 2 темы, 5 тем
    static func topicsNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "тем" }
        switch last {
        case 1: return "тема"
        case 2...4: return "темы"
        default: return "тем"
        }
    }
}

/// Тема в списке раздела: заголовок, начало текста, число слов
private struct SectionTopicRow: View {
    let topic: CommunityTopic
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(topic.title)
                    .scaledFont(size: 19, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .multilineTextAlignment(.leading)
                if !topic.text.isEmpty {
                    Text(topic.text)
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 12) {
                    if !topic.words.isEmpty {
                        Label("\(topic.words.count) \(DailyStudyCard.wordsNoun(topic.words.count))", systemImage: "text.book.closed")
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(.cyan)
                    }
                    if !topic.ratingSummary.isEmpty {
                        Text(topic.ratingSummary)
                            .scaledFont(size: 12, weight: .semibold)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
