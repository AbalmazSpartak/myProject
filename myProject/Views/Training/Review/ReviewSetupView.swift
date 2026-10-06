import SwiftUI
import SwiftData

/// «Повторение»: прогон уже пройденных слов без сдвига расписания FSRS.
/// Перед стартом — какие слова (стадия изучения), на каком языке показывать, озвучка и категории
enum ReviewStage: String, CaseIterable, Identifiable {
    case learning, reviewing, relearning, mistakes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learning: return "Учу"
        case .reviewing: return "Закрепляю"
        case .relearning: return "Забытые"
        case .mistakes: return "С ошибками"
        }
    }

    var hint: String {
        switch self {
        case .learning: return "недавно начатые"
        case .reviewing: return "на регулярном повторении"
        case .relearning: return "забыл, учу заново"
        case .mistakes: return "ошибся в тренировках"
        }
    }

    func contains(_ word: Word) -> Bool {
        switch self {
        case .learning: return word.state == .learning
        case .reviewing: return word.state == .review
        case .relearning: return word.state == .relearning
        case .mistakes: return word.isMistake
        }
    }
}

/// Настройки «Повторения» — запоминаются между запусками
enum ReviewSettings {
    static let stagesKey = "review_stages"
    static let showEnglishKey = "review_show_english"
    static let autoSpeakKey = "review_auto_speak"
    static let filtersKey = "review_filters"
}

struct ReviewSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage(ReviewSettings.showEnglishKey) private var showEnglish = true
    @AppStorage(ReviewSettings.autoSpeakKey) private var autoSpeak = true
    @AppStorage(ReviewSettings.stagesKey) private var stagesRaw = "learning,reviewing,relearning,mistakes"
    /// Пусто — все слова; иначе «pos:Глаголы», «topic:Время»
    @AppStorage(ReviewSettings.filtersKey) private var filtersRaw = ""

    @State private var studied: [Word] = []
    @State private var session: [Word]?

    private var stages: Set<ReviewStage> {
        Set(stagesRaw.split(separator: ",").compactMap { ReviewStage(rawValue: String($0)) })
    }

    private var filters: Set<String> {
        Set(filtersRaw.split(separator: ",").map(String.init))
    }

    /// Слова, подходящие по стадии; категории — отдельно, чтобы показать счётчики
    private var byStage: [Word] {
        studied.filter { word in stages.contains { $0.contains(word) } }
    }

    private var selected: [Word] {
        guard !filters.isEmpty else { return byStage }
        return byStage.filter { filters.contains(Self.posKey($0)) || filters.contains(Self.topicKey($0)) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    stagesSection
                    directionSection
                    categoriesSection
                }
                .padding(20)
                .padding(.bottom, 90)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .overlay(alignment: .bottom) { startButton }
        .onAppear { load() }
        .fullScreenCover(item: Binding(get: { session.map(ReviewSession.init) }, set: { if $0 == nil { session = nil } })) { item in
            ReviewSessionView(words: item.words, showEnglish: showEnglish, autoSpeak: autoSpeak)
                .appThemedColorScheme()
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
            Text("Повторение")
                .scaledFont(size: 20, weight: .bold)
                .foregroundColor(.brandDark)
            Spacer()
            Color.clear.frame(width: 70, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Показать слова

    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            title("Показать слова")
            VStack(spacing: 0) {
                ForEach(ReviewStage.allCases) { stage in
                    Button { toggle(stage) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: stages.contains(stage) ? "checkmark.circle.fill" : "circle")
                                .scaledFont(size: 22)
                                .foregroundColor(stages.contains(stage) ? .brandTint : .gray.opacity(0.5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stage.title)
                                    .scaledFont(size: 17, weight: .semibold)
                                    .foregroundColor(.brandDark)
                                Text(stage.hint)
                                    .scaledFont(size: 13)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(studied.filter(stage.contains).count)")
                                .scaledFont(size: 15, weight: .semibold, design: .rounded)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if stage != ReviewStage.allCases.last { Divider().padding(.leading, 48) }
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Язык и озвучка

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            title("Показывать на")
            Picker("Показывать на", selection: $showEnglish) {
                Text("Английском").tag(true)
                Text("Русском").tag(false)
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $autoSpeak) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Озвучивать английское слово сразу")
                        .scaledFont(size: 16, weight: .medium)
                        .foregroundColor(.brandDark)
                    Text(showEnglish ? "при показе слова" : "при показе ответа — чтобы не подсказывать")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                }
            }
            .tint(.brandTint)
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Категории

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            title("Категории")
            FlowLayout(spacing: 8, centered: false) {
                chip("Все слова", count: byStage.count, isOn: filters.isEmpty) { filtersRaw = "" }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Части речи").scaledFont(size: 13, weight: .semibold).foregroundColor(.gray)
            chips(for: partOfSpeechCounts, key: Self.posKey(group:))

            if !topicCounts.isEmpty {
                Text("Темы").scaledFont(size: 13, weight: .semibold).foregroundColor(.gray)
                chips(for: topicCounts, key: Self.topicKey(name:))
            }
        }
    }

    private var partOfSpeechCounts: [(String, Int)] {
        let counts = Dictionary(grouping: byStage) { StudyScope.partOfSpeechGroup(of: $0) }
            .filter { !$0.key.isEmpty }.mapValues(\.count)
        return counts.sorted { StudyScope.partOfSpeechOrder($0.key) < StudyScope.partOfSpeechOrder($1.key) }
    }

    private var topicCounts: [(String, Int)] {
        Dictionary(grouping: byStage) { StudyScope.topic(of: $0) }
            .filter { !$0.key.isEmpty }.mapValues(\.count)
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
    }

    private func chips(for items: [(String, Int)], key: @escaping (String) -> String) -> some View {
        FlowLayout(spacing: 8, centered: false) {
            ForEach(items, id: \.0) { name, count in
                chip(name, count: count, isOn: filters.contains(key(name))) { toggle(filter: key(name)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ name: String, count: Int, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(name)
                Text("\(count)").foregroundColor(isOn ? .brandBackground.opacity(0.8) : .gray)
            }
            .scaledFont(size: 15, weight: .semibold)
            .foregroundColor(isOn ? .brandBackground : .brandDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(isOn ? Color.brandDark : Color.cardBackground))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Начать

    private var startButton: some View {
        Button {
            session = selected.shuffled()
        } label: {
            Text(selected.isEmpty ? "Нет слов для повторения" : "Начать · \(selected.count) \(DailyStudyCard.wordsNoun(selected.count))")
                .scaledFont(size: 18, weight: .bold)
                .foregroundColor(.brandBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.brandDark.opacity(selected.isEmpty ? 0.35 : 1)))
        }
        .disabled(selected.isEmpty)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(LinearGradient(colors: [Color.brandBackground.opacity(0), Color.brandBackground], startPoint: .top, endPoint: .center))
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 20, weight: .semibold, design: .serif)
            .foregroundColor(.brandDark)
    }

    // MARK: - Логика

    private func load() {
        // Пройденные — те, что хоть раз оценивались
        studied = modelContext.fetchAllWords().filter { $0.reps > 0 || $0.isMistake }
    }

    private func toggle(_ stage: ReviewStage) {
        var current = stages
        if current.contains(stage) { current.remove(stage) } else { current.insert(stage) }
        stagesRaw = ReviewStage.allCases.filter(current.contains).map(\.rawValue).joined(separator: ",")
    }

    private func toggle(filter key: String) {
        var current = filters
        if current.contains(key) { current.remove(key) } else { current.insert(key) }
        filtersRaw = current.sorted().joined(separator: ",")
    }

    private static func posKey(_ word: Word) -> String { posKey(group: StudyScope.partOfSpeechGroup(of: word)) }
    private static func posKey(group: String) -> String { "pos:" + group }
    private static func topicKey(_ word: Word) -> String { topicKey(name: StudyScope.topic(of: word)) }
    private static func topicKey(name: String) -> String { "topic:" + name }
}

/// Набор слов для показа — обёртка, чтобы открыть тренировку по item
private struct ReviewSession: Identifiable {
    let id = UUID()
    let words: [Word]
}
