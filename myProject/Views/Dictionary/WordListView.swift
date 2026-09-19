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
        
        // Передаем ID как чистый, неопциональный UUID для точного сравнения внутри SQL-запроса
        let targetCategoryID = selectedCategory?.id ?? UUID()
        let isGeneralDictionary = (selectedCategory == nil)
        
        // Инициализируем Query с безопасной фильтрацией на уровне базы данных без Descendant-свойств
        _filteredWords = Query(filter: #Predicate<Word> { word in
            if isGeneralDictionary {
                return true // Если выбран Общий словарь, показываем все записи без фильтрации
            } else {
                // Сравниваем ID категории напрямую через развернутый опционал — это полностью безопасно для СУБД
                if let category = word.category {
                    return category.id == targetCategoryID
                } else {
                    return false
                }
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
