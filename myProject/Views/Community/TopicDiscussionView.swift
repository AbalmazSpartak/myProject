import SwiftUI
import SwiftData

/// Обсуждение темы: комментарии с ответами (один уровень) и «нравится», поле ввода внизу.
/// `limit` — сколько последних веток показать на странице темы; nil — все (экран «Все комментарии»)
struct TopicDiscussionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage(Subscription.simulateMissingKey) private var simulateNoSubscription = false

    let topic: CommunityTopic
    var limit: Int?

    @State private var draft = ""
    /// Отвечаем на этот комментарий (верхнего уровня)
    @State private var replyTo: TopicComment?
    /// Правим свой комментарий
    @State private var editing: TopicComment?
    @State private var isShowingAll = false
    @FocusState private var isComposerFocused: Bool

    private var canPost: Bool { Subscription.canPost(simulatingMissing: simulateNoSubscription) }

    /// Ветки: комментарии верхнего уровня, сначала новые
    private var threads: [TopicComment] {
        topic.comments.filter { $0.parentID == nil }.sorted { $0.createdAt > $1.createdAt }
    }

    private func replies(to comment: TopicComment) -> [TopicComment] {
        topic.comments.filter { $0.parentID == comment.id }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(topic.comments.isEmpty ? "Обсуждение" : "Обсуждение · \(topic.comments.count)")
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.brandDark)

            composer

            if threads.isEmpty {
                Text("Пока никто не написал. Начните обсуждение — вопрос, пример, своя подсказка.")
                    .scaledFont(size: 14)
                    .foregroundColor(.gray)
            }

            let shown = limit.map { Array(threads.prefix($0)) } ?? threads
            ForEach(shown) { comment in
                VStack(alignment: .leading, spacing: 10) {
                    commentRow(comment)
                    ForEach(replies(to: comment)) { reply in
                        commentRow(reply)
                            .padding(.leading, 40)
                    }
                }
            }

            if let limit, threads.count > limit {
                Button { isShowingAll = true } label: {
                    Text("Все комментарии · \(topic.comments.count)")
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .sheet(isPresented: $isShowingAll) {
            NavigationStack {
                ScrollView {
                    TopicDiscussionView(topic: topic)
                        .padding(20)
                }
                .background(Color.brandBackground.ignoresSafeArea())
                .navigationTitle("Обсуждение")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") { isShowingAll = false }
                            .fontWeight(.bold)
                    }
                }
            }
            .appThemedColorScheme()
        }
    }

    // MARK: - Поле ввода

    @ViewBuilder
    private var composer: some View {
        if canPost {
            VStack(alignment: .leading, spacing: 6) {
                if let target = replyTo ?? editing {
                    HStack(spacing: 6) {
                        Text(editing != nil ? "Изменение комментария" : "Ответ для \(target.authorName)")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(.cyan)
                        Button {
                            replyTo = nil
                            editing = nil
                            draft = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Отменить")
                    }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Написать комментарий…", text: $draft, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isComposerFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color.brandFill))
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .scaledFont(size: 30)
                            .foregroundColor(trimmedDraft.isEmpty ? .gray.opacity(0.4) : .cyan)
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedDraft.isEmpty)
                    .accessibilityLabel("Отправить")
                }
            }
        } else {
            Label("Писать в обсуждении можно с подпиской", systemImage: "lock.fill")
                .scaledFont(size: 14, weight: .semibold)
                .foregroundColor(.gray)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandFill))
        }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func send() {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        if let editing {
            editing.text = text
            editing.editedAt = Date()
        } else {
            let comment = TopicComment(text: text, authorName: profiles.first?.name ?? "Студент", parentID: replyTo?.id)
            modelContext.insert(comment)
            comment.topic = topic
        }
        try? modelContext.save()
        Haptics.tap()
        draft = ""
        replyTo = nil
        editing = nil
        isComposerFocused = false
    }

    // MARK: - Комментарий

    private func commentRow(_ comment: TopicComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(comment)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(.brandDark)
                    Text(Self.relativeTime(comment.createdAt) + (comment.editedAt != nil ? " · изменён" : ""))
                        .scaledFont(size: 12)
                        .foregroundColor(.gray)
                }
                Text(comment.text)
                    .scaledFont(size: 15)
                    .foregroundColor(.brandDark)
                    .textSelection(.enabled)
                HStack(spacing: 16) {
                    Button {
                        Haptics.tap()
                        comment.isLikedByMe.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(comment.likeCount > 0 ? "\(comment.likeCount)" : "Нравится",
                              systemImage: comment.isLikedByMe ? "heart.fill" : "heart")
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundColor(comment.isLikedByMe ? .red : .gray)
                    }
                    .buttonStyle(.plain)
                    if canPost {
                        Button {
                            // Ответ на ответ — в ту же ветку
                            replyTo = comment.parentID.flatMap { id in topic.comments.first { $0.id == id } } ?? comment
                            editing = nil
                            isComposerFocused = true
                        } label: {
                            Text("Ответить")
                                .scaledFont(size: 13, weight: .semibold)
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .contextMenu {
            if comment.isMine {
                if canPost {
                    Button {
                        editing = comment
                        replyTo = nil
                        draft = comment.text
                        isComposerFocused = true
                    } label: {
                        Label("Изменить", systemImage: "pencil")
                    }
                }
                Button(role: .destructive) { delete(comment) } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
    }

    /// Свой — фото из профиля; чужой — первая буква имени
    @ViewBuilder
    private func avatar(_ comment: TopicComment) -> some View {
        if comment.isMine, let data = profiles.first?.avatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Text(String(comment.authorName.prefix(1)).uppercased())
                .scaledFont(size: 14, weight: .bold)
                .foregroundColor(.teal)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.teal.opacity(0.18)))
        }
    }

    /// Ветка удаляется вместе с ответами
    private func delete(_ comment: TopicComment) {
        if comment.parentID == nil {
            for reply in replies(to: comment) { modelContext.delete(reply) }
        }
        if replyTo?.id == comment.id { replyTo = nil }
        if editing?.id == comment.id { editing = nil; draft = "" }
        modelContext.delete(comment)
        try? modelContext.save()
    }

    private static func relativeTime(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "только что" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
