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
                        // Чистим пробелы перед закрытием
                        word.english = word.english.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.russian = word.russian.trimmingCharacters(in: .whitespacesAndNewlines)
                        word.example = word.example.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss() // Закрываем экран, SwiftData сохранит всё автоматически
                    }
                    .bold()
                    .disabled(word.english.isEmpty || word.russian.isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

