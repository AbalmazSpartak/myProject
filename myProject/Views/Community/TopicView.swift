import SwiftUI
import SwiftData

/// Тема сообщества: текст и слова, которые можно добавить себе в словарь
struct TopicView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [WordList]

    let topic: CommunityTopic
    var backTitle = "Сообщество"

    @State private var isConfirmingDelete = false
    @State private var addedMessage: String?

    private var notAddedWords: [TopicWord] {
        topic.words.filter { !topic.isAdded($0, lists: lists) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(topic.section.uppercased())
                        .scaledFont(size: 13, weight: .bold)
                        .foregroundColor(.cyan)
                    Text(topic.title)
                        .scaledFont(size: 30, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                    saveButton
                    let blocks = topic.blocks
                    if blocks.isEmpty, !topic.text.isEmpty {
                        // Тема первой версии — только текст
                        Text(topic.text)
                            .scaledFont(size: 17, design: .serif)
                            .foregroundColor(.brandDark)
                            .textSelection(.enabled)
                    }
                    ForEach(blocks) { block in
                        TopicBlockView(block: block, clip: topic.audioClip(for: block))
                    }
                    if !topic.words.isEmpty {
                        wordsCard
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .alert("Удалить тему?", isPresented: $isConfirmingDelete) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                modelContext.delete(topic)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Слова, которые вы уже добавили себе, останутся в словаре.")
        }
        .alert("Добавлено", isPresented: Binding(get: { addedMessage != nil }, set: { if !$0 { addedMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addedMessage ?? "")
        }
    }

    private var header: some View {
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
            Menu {
                Button(role: .destructive) { isConfirmingDelete = true } label: {
                    Label("Удалить тему", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .scaledFont(size: 22)
                    .foregroundColor(.brandDark)
            }
            .accessibilityLabel("Ещё")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Подборки

    /// Тема в «Ваших подборках» на «Обзоре» — оттуда её можно открыть и изучать
    private var saveButton: some View {
        let isSaved = topic.savedAt != nil
        return Button {
            topic.savedAt = isSaved ? nil : Date()
            try? modelContext.save()
        } label: {
            Label(isSaved ? "В ваших подборках" : "В мои подборки",
                  systemImage: isSaved ? "bookmark.fill" : "bookmark")
                .scaledFont(size: 15, weight: .semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSaved ? Color.cyan.opacity(0.18) : Color.cardBackground)
                .foregroundColor(.brandDark)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .accessibilityHint(isSaved ? "Убрать из подборок на «Обзоре»" : "Добавить в подборки на «Обзоре»")
    }

    // MARK: - Слова

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Слова темы")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)

            ForEach(topic.words) { item in
                wordRow(item)
                if item.id != topic.words.last?.id { Divider() }
            }

            Button {
                add(notAddedWords)
            } label: {
                Text(notAddedWords.isEmpty ? "Все слова уже в словаре" : "Добавить все в словарь")
                    .scaledFont(size: 16, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(notAddedWords.isEmpty ? Color.gray.opacity(0.15) : Color.cyan.opacity(0.18))
                    .foregroundColor(notAddedWords.isEmpty ? .gray : .brandDark)
                    .cornerRadius(12)
            }
            .disabled(notAddedWords.isEmpty)
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }

    private func wordRow(_ item: TopicWord) -> some View {
        let isAdded = topic.isAdded(item, lists: lists)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.english)
                    .scaledFont(size: 17, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text(item.russian)
                    .scaledFont(size: 15)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button {
                TextToSpeechManager.shared.speak(item.english)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Озвучить")
            Button {
                add([item])
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .scaledFont(size: 24)
                    .foregroundColor(isAdded ? .green : .cyan)
            }
            .buttonStyle(.borderless)
            .disabled(isAdded)
            .accessibilityLabel(isAdded ? "Уже в словаре" : "Добавить в словарь")
        }
    }

    private func add(_ items: [TopicWord]) {
        guard !items.isEmpty else { return }
        let list = topic.addToDictionary(items, context: modelContext)
        if items.count > 1 {
            addedMessage = "Слова добавлены в ваш словарь «\(list.name)»."
        }
    }
}
