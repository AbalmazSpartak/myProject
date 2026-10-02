import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var profile: UserProfile
    
    @AppStorage("app_theme") private var selectedTheme: String = "system"
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    @AppStorage("show_word_images") private var showWordImages: Bool = true
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage(MainMenuLayout.storageKey) private var menuLayout = MainMenuLayout.standard
    @AppStorage(DailyNewWords.limitKey) private var newWordsPerDay = DailyNewWords.defaultLimit
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    @AppStorage(SpeechSettings.accentKey) private var speechAccent = SpeechSettings.defaultAccent
    @AppStorage(SpeechSettings.rateKey) private var speechRate = SpeechSettings.defaultRate
    @AppStorage(SpeechSettings.autoSpeakKey) private var autoSpeak = false
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(DailyReminder.timeKey) private var reminderTime = DailyReminder.defaultTime
    /// Пользователь запретил уведомления — подсказываем, где их включить
    @State private var notificationsDenied = false

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
                                    .scaledFont(size: 30)
                                    .foregroundColor(.teal)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // Подпись PhotosPicker — Sendable-замыкание: профиль читаем заранее
                            let photoButtonTitle = profile.avatarData == nil ? "Загрузить фото" : "Изменить фото"
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text(photoButtonTitle)
                                    .scaledFont(size: 15, weight: .semibold)
                                    .foregroundColor(.teal)
                            }
                            
                            if profile.avatarData != nil {
                                Button("Удалить фото", role: .destructive) {
                                    profile.avatarData = nil
                                    selectedPhotoItem = nil
                                }
                                .scaledFont(size: 13)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    TextField("Ваше имя", text: $profile.name)
                        .autocorrectionDisabled()
                }
                
                // Обучение
                Section(header: Text("Обучение"), footer: Text("Новые слова в «На повторение» идут от простых к сложным, счётчик обнуляется в полночь. После подхода можно продолжить или вернуться в меню.")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Направление перевода")
                            .scaledFont(size: 14)
                            .foregroundColor(.gray)
                        
                        Picker("Направление перевода", selection: $translationMode) {
                            Text("Англ ➔ Рус").tag("en_ru")
                            Text("Рус ➔ Англ").tag("ru_en")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    Toggle("Картинки к словам", isOn: $showWordImages)

                    Picker("Новых слов в день", selection: $newWordsPerDay) {
                        ForEach(DailyNewWords.limitOptions, id: \.self) { limit in
                            Text(limit == 0 ? "Без лимита" : "\(limit)").tag(limit)
                        }
                    }

                    Picker("Слов за подход", selection: $sessionLength) {
                        ForEach(SessionLength.options, id: \.self) { length in
                            Text(length == 0 ? "Все" : "\(length)").tag(length)
                        }
                    }

                    NavigationLink {
                        StudyDictionariesView()
                    } label: {
                        LabeledContent("Словари", value: studyScope.isEverythingEnabled ? "Все" : "Выбранные")
                    }
                }
                
                // Озвучка
                Section(header: Text("Озвучка"), footer: Text("При переводе с русского на английский слово звучит после ответа, чтобы не подсказывать.")) {
                    Picker("Акцент", selection: $speechAccent) {
                        Text("Американский").tag("en-US")
                        Text("Британский").tag("en-GB")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Скорость речи")
                        Slider(value: $speechRate, in: SpeechSettings.rateRange) {
                            Text("Скорость речи")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise.fill").foregroundColor(.gray)
                        } maximumValueLabel: {
                            Image(systemName: "hare.fill").foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Озвучивать слово сразу", isOn: $autoSpeak)

                    Button {
                        TextToSpeechManager.shared.speak("Hello! This is how English words will sound.")
                    } label: {
                        Label("Прослушать", systemImage: "speaker.wave.2.fill")
                    }
                }

                // Напоминание
                Section {
                    Toggle("Напоминать заниматься", isOn: Binding(get: { reminderEnabled }, set: setReminder))
                    if reminderEnabled {
                        DatePicker("Время", selection: reminderDate, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Напоминание")
                } footer: {
                    Text(notificationsDenied
                         ? "Уведомления запрещены — включите их в Настройках iPhone → WordLearner → Уведомления."
                         : "Раз в день, без спешки и счётчиков — просто повод уделить словам пару минут.")
                }

                // Оформление
                Section(header: Text("Оформление")) {
                    // Выбор темы вернётся вместе с тёмной палитрой «журнала»; пока приложение всегда светлое
                    NavigationLink {
                        MainMenuSettingsView()
                    } label: {
                        LabeledContent("Главное меню", value: menuLayout == .standard ? "Стандартное" : "Настроено")
                    }
                }
                #if DEBUG
                Section {
                    NavigationLink("🛠️ Раздел разработчика") {
                        DeveloperView()
                    }
                }
                #endif
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
            .brandListBackground()
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
                        await MainActor.run {
                            if let uiImage = UIImage(data: data),
                               let compressedData = uiImage.jpegData(compressionQuality: 0.7) {
                                profile.avatarData = compressedData
                            } else {
                                profile.avatarData = data
                            }
                        }
                    }
                }
            }
            .alert("Сброс статистики", isPresented: $showingResetAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Сбросить", role: .destructive) {
                    profile.flashcardsEnRuCorrect = 0
                    profile.flashcardsEnRuTotal = 0
                    profile.flashcardsRuEnCorrect = 0
                    profile.flashcardsRuEnTotal = 0
                    profile.quizEnRuCorrect = 0
                    profile.quizEnRuTotal = 0
                    profile.quizRuEnCorrect = 0
                    profile.quizRuEnTotal = 0
                }
            } message: {
                Text("Вы уверены, что хотите сбросить всю детализированную статистику? Это действие нельзя отменить.")
            }
        }
    }

    // MARK: - Напоминание

    private func setReminder(_ isOn: Bool) {
        guard isOn else {
            reminderEnabled = false
            DailyReminder.cancel()
            return
        }
        Task {
            if await DailyReminder.requestAuthorization() {
                notificationsDenied = false
                reminderEnabled = true
                DailyReminder.schedule(at: reminderTime)
            } else {
                notificationsDenied = true
                reminderEnabled = false
            }
        }
    }

    /// Время напоминания для DatePicker; при смене — переставляем уведомления
    private var reminderDate: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(reminderTime)) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderTime = (parts.hour ?? 19) * 3600 + (parts.minute ?? 0) * 60
                DailyReminder.schedule(at: reminderTime)
            }
        )
    }
}
