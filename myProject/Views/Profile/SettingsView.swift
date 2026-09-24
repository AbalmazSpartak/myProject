import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Используем Bindable для автоматического сохранения изменений в SwiftData
    @Bindable var profile: UserProfile
    
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Личные данные")) {
                    TextField("Ваше имя", text: $profile.name)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Управление данными"), footer: Text("Сброс статистики удалит информацию о пройденных тестах и проценте правильных ответов. Ваши слова в словаре останутся нетронутыми.")) {
                    Button(role: .destructive, action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Text("Сбросить статистику")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Сброс статистики", isPresented: $showingResetAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сбросить", role: .destructive) {
                    // Обнуляем статистику
                    profile.correctAnswers = 0
                    profile.totalAnswers = 0
                }
            } message: {
                Text("Вы уверены, что хотите сбросить статистику? Это действие нельзя отменить.")
            }
        }
    }
}
