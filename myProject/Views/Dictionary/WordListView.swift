import SwiftUI
import SwiftData

struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var filteredWords: [Word]
    @Binding var editingWord: Word?
    
    private var showCategoryTag: Bool
    private let brandDarkColor = Color(red: 26/255, green: 37/255, blue: 68/255)
    
    init(selectedCategory: Category?, editingWord: Binding<Word?>) {
        self._editingWord = editingWord
        self.showCategoryTag = (selectedCategory == nil)
        let targetCategoryID = selectedCategory?.id ?? UUID()
        let isGeneralDictionary = (selectedCategory == nil)
        
        _filteredWords = Query(filter: #Predicate<Word> { word in
            if isGeneralDictionary { return true } else {
                if let category = word.category { return category.id == targetCategoryID } else { return false }
            }
        }, sort: \Word.english)
    }
    
    var body: some View {
        List {
            ForEach(filteredWords) { word in
                Button(action: { editingWord = word }) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            HStack(spacing: 6) {
                                Text(word.english)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(brandDarkColor)
                                if !word.transcription.isEmpty {
                                    Text(word.transcription)
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Text(word.russian)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        if !word.example.isEmpty {
                            Text(word.example)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .italic()
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        if showCategoryTag, let cat = word.category {
                            Text(cat.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                )
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteWord)
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(red: 247/255, green: 249/255, blue: 253/255))
    }
    
    private func deleteWord(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(filteredWords[index]) }
    }
}
