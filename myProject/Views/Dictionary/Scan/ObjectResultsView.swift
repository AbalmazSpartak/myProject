import SwiftUI
import SwiftData
@preconcurrency import Translation

/// «Предмет»: догадки распознавателя о том, что на фото, — выбрать слова и сохранить в словарь.
/// Слово из базы — со своим переводом и прогрессом; новому слову перевод подставляет переводчик iOS, а картинкой карточки становится это фото
struct ObjectResultsView: View {
    let guesses: [ObjectGuess]
    /// Фото предмета для ленты словаря
    let photo: Data
    var onSave: (WordList) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var lists: [WordList]

    @State private var listName = "Предметы"
    @State private var selected: Set<String>
    @State private var existing: [String: Word] = [:]
    @State private var translations: [String: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var isTranslating = false

    /// Новых слов нет в базе, поэтому скорее всего они реже встречаются — как у слов из скана текста
    private let newWordLevel = CEFRLevel.c1.rawValue

    init(guesses: [ObjectGuess], photo: Data, onSave: @escaping (WordList) -> Void) {
        self.guesses = guesses
        self.photo = photo
        self.onSave = onSave
        // Отмечена самая уверенная догадка — остальные часто про фон или материал
        _selected = State(initialValue: Set(guesses.prefix(1).map(\.id)))
    }

    private var newGuesses: [ObjectGuess] {
        guesses.filter { existing[$0.id] == nil }
    }

    private var canSave: Bool {
        !selected.isEmpty && !isTranslating && !listName.trimmingCharacters(in: .whitespaces).isEmpty
            && guesses.filter { selected.contains($0.id) }.allSatisfy { existing[$0.id] != nil || !translation(for: $0).isEmpty }
    }

    var body: some View {
        List {
            Group {
                Section {
                    if let image = UIImage(data: photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                Section {
                    ForEach(guesses) { row($0) }
                } header: {
                    Text("Что на фото")
                } footer: {
                    Text(isTranslating
                         ? "Перевожу встроенным переводчиком iOS…"
                         : "Распознаватель iOS угадывает предмет и иногда ошибается — отметьте то, что действительно на фото. У новых слов это фото станет картинкой на карточке.")
                }
                Section {
                    TextField("Название", text: $listName)
                } header: {
                    Text("Словарь")
                } footer: {
                    Text(existingList.map { "Слова добавятся в «\($0.name)» (\($0.words.count) сейчас), фото — в его ленту." }
                         ?? "Будет создан новый словарь, фото сохранится в нём.")
                }
            }
            .listRowBackground(Color.cardBackground)
        }
        .brandListBackground()
        .navigationTitle("Предмет")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить (\(selected.count))", action: save)
                    .bold()
                    .disabled(!canSave)
            }
        }
        .translationTask(translationConfig) { session in
            await translate(with: session)
        }
        .onAppear {
            guard existing.isEmpty else { return }
            existing = Self.match(guesses, in: modelContext.fetchAllWords())
            if !newGuesses.isEmpty, translationConfig == nil {
                translationConfig = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                                     target: Locale.Language(identifier: "ru"))
            }
        }
    }

    // MARK: - Строки

    private func row(_ guess: ObjectGuess) -> some View {
        let isOn = selected.contains(guess.id)
        let word = existing[guess.id]
        return HStack(alignment: .top, spacing: 12) {
            Button {
                selected.formSymmetricDifference([guess.id])
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 22)
                    .foregroundStyle(isOn ? Color.teal : Color.gray.opacity(0.5))
            }
            .buttonStyle(.borderless)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(word?.english ?? guess.english).font(.headline)
                    Text(guess.isConfident ? "уверенно" : "возможно")
                        .font(.caption.bold())
                        .foregroundStyle(guess.isConfident ? .green : .orange)
                }
                if let word {
                    Text(word.russian).foregroundStyle(.secondary)
                } else {
                    TextField(isTranslating ? "переводится…" : "перевод", text: translationBinding(for: guess))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let word {
                Text(word.cefrLevel)
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
            } else {
                Text("новое")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Слово базы с тем же написанием; из нескольких значений — существительное
    private static func match(_ guesses: [ObjectGuess], in words: [Word]) -> [String: Word] {
        let index = Dictionary(grouping: words) { $0.english.lowercased() }
        var result: [String: Word] = [:]
        for guess in guesses {
            guard let matches = index[guess.english.lowercased()] else { continue }
            result[guess.id] = matches.first { $0.partOfSpeech == "n." } ?? matches.first
        }
        return result
    }

    // MARK: - Перевод

    private func translation(for guess: ObjectGuess) -> String {
        (translations[guess.id] ?? "").trimmingCharacters(in: .whitespaces)
    }

    private func translationBinding(for guess: ObjectGuess) -> Binding<String> {
        Binding(get: { translations[guess.id] ?? "" }, set: { translations[guess.id] = $0 })
    }

    private func translate(with session: TranslationSession) async {
        isTranslating = true
        defer { isTranslating = false }
        let requests = Self.requests(newGuesses.map { (id: $0.id, text: $0.english) })
        guard let responses = try? await session.translations(from: requests) else { return }
        for response in responses {
            guard let id = response.clientIdentifier, (translations[id] ?? "").isEmpty else { continue }
            translations[id] = ScanResultsView.cleanedTranslation(response.targetText)
        }
    }

    /// Запросы собираем вне главного потока: так Swift 6 разрешает передать их в переводчик
    nonisolated private static func requests(_ sources: [(id: String, text: String)]) -> [TranslationSession.Request] {
        sources.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id) }
    }

    // MARK: - Сохранение

    private var existingList: WordList? {
        let name = listName.trimmingCharacters(in: .whitespaces)
        return lists.first { $0.name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(name) == .orderedSame }
    }

    private func save() {
        let list = WordList.named(listName, context: modelContext)
        list.addPhoto(photo)
        let picture = ScanPhoto.jpeg(from: photo, maxSide: ScanPhoto.wordImageSide)
        for guess in guesses where selected.contains(guess.id) {
            if let word = existing[guess.id] {
                if !word.lists.contains(where: { $0.id == list.id }) { word.lists.append(list) }
            } else {
                let word = Word(english: guess.english, russian: translation(for: guess), cefrLevel: newWordLevel,
                                partOfSpeech: "n.", isCustom: true)
                word.imageData = picture
                modelContext.insert(word)
                word.lists.append(list)
            }
        }
        try? modelContext.save()
        onSave(list)
    }
}
