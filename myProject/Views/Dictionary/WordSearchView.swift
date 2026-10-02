import SwiftUI
import SwiftData

/// Словарь → поиск слова по всей базе и его правка
struct WordSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var query = ""
    @State private var results: [Word] = []
    @State private var index: [SearchEntry] = []
    @State private var editingWord: Word?
    #if DEBUG
    @State private var copiedWordID: PersistentIdentifier?
    #endif

    private let resultLimit = 100

    /// Слово с заранее приведёнными к нижнему регистру полями — чтобы не делать это на каждое нажатие клавиши
    private struct SearchEntry {
        let word: Word
        let english: String
        let russian: String
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "ё", with: "е")
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

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Введите слово на английском или русском. Всего слов: \(index.count)")
                        .foregroundStyle(.secondary)
                } else if results.isEmpty {
                    Text("Ничего не найдено")
                        .foregroundStyle(.secondary)
                } else {
                    Section(footer: footer) {
                        ForEach(results) { word in
                            row(for: word)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск слова")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .brandListBackground()
            .navigationTitle("Поиск слов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }.bold()
                }
            }
            .onChange(of: query) { updateResults() }
            .task { rebuildIndex() }
            // Слово могли удалить в правке — перестраиваем список, чтобы не показать удалённое
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in rebuildIndex() }
            .sheet(item: $editingWord, onDismiss: rebuildIndex) { word in
                EditWordView(word: word)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if results.count == resultLimit {
            Text("Показаны первые \(resultLimit). Уточните запрос.")
        } else {
            #if DEBUG
            Text("Правка меняет слово только на этом устройстве. Чтобы она не потерялась при обновлении words.csv, скопируйте CSV-строку (свайп влево) в мастер-базу.")
            #endif
        }
    }

    private func row(for word: Word) -> some View {
        Button { editingWord = word } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(word.english).font(.headline).foregroundStyle(.primary)
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech).font(.subheadline).italic().foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(word.cefrLevel).font(.caption.bold()).foregroundStyle(.indigo)
                }
                Text(word.russian).font(.subheadline).foregroundStyle(.secondary)
                if !word.example.isEmpty {
                    Text(word.attributedExample).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                #if DEBUG
                if copiedWordID == word.persistentModelID {
                    Label("CSV-строка скопирована", systemImage: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
                #endif
            }
        }
        #if DEBUG
        .swipeActions(edge: .trailing) {
            Button { copyCSV(of: word) } label: {
                Label("CSV", systemImage: "doc.on.doc")
            }
            .tint(.teal)
        }
        .contextMenu {
            Button { editingWord = word } label: { Label("Редактировать", systemImage: "pencil") }
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
