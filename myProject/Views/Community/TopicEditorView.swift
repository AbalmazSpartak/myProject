import SwiftUI
import SwiftData

/// Новая тема: раздел (готовый или новый), заголовок, текст и слова
struct TopicEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Разделы на выбор: встроенные и те, где уже есть темы
    let sections: [String]

    @State private var section: String
    @State private var newSection = ""
    @State private var title = ""
    @State private var text = ""
    @State private var words: [TopicWord] = [TopicWord(english: "", russian: "")]

    /// Значение пикера для «Новый раздел…»
    private static let newSectionTag = "\u{0}new"

    init(sections: [String]) {
        self.sections = sections
        _section = State(initialValue: sections.first ?? Self.newSectionTag)
    }

    private var resolvedSection: String {
        (section == Self.newSectionTag ? newSection : section).trimmingCharacters(in: .whitespaces)
    }

    private var filledWords: [TopicWord] {
        words.filter {
            !$0.english.trimmingCharacters(in: .whitespaces).isEmpty && !$0.russian.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var canSave: Bool {
        !resolvedSection.isEmpty && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Раздел") {
                    Picker("Раздел", selection: $section) {
                        ForEach(sections, id: \.self) { Text($0).tag($0) }
                        Text("Новый раздел…").tag(Self.newSectionTag)
                    }
                    if section == Self.newSectionTag {
                        TextField("Название, например «Грамматика»", text: $newSection)
                    }
                }

                Section("Тема") {
                    TextField("Заголовок", text: $title)
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Текст темы")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section {
                    ForEach($words) { $word in
                        HStack {
                            TextField("English", text: $word.english)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Divider()
                            TextField("Перевод", text: $word.russian)
                        }
                    }
                    .onDelete { words.remove(atOffsets: $0) }
                    Button {
                        words.append(TopicWord(english: "", russian: ""))
                    } label: {
                        Label("Добавить слово", systemImage: "plus")
                    }
                } header: {
                    Text("Слова")
                } footer: {
                    Text("Необязательно. Читатели темы смогут добавить эти слова себе в словарь. Пустые строки не сохраняются.")
                }
            }
            .brandListBackground()
            .navigationTitle("Новая тема")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Создать") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        // Раздел с тем же названием, но другим регистром — тот же раздел
        let name = sections.first { $0.caseInsensitiveCompare(resolvedSection) == .orderedSame } ?? resolvedSection
        let topic = CommunityTopic(section: name,
                                   title: title.trimmingCharacters(in: .whitespaces),
                                   text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                   words: filledWords)
        modelContext.insert(topic)
        try? modelContext.save()
        dismiss()
    }
}
