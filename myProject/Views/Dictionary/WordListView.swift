import SwiftUI
import SwiftData

struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var filteredWords: [Word]
    @Binding var editingWord: Word?
    
    private var showCategoryTag: Bool
    
    // Динамический инициализатор формирует высокоэффективный предикат для диска
    init(selectedCategory: Category?, editingWord: Binding<Word?>) {
        self._editingWord = editingWord
        self.showCategoryTag = (selectedCategory == nil)
        
        let categoryID = selectedCategory?.id
        
        // Инициализируем Query с жесткой фильтрацией на уровне базы данных
        _filteredWords = Query(filter: #Predicate<Word> { word in
            if let categoryID = categoryID {
                return word.category?.id == categoryID
            } else {
                return true // Показываем все слова из СУБД без ручного перебора
            }
        }, sort: \Word.english)
    }
    
    var body: some View {
        List {
            ForEach(filteredWords) { word in
                Button(action: { editingWord = word }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(word.english) \(word.transcription)")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
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
                        if showCategoryTag, let cat = word.category {
                            Text(cat.name)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .onDelete(perform: deleteWord)
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteWord(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredWords[index])
        }
    }
}
