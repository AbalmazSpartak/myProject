import SwiftUI
import SwiftData

/// Из какого словаря слова гонки: выбранные для изучения, ошибки, уровень, свой словарь или тема.
/// Один выбор на всё лобби — и для гонки в одиночку, и для комнаты (слова задаёт её создатель)
enum RaceWordSource: Hashable {
    case study
    case mistakes
    case level(String)
    case list(UUID)
    case topic(UUID)

    static let storageKey = "race_word_source"
    /// Меньше — не из чего собрать три варианта ответа
    static let minimumWords = 4

    // MARK: - Хранение строкой: "study", "mistakes", "level:A1", "list:<id>", "topic:<id>"

    init(storedValue: String) {
        let parts = storedValue.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("mistakes", _): self = .mistakes
        case ("level", let raw?): self = .level(raw)
        case ("list", let raw?): self = UUID(uuidString: raw).map(Self.list) ?? .study
        case ("topic", let raw?): self = UUID(uuidString: raw).map(Self.topic) ?? .study
        default: self = .study
        }
    }

    var storedValue: String {
        switch self {
        case .study: return "study"
        case .mistakes: return "mistakes"
        case .level(let raw): return "level:\(raw)"
        case .list(let id): return "list:\(id.uuidString)"
        case .topic(let id): return "topic:\(id.uuidString)"
        }
    }

    // MARK: - Слова

    func predicate(scope: StudyScope) -> Predicate<Word> {
        switch self {
        case .study:
            return StudyWords.scope(scope)
        case .mistakes:
            return #Predicate<Word> { $0.isMistake }
        case .level(let raw):
            return #Predicate<Word> { $0.cefrLevel == raw }
        case .list(let id):
            return #Predicate<Word> { word in word.lists.contains { $0.id == id } }
        case .topic(let id):
            return #Predicate<Word> { $0.category?.id == id }
        }
    }

    /// Слова для гонки запросом к базе — все не читаем (10 000+ — ~2 с на iPhone 12).
    /// В выбранном меньше четырёх (словарь удалили, ошибки исправили) — выбранные для изучения, затем весь словарь
    func words(scope: StudyScope, in context: ModelContext) -> [Word] {
        var words = StudyWords.random(predicate(scope: scope), limit: 200, in: context)
        if words.count < Self.minimumWords, self != .study {
            words = StudyWords.random(StudyWords.scope(scope), limit: 200, in: context)
        }
        if words.count < Self.minimumWords {
            words = StudyWords.random(#Predicate<Word> { _ in true }, limit: 200, in: context)
        }
        return words
    }

    /// Название в строке «Слова: …»
    func title(in context: ModelContext) -> String {
        switch self {
        case .study: return "Выбранные для изучения"
        case .mistakes: return "Работа над ошибками"
        case .level(let raw): return "Уровень \(raw)"
        case .list(let id):
            var descriptor = FetchDescriptor<WordList>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor).first?.name) ?? "Мой словарь"
        case .topic(let id):
            var descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor).first?.name) ?? "Тема"
        }
    }
}

/// Список словарей для гонки: один выбор, у каждого — число слов; где меньше четырёх — недоступно.
/// Числа тем досчитываются порциями после показа: 117 тем — ~0,5 с запросов
struct RaceWordSourcePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @Query(sort: \WordList.name) private var lists: [WordList]
    @Query(sort: \Category.name) private var categories: [Category]

    @Binding var selection: String
    @State private var counts: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        row(.study, title: "Выбранные для изучения", icon: "checklist")
                        row(.mistakes, title: "Работа над ошибками", icon: "exclamationmark.triangle.fill")
                    }
                    Section("Уровни") {
                        ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                            row(.level(level.rawValue), title: "Уровень \(level.rawValue)", icon: "chart.bar.fill")
                        }
                    }
                    if !lists.isEmpty {
                        Section("Мои словари") {
                            ForEach(lists) { list in
                                row(.list(list.id), title: list.name, icon: "text.book.closed.fill")
                            }
                        }
                    }
                    Section("Темы") {
                        ForEach(categories) { category in
                            row(.topic(category.id), title: category.name, icon: "folder.fill")
                        }
                    }
                }
                .listRowBackground(Color.cardBackground)
            }
            .brandListBackground()
            .navigationTitle("Слова для гонки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .task { await countAll() }
        }
    }

    private func row(_ source: RaceWordSource, title: String, icon: String) -> some View {
        let count = counts[source.storedValue]
        let isAvailable = count.map { $0 >= RaceWordSource.minimumWords } ?? true
        return Button {
            selection = source.storedValue
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.indigo)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.brandDark)
                Spacer()
                if let count {
                    Text("\(count)")
                        .foregroundColor(.gray)
                }
                if selection == source.storedValue {
                    Image(systemName: "checkmark")
                        .foregroundColor(.indigo)
                        .fontWeight(.bold)
                }
            }
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
    }

    /// Сначала основное, уровни и словари, затем темы — по 4 с паузой в кадр, чтобы список сразу листался
    private func countAll() async {
        var sources: [RaceWordSource] = [.study, .mistakes] + CEFRLevel.allCases.map { .level($0.rawValue) }
        sources += lists.map { .list($0.id) }
        sources += categories.map { .topic($0.id) }
        for (index, source) in sources.enumerated() {
            counts[source.storedValue] = StudyWords.count(source.predicate(scope: studyScope), in: modelContext)
            if index % 4 == 3 { try? await Task.sleep(for: .milliseconds(16)) }
        }
    }
}
