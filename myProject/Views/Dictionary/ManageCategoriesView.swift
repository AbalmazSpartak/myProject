import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    
    var body: some View {
        NavigationStack {
            List {
                Group {
                    ForEach(categories) { category in
                        Text(category.name)
                    }
                    .onDelete(perform: deleteCategories)
                }
                // Строки — тёплого цвета карточек, а не системного серого
                .listRowBackground(Color.cardBackground)
            }
            .brandListBackground()
            .navigationTitle("Управление папками")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        // Сразу сохраняем: слова темы удаляются каскадом, и словарь под листом должен их перечитать
        try? modelContext.save()
    }
}
