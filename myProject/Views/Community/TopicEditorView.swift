import SwiftUI
import SwiftData

/// Новая тема или правка своей: раздел (готовый или новый), заголовок, блоки (подзаголовки, текст, таблицы, аудио) и слова
struct TopicEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Разделы на выбор: встроенные и те, где уже есть темы
    let sections: [String]
    /// nil — новая тема
    private let topic: CommunityTopic?

    @State private var section: String
    @State private var newSection = ""
    @State private var title = ""
    @State private var blocks: [TopicBlock] = [TopicBlock(kind: .text)]
    /// Записи и файлы блоков «Аудио» до сохранения — по TopicBlock.audioClipID
    @State private var pendingAudio: [UUID: PendingAudio] = [:]
    @State private var words: [TopicWord] = [TopicWord(english: "", russian: "")]

    /// Значение пикера для «Новый раздел…»
    private static let newSectionTag = "\u{0}new"

    init(sections: [String], editing topic: CommunityTopic? = nil) {
        self.sections = sections
        self.topic = topic
        guard let topic else {
            _section = State(initialValue: sections.first ?? Self.newSectionTag)
            return
        }
        // Правка: всё как сохранено, звук — в черновик, пока не нажали «Сохранить»
        if sections.contains(topic.section) {
            _section = State(initialValue: topic.section)
        } else {
            _section = State(initialValue: Self.newSectionTag)
            _newSection = State(initialValue: topic.section)
        }
        _title = State(initialValue: topic.title)
        var blocks = topic.blocks
        if blocks.isEmpty, !topic.text.isEmpty {
            // Тема первой версии — только текст
            var text = TopicBlock(kind: .text)
            text.text = topic.text
            blocks = [text]
        }
        _blocks = State(initialValue: blocks)
        _pendingAudio = State(initialValue: Dictionary(uniqueKeysWithValues: topic.audioClips.map {
            ($0.id, PendingAudio(data: $0.data, fileExtension: $0.fileExtension))
        }))
        _words = State(initialValue: topic.words.isEmpty ? [TopicWord(english: "", russian: "")] : topic.words)
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
                }

                ForEach($blocks) { $block in
                    Section {
                        blockEditor($block)
                    } header: {
                        blockHeader(block)
                    }
                }

                Section {
                    Menu {
                        ForEach(TopicBlock.Kind.allCases, id: \.self) { kind in
                            Button {
                                blocks.append(TopicBlock(kind: kind))
                            } label: {
                                Label(kind.title, systemImage: kind.icon)
                            }
                        }
                    } label: {
                        Label("Добавить блок", systemImage: "plus.square.on.square")
                    }
                } footer: {
                    Text("Подзаголовок, текст, таблица или аудио — в любом порядке. В тексте и таблицах: **жирный**, *курсив*, ==красный==.")
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
            .onDisappear { AudioClipPlayer.shared.stop() }
            .navigationTitle(topic == nil ? "Новая тема" : "Правка темы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(topic == nil ? "Создать" : "Сохранить") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Блоки

    @ViewBuilder
    private func blockEditor(_ block: Binding<TopicBlock>) -> some View {
        switch block.wrappedValue.kind {
        case .heading:
            TextField("Подзаголовок", text: block.text)
                .font(.headline)
        case .text:
            TextEditor(text: block.text)
                .frame(minHeight: 120)
                .overlay(alignment: .topLeading) {
                    if block.wrappedValue.text.isEmpty {
                        Text("Текст")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
        case .table:
            TopicTableEditor(table: block.table)
        case .audio:
            TopicAudioEditor(block: block, pendingAudio: $pendingAudio)
        }
    }

    /// Вид блока и меню: выше, ниже, удалить
    private func blockHeader(_ block: TopicBlock) -> some View {
        let index = blocks.firstIndex { $0.id == block.id } ?? 0
        return HStack {
            Label(block.kind.title, systemImage: block.kind.icon)
            Spacer()
            Menu {
                Button { moveBlock(at: index, by: -1) } label: { Label("Выше", systemImage: "arrow.up") }
                    .disabled(index == 0)
                Button { moveBlock(at: index, by: 1) } label: { Label("Ниже", systemImage: "arrow.down") }
                    .disabled(index == blocks.count - 1)
                Button(role: .destructive) { deleteBlock(at: index) } label: { Label("Удалить блок", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
            }
            .textCase(nil)
        }
    }

    private func moveBlock(at index: Int, by offset: Int) {
        let target = index + offset
        guard blocks.indices.contains(index), blocks.indices.contains(target) else { return }
        withAnimation { blocks.swapAt(index, target) }
    }

    private func deleteBlock(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        if let clipID = blocks[index].audioClipID { pendingAudio[clipID] = nil }
        AudioClipPlayer.shared.stop()
        withAnimation { _ = blocks.remove(at: index) }
    }

    /// Пустые блоки не сохраняем; у озвучки свой звук не нужен
    private var filledBlocks: [TopicBlock] {
        blocks.compactMap { block in
            var block = block
            block.text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch block.kind {
            case .heading, .text:
                return block.text.isEmpty ? nil : block
            case .table:
                return block.table.cells.joined().allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } ? nil : block
            case .audio:
                if block.audioSource == .speech {
                    block.audioClipID = nil
                    block.speechText = block.speechText.trimmingCharacters(in: .whitespacesAndNewlines)
                    return block.speechText.isEmpty ? nil : block
                }
                return block.audioClipID.flatMap { pendingAudio[$0] } == nil ? nil : block
            }
        }
    }

    private func save() {
        // Раздел с тем же названием, но другим регистром — тот же раздел
        let name = sections.first { $0.caseInsensitiveCompare(resolvedSection) == .orderedSame } ?? resolvedSection
        let topic: CommunityTopic
        if let existing = self.topic {
            topic = existing
            topic.section = name
            topic.title = title.trimmingCharacters(in: .whitespaces)
            topic.setBlocks(filledBlocks)
            topic.words = filledWords
        } else {
            topic = CommunityTopic(section: name,
                                   title: title.trimmingCharacters(in: .whitespaces),
                                   blocks: filledBlocks,
                                   words: filledWords)
            modelContext.insert(topic)
        }
        // Звук: убранный из темы удаляем, новый добавляем, оставшийся не трогаем
        let usedIDs = Set(topic.blocks.compactMap(\.audioClipID))
        for clip in topic.audioClips where !usedIDs.contains(clip.id) {
            modelContext.delete(clip)
        }
        let existingIDs = Set(topic.audioClips.map(\.id))
        for id in usedIDs.subtracting(existingIDs) {
            guard let audio = pendingAudio[id] else { continue }
            let clip = TopicAudioClip(id: id, data: audio.data, fileExtension: audio.fileExtension)
            modelContext.insert(clip)
            clip.topic = topic
        }
        AudioClipPlayer.shared.stop()
        try? modelContext.save()
        dismiss()
    }
}
