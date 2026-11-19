import SwiftUI
import SwiftData

/// «Темы» встроенной базы по восьми разделам («Папки» → «Темы»); выбор темы открывает её в Словаре
struct TopicsView: View {
    let categories: [Category]
    let onSelect: (Category) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var query = ""

    private var sections: [(title: String, topics: [Category])] {
        let byName = Dictionary(categories.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return TopicSections.all.compactMap { section in
            let topics = section.topics.compactMap { byName[$0] }
                .filter { needle.isEmpty || $0.name.lowercased().contains(needle) }
            return topics.isEmpty ? nil : (title: section.title, topics: topics)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Темы")
                    .scaledFont(size: 32, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                searchField
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                ForEach(sections, id: \.title) { section in
                    LXSectionLabel(text: section.title)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 8)
                    LXGroup {
                        ForEach(section.topics) { topic in row(topic) }
                    }
                    .padding(.horizontal, 16)
                }

                if sections.isEmpty {
                    Text("Такой темы нет")
                        .scaledFont(size: 15)
                        .foregroundStyle(Color.brandMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Темы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.brandBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").scaledFont(size: 17)
            TextField("Искать тему", text: $query)
                .scaledFont(size: 16)
                .foregroundStyle(Color.brandDark)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").scaledFont(size: 17)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить")
            }
        }
        .foregroundStyle(Color.brandMuted)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ topic: Category) -> some View {
        Button { onSelect(topic) } label: {
            HStack(spacing: 12) {
                Text(topic.name)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(Color.brandDark)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(DictionaryCounts.category(topic, in: modelContext).formatted())
                    .scaledFont(size: 14)
                    .foregroundStyle(Color.brandMuted)
                Image(systemName: "chevron.right")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(Color.brandMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
