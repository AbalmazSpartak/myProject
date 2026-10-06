import SwiftUI
import SwiftData

struct EditWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var word: Word
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var isConfirmingDelete = false
    /// Удаляем после закрытия окна, чтобы форма не обращалась к уже удалённому слову
    @State private var deleteOnClose = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section(header: Text("Слово и Перевод")) {
                        TextField("Английское слово", text: $word.english).autocapitalization(.none).disableAutocorrection(true)
                        TextField("Транскрипция", text: $word.transcription).autocapitalization(.none).disableAutocorrection(true)
                        TextField("Перевод на русский", text: $word.russian).disableAutocorrection(true)
                    }
                    Section(header: Text("Часть речи и тема")) {
                        TextField("Часть речи (n., v., adj. …)", text: $word.partOfSpeech).autocapitalization(.none).disableAutocorrection(true)
                        Picker("Тема", selection: $word.category) {
                            Text("Без темы").tag(Category?.none)
                            ForEach(categories) { category in
                                Text(category.name).tag(Category?.some(category))
                            }
                        }
                    }
                    Section(header: Text("Контекст"), footer: Text("Изучаемое слово в примере отмечается так: <b>слово</b>")) {
                        TextField("Пример предложения", text: $word.example, axis: .vertical).disableAutocorrection(true)
                    }
                    Section(header: Text("Уровень CEFR")) {
                        Picker("Уровень", selection: $word.cefrLevel) {
                            ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                                Text(level.rawValue).tag(level.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    // Удалить можно только своё слово: слово из базы вернулось бы при обновлении words.csv
                    if word.isCustom {
                        Section {
                            Button("Удалить слово", role: .destructive) { isConfirmingDelete = true }
                        } footer: {
                            Text(word.lists.isEmpty ? "Слово удалится с устройства вместе с прогрессом." : "Слово удалится с устройства и из всех ваших словарей (\(word.lists.count)).")
                        }
                    }
                }
                // Строки — тёплого цвета карточек, а не системного серого
                .listRowBackground(Color.cardBackground)
            }
            .confirmationDialog("Удалить «\(word.english)»?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    deleteOnClose = true
                    dismiss()
                }
            }
            .onDisappear {
                // Могли поменять написание или тему — порядок и счётчики «Словаря» пересчитаются
                WordCache.shared.invalidateDictionaryIndex()
                guard deleteOnClose else { return }
                modelContext.delete(word)
                try? modelContext.save()
            }
            .brandListBackground()
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        word.english = word.english.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.transcription = word.transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.russian = word.russian.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.example = word.example.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.partOfSpeech = word.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .bold()
                    .disabled(word.english.isEmpty || word.russian.isEmpty)
                }
            }
        }
    }
}
