import SwiftUI
import SwiftData

/// Словарь → поиск слова по всей базе и его правка
struct WordSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Word.english) private var allWords: [Word]

    @State private var query = ""
    @State private var editingWord: Word?
    #if DEBUG
    @State private var copiedWordID: PersistentIdentifier?
    #endif

    private let resultLimit = 100

    /// Сначала слова, начинающиеся с запроса, затем содержащие его (по английскому и русскому)
    private var results: [Word] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var prefix: [Word] = []
        var contains: [Word] = []
        for word in allWords {
            let english = word.english.lowercased()
            if english.hasPrefix(q) {
                prefix.append(word)
            } else if english.contains(q) || word.russian.lowercased().contains(q) {
                contains.append(word)
            }
        }
        return Array((prefix + contains).prefix(resultLimit))
    }

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Введите слово на английском или русском. Всего слов: \(allWords.count)")
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
            .navigationTitle("Поиск слов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }.bold()
                }
            }
            .sheet(item: $editingWord) { word in
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
            Text("Правка меняет слово только на этом устройстве. Чтобы она не потерялась при перезагрузке словаря, скопируйте CSV-строку (свайп влево) в мастер-базу.")
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
