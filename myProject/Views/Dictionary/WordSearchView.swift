import SwiftUI
import SwiftData

/// Поиск слова по всей базе (по английскому и русскому) по дизайну LexiStream; нажатие открывает карточку слова
struct WordSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Недавние запросы — через перевод строки, новые впереди
    @AppStorage("dictionary_recent_queries") private var recentRaw = ""
    @FocusState private var isFocused: Bool

    @State private var query = ""
    @State private var results: [Word] = []
    @State private var index: [SearchEntry] = []
    @State private var wordToShow: Word?
    #if DEBUG
    @State private var copiedWordID: PersistentIdentifier?
    #endif

    private let resultLimit = 100
    private let recentLimit = 8

    /// Слово с заранее приведёнными к нижнему регистру полями — чтобы не делать это на каждое нажатие клавиши
    private struct SearchEntry {
        let word: Word
        let english: String
        let russian: String
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    private var recent: [String] {
        recentRaw.split(separator: "\n").map(String.init)
    }

    /// Читаем слова из базы один раз, а не через @Query: тот перечитывает все слова при каждой перерисовке (~0,6 с на букву)
    private func rebuildIndex() {
        let words = (try? modelContext.fetch(FetchDescriptor<Word>(sortBy: [SortDescriptor(\.english)]))) ?? []
        index = words.map { SearchEntry(word: $0, english: Self.normalized($0.english), russian: Self.normalized($0.russian)) }
        updateResults()
    }

    /// Сначала слова, начинающиеся с запроса, затем содержащие его (по английскому и русскому)
    private func updateResults() {
        let q = Self.normalized(query.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { results = []; return }
        var prefix: [Word] = []
        var contains: [Word] = []
        for entry in index {
            if entry.english.hasPrefix(q) {
                prefix.append(entry.word)
                if prefix.count == resultLimit { break }
            } else if contains.count < resultLimit, entry.english.contains(q) || entry.russian.contains(q) {
                contains.append(entry.word)
            }
        }
        results = Array((prefix + contains).prefix(resultLimit))
    }

    private func remember(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        var items = recent.filter { $0.caseInsensitiveCompare(text) != .orderedSame }
        items.insert(text, at: 0)
        recentRaw = items.prefix(recentLimit).joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                searchField
                LXTextButton(title: "Отмена") { dismiss() }
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onChange(of: query) { updateResults() }
        .task {
            rebuildIndex()
            isFocused = true
        }
        // Слово могли удалить в правке — перестраиваем список, чтобы не показать удалённое
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in rebuildIndex() }
        .sheet(item: $wordToShow, onDismiss: rebuildIndex) { word in
            WordDetailView(word: word)
                .appThemedColorScheme()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").scaledFont(size: 17)
            TextField("Поиск слова", text: $query)
                .scaledFont(size: 16)
                .foregroundStyle(Color.brandDark)
                .focused($isFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { remember(query) }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle").scaledFont(size: 17)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить")
            }
        }
        .foregroundStyle(Color.brandMuted)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .lxFill(radius: 14)
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            if !recent.isEmpty {
                LXSectionLabel(text: "Недавние запросы")
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                FlowLayout(spacing: 8, centered: false) {
                    ForEach(recent, id: \.self) { item in
                        LXChip(title: item) { query = item }
                    }
                }
                .padding(.horizontal, 16)
            }
            Text("Введите слово на английском или русском. Всего слов: \(index.count.formatted())")
                .scaledFont(size: 14)
                .foregroundStyle(Color.brandMuted)
                .padding(.horizontal, 20)
                .padding(.top, 16)
        } else if results.isEmpty {
            Text("Ничего не найдено")
                .scaledFont(size: 15)
                .foregroundStyle(Color.brandMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
        } else {
            LXSectionLabel(text: "Найдено")
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)
            LazyVStack(spacing: 0) {
                ForEach(results) { word in row(for: word) }
            }
            if results.count == resultLimit {
                Text("Показаны первые \(resultLimit). Уточните запрос.")
                    .scaledFont(size: 13)
                    .foregroundStyle(Color.brandMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
        }
    }

    private func row(for word: Word) -> some View {
        LXWordRow(word: word)
            .onTapGesture {
                remember(query)
                wordToShow = word
            }
            #if DEBUG
            .overlay(alignment: .bottomTrailing) {
                if copiedWordID == word.persistentModelID {
                    Label("CSV-строка скопирована", systemImage: "checkmark")
                        .scaledFont(size: 12, weight: .bold)
                        .foregroundStyle(Color.statusKnown)
                        .padding(.trailing, 16)
                        .padding(.bottom, 4)
                }
            }
            .lxContextMenu {
                Button { copyCSV(of: word) } label: { Label("Скопировать CSV-строку", systemImage: "doc.on.doc") }
            }
            #endif
    }

    #if DEBUG
    private func copyCSV(of word: Word) {
        UIPasteboard.general.string = WordCSVParser.line(for: word)
        copiedWordID = word.persistentModelID
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    #endif
}
