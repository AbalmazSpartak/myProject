import SwiftUI
import SwiftData

struct AddWordFormView: View {
    @Environment(\.modelContext) private var modelContext
    var selectedCategory: Category? // Текущая выбранная папка
    
    @State private var newEnglish = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    
    enum Field: Hashable {
        case english, russian, example
    }
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(spacing: 12) {
            // Поле ввода 1: Английское слово
            TextField(focusedField == .english ? "" : "Слово на английском", text: $newEnglish)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .english)

            // Поле ввода 2: Русский перевод
            TextField(focusedField == .russian ? "" : "Перевод на русский", text: $newRussian)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .russian)

            // Поле ввода 3: Пример фразы
            TextField(focusedField == .example ? "" : "Пример фразы (необязательно)", text: $newExample)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .example)

            // Кнопка добавления
            Button(action: addWord) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedCategory == nil ? "Добавить в Общий" : "Добавить в «\(selectedCategory!.name)»")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(newEnglish.isEmpty || newRussian.isEmpty ? Color.gray : Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(newEnglish.isEmpty || newRussian.isEmpty)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 10)
        // Защита: клик по самой форме не закрывает клавиатуру
        .onTapGesture { }
    }
    
    private func addWord() {
        focusedField = nil // Закрываем клавиатуру
        
        let eng = newEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        let rus = newRussian.trimmingCharacters(in: .whitespacesAndNewlines)
        let ex = newExample.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Создаем слово и привязываем к текущей категории
        let newWord = Word(english: eng, russian: rus, example: ex, category: selectedCategory)
        modelContext.insert(newWord)
        
        // Очищаем поля
        newEnglish = ""
        newRussian = ""
        newExample = ""
    }
}
