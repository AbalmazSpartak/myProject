#if DEBUG
import SwiftUI
import SwiftData

struct DeveloperView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allWords: [Word]
    @Query private var categories: [Category]
    @Query private var profiles: [UserProfile]
    
    @State private var daysToShift: Int = 1
    @State private var showConfirmReset = false
    @State private var showConfirmReseed = false
    @State private var showConfirmFSRSReset = false
    @State private var lastActionMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Статус базы") {
                    LabeledContent("Слов всего", value: "\(allWords.count)")
                    LabeledContent("Категорий", value: "\(categories.count)")
                    LabeledContent("Профилей", value: "\(profiles.count)")
                    LabeledContent("Слов на повторении (due)", value: "\(dueWordsCount)")
                    LabeledContent("Слов с ошибками", value: "\(allWords.filter { $0.isMistake }.count)")
                }
                
                Section("Уровни CEFR") {
                    ForEach(CEFRLevel.allCases, id: \.rawValue) { level in
                        LabeledContent(level.rawValue, value: "\(allWords.filter { $0.cefrLevel == level.rawValue }.count)")
                    }
                }
                
                Section(footer: Text("Полностью удаляет слова и категории и заново грузит sample_words.json. Профиль и статистику не трогает.")) {
                    Button("Перезагрузить словарь из JSON") {
                        showConfirmReseed = true
                    }
                }
                
                Section("Эмуляция времени (FSRS)") {
                    Stepper("Сдвинуть dueDate на \(daysToShift) дн. назад", value: $daysToShift, in: 1...60)
                    
                    Button("Применить сдвиг") {
                        shiftDueDates(by: daysToShift)
                    }
                    
                    Button("Сбросить FSRS-прогресс всех слов", role: .destructive) {
                        showConfirmFSRSReset = true
                    }
                }
                
                Section(footer: Text("Удаляет ВСЕ слова, категории и профиль без возможности восстановления.")) {
                    Button("Полный сброс базы", role: .destructive) {
                        showConfirmReset = true
                    }
                }
                
                Section(footer: Text("Добавляет слова-заглушки для проверки прокрутки и фильтров на большом объёме данных. Помечены отдельной категорией «Тестовые данные» — легко удалить одной кнопкой.")) {
                    Button("Добавить 200 тестовых слов") {
                        generateTestWords(count: 200)
                    }
                    
                    Button("Удалить все тестовые слова", role: .destructive) {
                        deleteTestWords()
                    }
                }
                
                if let message = lastActionMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Раздел разработчика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
            .alert("Перезагрузить словарь?", isPresented: $showConfirmReseed) {
                Button("Отмена", role: .cancel) {}
                Button("Перезагрузить", role: .destructive) {
                    DataPreloader.forceReloadFromJSON(context: modelContext)
                    lastActionMessage = "Словарь перезагружен из JSON."
                }
            }
            .alert("Сбросить FSRS у всех слов?", isPresented: $showConfirmFSRSReset) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить", role: .destructive) {
                    resetAllFSRS()
                }
            }
            .alert("Полный сброс базы?", isPresented: $showConfirmReset) {
                Button("Отмена", role: .cancel) {}
                Button("Сбросить всё", role: .destructive) {
                    resetEverything()
                }
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
    }
    
    private var dueWordsCount: Int {
        let now = Date()
        return allWords.filter { $0.state == .new || $0.dueDate <= now }.count
    }
    
    private func shiftDueDates(by days: Int) {
        let interval = TimeInterval(-days * 86400)
        for word in allWords where word.state != .new {
            word.dueDate = word.dueDate.addingTimeInterval(interval)
        }
        try? modelContext.save()
        lastActionMessage = "dueDate сдвинут на \(days) дн. у \(allWords.filter { $0.state != .new }.count) слов."
    }
    
    private func resetAllFSRS() {
        for word in allWords {
            word.state = .new
            word.difficulty = 0
            word.stability = 0
            word.dueDate = Date()
            word.reps = 0
            word.lapses = 0
            word.lastReview = nil
            word.isMistake = false
        }
        try? modelContext.save()
        lastActionMessage = "FSRS-прогресс сброшен у \(allWords.count) слов."
    }
    
    private func resetEverything() {
        for word in allWords { modelContext.delete(word) }
        for category in categories { modelContext.delete(category) }
        for profile in profiles { modelContext.delete(profile) }
        try? modelContext.save()
        lastActionMessage = "База полностью очищена."
    }
    private func generateTestWords(count: Int) {
        let testCategory: Category
        if let existing = categories.first(where: { $0.name == "Тестовые данные" }) {
            testCategory = existing
        } else {
            let newCat = Category(name: "Тестовые данные")
            modelContext.insert(newCat)
            testCategory = newCat
        }
        
        let levels = CEFRLevel.allCases
        let startIndex = allWords.filter { $0.category?.name == "Тестовые данные" }.count
        
        for i in 1...count {
            let n = startIndex + i
            let word = Word(
                english: "testword\(n)",
                russian: "тестслово\(n)",
                transcription: "[test\(n)]",
                example: "This is test sentence number \(n).",
                category: testCategory,
                cefrLevel: levels.randomElement()?.rawValue ?? "A1"
            )
            modelContext.insert(word)
        }
        try? modelContext.save()
        lastActionMessage = "Добавлено \(count) тестовых слов."
    }

    private func deleteTestWords() {
        let testWords = allWords.filter { $0.category?.name == "Тестовые данные" }
        for word in testWords { modelContext.delete(word) }
        
        if let testCategory = categories.first(where: { $0.name == "Тестовые данные" }) {
            modelContext.delete(testCategory)
        }
        try? modelContext.save()
        lastActionMessage = "Тестовые слова удалены."
    }
}
#endif
