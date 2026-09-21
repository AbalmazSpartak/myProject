import SwiftUI
import SwiftData

struct AddWordFormView: View {
    @Environment(\.modelContext) private var modelContext
    var selectedCategory: Category?
    
    @State private var newEnglish = ""
    @State private var newTranscription = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    
    enum Field: Hashable {
        case english, transcription, russian, example
    }
    
    @FocusState private var focusedField: Field?
    
    // Брендовые цвета для интеграции с главным меню
    private let brandDarkColor = Color.brandDark
    
    var body: some View {
        VStack(spacing: 12) {
            // ИСПРАВЛЕНИЕ: Все подсказки обернуты в Text() с темно-серым контрастным цветом
            TextField(text: $newEnglish) {
                Text(focusedField == .english ? "" : "Слово на английском")
                    .foregroundStyle(.black.opacity(0.09)) // Сделали подсказку намного темнее
            }
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded))
            .foregroundColor(brandDarkColor)
            .padding(.vertical, 10)
            .background(Color.brandInputBg)
            .cornerRadius(10)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .focused($focusedField, equals: .english)

            TextField(text: $newTranscription) {
                Text(focusedField == .transcription ? "" : "Транскрипция (необязательно)")
                    .foregroundStyle(.black.opacity(0.09))
            }
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded))
            .foregroundColor(brandDarkColor)
            .padding(.vertical, 10)
            .background(Color.brandInputBg)
            .cornerRadius(10)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .focused($focusedField, equals: .transcription)

            TextField(text: $newRussian) {
                Text(focusedField == .russian ? "" : "Перевод на русский")
                    .foregroundStyle(.black.opacity(0.09))
            }
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded))
            .foregroundColor(brandDarkColor)
            .padding(.vertical, 10)
            .background(Color.brandInputBg)
            .cornerRadius(10)
            .disableAutocorrection(true)
            .focused($focusedField, equals: .russian)

            TextField(text: $newExample) {
                Text(focusedField == .example ? "" : "Пример фразы (необязательно)")
                    .foregroundStyle(.black.opacity(0.09))
            }
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded))
            .foregroundColor(brandDarkColor)
            .padding(.vertical, 10)
            .background(Color.brandInputBg)
            .cornerRadius(10)
            .disableAutocorrection(true)
            .focused($focusedField, equals: .example)

            Button(action: addWord) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(selectedCategory == nil ? "Добавить в Общий" : "Добавить в «\(selectedCategory!.name)»")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(newEnglish.isEmpty || newRussian.isEmpty ? Color.black.opacity(0.06) : Color.orange)
                .foregroundColor(newEnglish.isEmpty || newRussian.isEmpty ? .gray : .white)
                .cornerRadius(14)
            }
            .disabled(newEnglish.isEmpty || newRussian.isEmpty)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 15)
        .onTapGesture { }
    }
    
    private func addWord() {
        focusedField = nil
        
        let eng = newEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        var trans = newTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rus = newRussian.trimmingCharacters(in: .whitespacesAndNewlines)
        let ex = newExample.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
