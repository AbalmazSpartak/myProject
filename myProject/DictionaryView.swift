import SwiftUI
import SwiftData

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Word.english) private var words: [Word] // Сортировка по алфавиту
    @Binding var currentScreen: String
    
    @State private var newEnglish = ""
    @State private var newRussian = ""
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { currentScreen = "menu" }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Меню")
                    }
                    .font(.headline)
                }
                Spacer()
                Text("Мой словарь (\(words.count))")
                    .font(.headline)
                    .bold()
                Spacer()
                Text("Меню").opacity(0).font(.headline)
            }
            .padding()
            
            VStack(spacing: 12) {
                TextField("Слово на английском", text: $newEnglish)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                TextField("Перевод на русский", text: $newRussian)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                
                Button(action: addWord) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Добавить в память")
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
            .padding()
            
            List {
                ForEach(words) { word in
                    HStack {
                        Text(word.english)
                            .fontWeight(.medium)
                        Spacer()
                        Text(word.russian)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete(perform: deleteWord)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    func addWord() {
        let eng = newEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        let rus = newRussian.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newWord = Word(english: eng, russian: rus)
        modelContext.insert(newWord) // Сохраняем в базу данных устройства
        
        newEnglish = ""
        newRussian = ""
    }
    
    func deleteWord(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(words[index]) // Удаляем из базы данных устройства
        }
    }
}
