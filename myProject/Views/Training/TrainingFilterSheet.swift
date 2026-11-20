import SwiftUI

/// «Что повторять» — лист снизу для карточек по холсту (вариант A): режим, уровень и темы на одном экране
struct TrainingFilterSheet: View {
    let current: TrainingFilter
    let counts: WordCounts
    let categories: [Category]
    var includesDue = false
    let onSelect: (TrainingFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private func choose(_ filter: TrainingFilter) {
        Haptics.tap()
        onSelect(filter)
        dismiss()
    }

    /// Темы по разделам; свои папки, которых нет в списке 48 тем, — в конце
    private var sections: [(title: String, topics: [Category])] {
        let byName = Dictionary(categories.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        func matches(_ category: Category) -> Bool { needle.isEmpty || category.name.lowercased().contains(needle) }

        var result = TopicSections.all.compactMap { section -> (title: String, topics: [Category])? in
            let topics = section.topics.compactMap { byName[$0] }.filter(matches)
            return topics.isEmpty ? nil : (title: section.title, topics: topics)
        }
        let others = categories.filter { !TopicSections.topicNames.contains($0.name) && matches($0) }
        if !others.isEmpty { result.append((title: "Другие", topics: others)) }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Что повторять")
                    .scaledFont(size: 24, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                Spacer()
                Button { dismiss() } label: {
                    LXIconLabel(systemImage: "xmark", label: "Закрыть")
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.top, 8)
            .frame(minHeight: 52)

            searchField
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if query.isEmpty {
                        LXSectionLabel(text: "Режим")
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                        modeChips.padding(.horizontal, 16)

                        LXSectionLabel(text: "Уровень")
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                        levelTiles.padding(.horizontal, 16)
                    }

                    ForEach(sections, id: \.title) { section in
                        LXSectionLabel(text: section.title)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 6)
                        LXGroup {
                            ForEach(section.topics) { topic in topicRow(topic) }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !query.isEmpty, sections.isEmpty {
                        Text("Такой темы нет")
                            .scaledFont(size: 15)
                            .foregroundStyle(Color.brandMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Части листа

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").scaledFont(size: 17)
            TextField("Поиск по темам", text: $query)
                .scaledFont(size: 15)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").scaledFont(size: 17)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить поиск")
            }
        }
        .foregroundStyle(Color.brandMuted)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modeChips: some View {
        FlowLayout(spacing: 8, centered: false) {
            if includesDue {
                modeChip("На повторение", detail: "\(counts.due)", filter: .due)
            }
            modeChip("Все слова", detail: nil, filter: .all)
            modeChip("Работа над ошибками", detail: "\(counts.mistakes)", filter: .mistakes, isEnabled: counts.mistakes > 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func modeChip(_ title: String, detail: String?, filter: TrainingFilter, isEnabled: Bool = true) -> some View {
        let isOn = current == filter
        return Button { choose(filter) } label: {
            LXChipLabel(title: title, detail: detail, systemImage: isOn ? "checkmark" : nil, isOn: isOn)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var levelTiles: some View {
        HStack(spacing: 6) {
            ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                let count = counts.count(level: level)
                let isOn = current == .level(level)
                Button { choose(.level(level)) } label: {
                    VStack(spacing: 1) {
                        Text(level.rawValue).scaledFont(size: 15, weight: .semibold)
                        Text(count.formatted()).scaledFont(size: 12)
                            .foregroundStyle(isOn ? Color.brandOnSoft : Color.brandMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isOn ? Color.brandOnSoft : Color.brandDark)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(isOn ? Color.brandAccent : Color.cardBackground,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isOn ? Color.clear : Color.brandBorder,
                                    style: StrokeStyle(lineWidth: 1, dash: count == 0 ? [4, 3] : []))
                    }
                }
                .buttonStyle(.plain)
                .disabled(count == 0)
                .opacity(count == 0 ? 0.6 : 1)
                .accessibilityLabel("Уровень \(level.rawValue), \(DictionaryCounts.words(count))")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func topicRow(_ topic: Category) -> some View {
        let isOn = current == .category(topic)
        return Button { choose(.category(topic)) } label: {
            HStack(spacing: 10) {
                Text(topic.name)
                    .scaledFont(size: 16, weight: isOn ? .semibold : .medium)
                    .foregroundStyle(Color.brandDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(counts.count(for: topic).formatted())
                    .scaledFont(size: 14)
                    .foregroundStyle(Color.brandMuted)
                Image(systemName: isOn ? "checkmark" : "chevron.right")
                    .scaledFont(size: isOn ? 15 : 13, weight: .semibold)
                    .foregroundStyle(isOn ? Color.brandTint : Color.brandMuted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(isOn ? Color.brandAccent.opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
