import SwiftUI
import SwiftData

/// «Мои закладки» — все темы «Сообщества», добавленные в «Ваши подборки» (кнопка «Все» на «Обзоре»).
/// Свайп влево убирает тему из закладок, сама тема остаётся в «Сообществе»
struct BookmarksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CommunityTopic> { $0.savedAt != nil }, sort: \CommunityTopic.savedAt, order: .reverse)
    private var savedTopics: [CommunityTopic]

    @State private var openedTopic: CommunityTopic?

    var body: some View {
        VStack(spacing: 0) {
            header
            if savedTopics.isEmpty {
                ContentUnavailableView(
                    "Закладок нет",
                    systemImage: "bookmark",
                    description: Text("Откройте тему в «Сообществе» и нажмите «В мои подборки».")
                )
            } else {
                List {
                    ForEach(savedTopics) { topic in
                        SavedTopicRow(topic: topic) { openedTopic = topic }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                            .swipeActions {
                                Button(role: .destructive) {
                                    topic.savedAt = nil
                                    try? modelContext.save()
                                } label: {
                                    Label("Убрать", systemImage: "bookmark.slash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationDestination(item: $openedTopic) { topic in
            TopicView(topic: topic, backTitle: "Закладки")
                .toolbar(.hidden, for: .navigationBar)
        }
    }

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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .overlay {
            Text("Мои закладки")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .allowsHitTesting(false)
        }
    }
}
