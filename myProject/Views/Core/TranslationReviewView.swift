#if DEBUG
import SwiftUI
import SwiftData

/// Раздел разработчика → «Проверка перевода словарей»: в своих словарях (из книг, сканов) отдельно слова из базы
/// и новые с автопереводом iOS — чтобы проверить качество перевода новых
struct TranslationReviewView: View {
    @Query(sort: \WordList.createdAt, order: .reverse) private var lists: [WordList]

    var body: some View {
        List {
            if lists.isEmpty {
                Text("Своих словарей пока нет.")
                    .foregroundColor(.gray)
            }
            ForEach(lists) { list in
                NavigationLink {
                    TranslationReviewListView(list: list)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(list.name)
                            .scaledFont(size: 16, weight: .semibold)
                        let newCount = list.words.filter(\.isCustom).count
                        Text("\((list.words.count - newCount).formatted()) из базы · \(newCount.formatted()) новых")
                            .scaledFont(size: 13)
                            .foregroundColor(.gray)
                    }
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Проверка перевода")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Один словарь: «Новые (автоперевод)» / «Из базы»; нажатие — правка слова, CSV новых — через «Поделиться»
private struct TranslationReviewListView: View {
    @Environment(\.modelContext) private var modelContext
    let list: WordList

    @State private var showsNew = true
    @State private var words: [Word] = []
    @State private var wordToEdit: Word?
    @State private var csvURL: URL?

    var body: some View {
        List {
            Section {
                Picker("Слова", selection: $showsNew) {
                    Text("Новые (автоперевод)").tag(true)
                    Text("Из базы").tag(false)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(showsNew
                     ? "Добавлены из текста и переведены переводчиком iOS без учёта контекста. Нажмите на слово, чтобы исправить. Сверху — самые частые в тексте."
                     : "Слова основной базы — перевод проверенный, для сравнения.")
            }
            Section("\(words.count.formatted()) слов") {
                ForEach(words) { word in
                    Button { wordToEdit = word } label: { row(word) }
                        .buttonStyle(.plain)
                }
            }
        }
        .listRowBackground(Color.cardBackground)
        .brandListBackground()
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let csvURL {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: csvURL) {
                        Label("Выгрузить новые в CSV", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .task(id: showsNew) { reload() }
        .task { csvURL = exportNewWords() }
        .sheet(item: $wordToEdit, onDismiss: {
            try? modelContext.save()
            reload()
            csvURL = exportNewWords()
        }) { word in
            EditWordView(word: word)
        }
    }

    private func row(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(word.english)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(.brandDark)
                if !word.partOfSpeech.isEmpty {
                    Text(word.partOfSpeech)
                        .scaledFont(size: 12)
                        .foregroundColor(.gray)
                }
                Spacer()
                if showsNew, let count = list.frequencies[WordList.frequencyKey(word)] {
                    Text("×\(count)")
                        .scaledFont(size: 12)
                        .foregroundColor(.gray)
                }
            }
            Text(word.russian)
                .scaledFont(size: 15)
                .foregroundColor(.brandDark.opacity(0.8))
            if !word.example.isEmpty {
                Text(Self.plain(word.example))
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    /// Новые — по частоте в тексте, из базы — по алфавиту
    private func reload() {
        let all = list.words.filter { !$0.isDeleted && $0.isCustom == showsNew }
        words = showsNew
            ? all.sorted { (list.frequencies[WordList.frequencyKey($0)] ?? 0) > (list.frequencies[WordList.frequencyKey($1)] ?? 0) }
            : all.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
    }

    /// CSV новых слов: слово, часть речи, перевод, пример, сколько раз в тексте
    private func exportNewWords() -> URL? {
        let newWords = list.words.filter { !$0.isDeleted && $0.isCustom }
            .sorted { (list.frequencies[WordList.frequencyKey($0)] ?? 0) > (list.frequencies[WordList.frequencyKey($1)] ?? 0) }
        guard !newWords.isEmpty else { return nil }
        var csv = "Word,PoS,Translation,Example,Count\n"
        for word in newWords {
            let count = list.frequencies[WordList.frequencyKey(word)] ?? 0
            csv += [word.english, word.partOfSpeech, word.russian, word.example, "\(count)"].map(Self.csvField).joined(separator: ",") + "\n"
        }
        let name = list.name.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name) — новые слова.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func csvField(_ value: String) -> String {
        value.contains(where: { ",\"\n".contains($0) }) ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" : value
    }

    private static func plain(_ example: String) -> String {
        example.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "")
    }
}
#endif
