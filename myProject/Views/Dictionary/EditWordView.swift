import SwiftUI
import SwiftData

struct EditWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var word: Word
    @Query(sort: \Category.name) private var categories: [Category]

    var body: some View {
        NavigationStack {
            Form {
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
            }
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
