import SwiftUI
import SwiftData

struct AddWordFormView: View {
    @Environment(\.modelContext) private var modelContext
    var selectedCategory: Category?
    
    @State private var newEnglish = ""
    @State private var newTranscription = "" // Состояние для транскрипции
    @State private var newRussian = ""
    @State private var newExample = ""
    
    enum Field: Hashable {
        case english, transcription, russian, example
    }
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(spacing: 12) {
            TextField(focusedField == .english ? "" : "Слово на английском", text: $newEnglish)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .english)

            // Поле транскрипции (Необязательное)
            TextField(focusedField == .transcription ? "" : "Транскрипция (необязательно)", text: $newTranscription)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .transcription)

            TextField(focusedField == .russian ? "" : "Перевод на русский", text: $newRussian)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .russian)

            TextField(focusedField == .example ? "" : "Пример фразы (необязательно)", text: $newExample)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .example)

            Button(action: addWord) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedCategory == nil ? "Добавить в Общий" : "Добавить в «\(selectedCategory!.name)»")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                // Кнопка зависит только от english и russian fields
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
        .onTapGesture { }
    }
    
    private func addWord() {
        focusedField = nil
        
        let eng = newEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        var trans = newTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rus = newRussian.trimmingCharacters(in: .whitespacesAndNewlines)
        let ex = newExample.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Автоматически оборачиваем в скобки, если пользователь ввел транскрипцию вручную без них
        if !trans.isEmpty && !trans.hasPrefix("[") {
            trans = "[\(trans)]"
        }
        
        let newWord = Word(english: eng, russian: rus, example: ex, transcription: trans, category: selectedCategory)
        modelContext.insert(newWord)
        
        newEnglish = ""
        newTranscription = ""
        newRussian = ""
        newExample = ""
    }
}
