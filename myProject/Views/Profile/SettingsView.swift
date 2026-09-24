import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var profile: UserProfile
    
    @AppStorage("app_theme") private var selectedTheme: String = "system"
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    
    @State private var showingResetAlert = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            Form {
                // Личные данные
                Section(header: Text("Личные данные")) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(0.15))
                                .frame(width: 60, height: 60)
                            
                            if let data = profile.avatarData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.teal)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text(profile.avatarData == nil ? "Загрузить фото" : "Изменить фото")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.teal)
                            }
                            
                            if profile.avatarData != nil {
                                Button("Удалить фото", role: .destructive) {
                                    profile.avatarData = nil
                                    selectedPhotoItem = nil
                                }
                                .font(.system(size: 13))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    TextField("Ваше имя", text: $profile.name)
                        .autocorrectionDisabled()
                }
                
                // Обучение
                Section(header: Text("Обучение")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Направление перевода")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Picker("Направление перевода", selection: $translationMode) {
                            Text("Англ ➔ Рус").tag("en_ru")
                            Text("Рус ➔ Англ").tag("ru_en")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }
                
                // Оформление
                Section(header: Text("Оформление")) {
                    Picker("Тема оформления", selection: $selectedTheme) {
                        Text("Системная").tag("system")
                        Text("Светлая").tag("light")
                        Text("Темная").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
                
                // Управление данными
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data),
                           let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                            profile.avatarData = compressedData
                        } else {
                            profile.avatarData = data
                        }
                    }
                }
            }
            .alert("Сброс статистики", isPresented: $showingResetAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сбросить", role: .destructive) {
                    profile.correctAnswers = 0
                    profile.totalAnswers = 0
                }
            } message: {
                Text("Вы уверены, что хотите сбросить статистику? Это действие нельзя отменить.")
            }
        }
    }
}
