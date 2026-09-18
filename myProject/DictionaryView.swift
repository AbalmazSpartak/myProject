import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DictionaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Word.english) private var words: [Word]
    @Binding var currentScreen: String
    
    @State private var newEnglish = ""
    @State private var newRussian = ""
    @State private var newExample = ""
    
    @State private var isImporting = false
    
    enum Field: Hashable {
        case english, russian, example
    }
    
    @FocusState private var focusedField: Field?
    
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
                
                Button(action: { isImporting = true }) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            
            VStack(spacing: 12) {
                TextField(focusedField == .english ? "" : "Слово на английском", text: $newEnglish)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.center)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .english)

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
            .onTapGesture { }
            
            List {
                ForEach(words) { word in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(word.english)
                                .fontWeight(.medium)
                            Spacer()
                            Text(word.russian)
                                .foregroundColor(.gray)
                        }
                        if !word.example.isEmpty {
                            Text(word.example)
                                .font(.caption)
                                .italic()
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                }
                .onDelete(perform: deleteWord)
            }
            .listStyle(PlainListStyle())
            .onTapGesture { focusedField = nil }
        }
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
        )
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let fileURL = urls.first {
                    importWords(from: fileURL)
                }
            case .failure(let error):
                print("Ошибка при выборе файла: \(error.localizedDescription)")
            }
        }
    }
    
    func addWord() {
        focusedField = nil
        
        let eng = newEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
        let rus = newRussian.trimmingCharacters(in: .whitespacesAndNewlines)
        let ex = newExample.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newWord = Word(english: eng, russian: rus, example: ex)
        modelContext.insert(newWord)
        
        newEnglish = ""
        newRussian = ""
        newExample = ""
    }
    
    func deleteWord(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(words[index])
        }
    }
    
    private func importWords(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            let lines = fileContent.components(separatedBy: .newlines)
            var addedCount = 0
            
            for line in lines {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                let parts = line.components(separatedBy: " - ")
                
                if parts.count == 2 {
                    let englishPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let russianPart = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !englishPart.isEmpty && !russianPart.isEmpty {
                        let newWord = Word(english: englishPart, russian: russianPart, example: "")
                        modelContext.insert(newWord)
                        addedCount += 1
                    }
                }
            }
            print("Успешно добавлено слов из файла: \(addedCount)")
        } catch {
            print("Ошибка при чтении файла: \(error.localizedDescription)")
        }
    }
}
