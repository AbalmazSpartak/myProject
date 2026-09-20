import SwiftUI
import SwiftData

struct EditWordView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var word: Word // Связываем поля напрямую со свойствами SwiftData-модели
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Слово и Перевод")) {
                    TextField("Английское слово", text: $word.english)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Транскрипция", text: $word.transcription)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Перевод на русский", text: $word.russian)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Контекст")) {
                    TextField("Пример предложения", text: $word.example)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        // Очищаем пробелы перед сохранением
                        word.english = word.english.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.transcription = word.transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.russian = word.russian.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.example = word.example.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss() // SwiftData зафиксирует изменения автоматически
                    }
                    .bold()
                    .disabled(word.english.isEmpty || word.russian.isEmpty)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
