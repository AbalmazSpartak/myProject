import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var profile: UserProfile
    
    @AppStorage("app_theme") private var selectedTheme: String = "system"
    @AppStorage("translation_mode") private var translationMode: String = "en_ru"
    @AppStorage("show_word_images") private var showWordImages: Bool = true
    @AppStorage(DictionarySignals.enabledKey) private var improveDictionary = true
    @AppStorage(CloudContext.enabledKey) private var aiHints = false
    @AppStorage(CloudContext.qualityKey) private var aiHintsQuality = CloudContext.Quality.normal.rawValue
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.askKey) private var asksMode = false

    /// Третий вариант «Спрашивать» — режим остаётся прежним, а при запуске появляется выбор
    private var modeChoice: Binding<String> {
        Binding(get: { asksMode ? "ask" : mode.rawValue },
                set: { value in
                    asksMode = value == "ask"
                    if let chosen = AppMode(rawValue: value) { mode = chosen }
                })
    }
    @AppStorage(Haptics.enabledKey) private var hapticsEnabled = true
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage(OverviewLayout.storageKey) private var overviewLayout = OverviewLayout.standard
    @AppStorage(SessionLength.key) private var sessionLength = SessionLength.defaultValue
    @AppStorage(SpeechSettings.accentKey) private var speechAccent = SpeechSettings.defaultAccent
    @AppStorage(SpeechSettings.voiceKey) private var speechVoice = ""
    @AppStorage(SpeechSettings.rateKey) private var speechRate = SpeechSettings.defaultRate
    @AppStorage(SpeechSettings.autoSpeakKey) private var autoSpeak = false
    @AppStorage(NeuralVoice.enabledKey) private var neuralVoiceEnabled = false

    private var neuralVoiceSummary: String {
        NeuralVoice.isInstalled ? (neuralVoiceEnabled ? "включён" : "выключен") : "не скачан"
    }
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(DailyReminder.timeKey) private var reminderTime = DailyReminder.defaultTime
    /// Пользователь запретил уведомления — подсказываем, где их включить
    @State private var notificationsDenied = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isChoosingAvatar = false
    
    var body: some View {
        NavigationStack {
            Form {
                Group {
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
                                .buttonStyle(.borderless)

                                Button("Выбрать аватарку") { isChoosingAvatar = true }
                                    .scaledFont(size: 15, weight: .semibold)
                                    .foregroundColor(.teal)
                                    .buttonStyle(.borderless)
                            
                                if profile.avatarData != nil {
                                    Button("Удалить фото", role: .destructive) {
                                        profile.avatarData = nil
                                        selectedPhotoItem = nil
                                    }
                                    .scaledFont(size: 13)
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    
                        TextField("Ваше имя", text: $profile.name)
                            .autocorrectionDisabled()
                    }
                
                    Section {
                        Picker("Режим", selection: modeChoice) {
                            ForEach(AppMode.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                            Text("Спрашивать").tag("ask")
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Режим")
                    } footer: {
                        Text(asksMode
                             ? "При каждом запуске приложение спросит, что открыть: изучение слов или читалку."
                             : mode == .learning
                             ? "Слова, повторения, тренировки, игры и книги."
                             : "Только библиотека и читалка. Слова и прогресс сохраняются — вернуть «Изучение» можно в любой момент.")
                    }

                    // Оформление — сразу после личных данных: тема и вид «Обзора»
                    Section(header: Text("Оформление")) {
                        Picker("Тема оформления", selection: $selectedTheme) {
                            Text("Системная").tag("system")
                            Text("Светлая").tag("light")
                            Text("Тёмная").tag("dark")
                        }
                        .pickerStyle(.segmented)

                        if mode == .learning {
                            NavigationLink {
                                OverviewSettingsView()
                            } label: {
                                LabeledContent("Обзор", value: overviewLayout == .standard ? "Стандартный" : "Настроен")
                            }
                        }
                    }

                    // Обучение
                    if mode == .learning {
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

                            Toggle("Вибрация", isOn: $hapticsEnabled)

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
                    }

                    Section {
                        Toggle("ИИ-подсказки", isOn: $aiHints)
                        if aiHints {
                            Picker("Подсказка", selection: $aiHintsQuality) {
                                ForEach(CloudContext.Quality.allCases, id: \.self) { quality in
                                    Text(quality.title).tag(quality.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    } footer: {
                        Text(aiHints
                             ? "Кнопка «Значение в этом предложении» в карточке слова в читалке. Слово и предложение уходят на сервер WordLearner (ИИ Claude), без имени и почты. Обычная — быстрая; более точная — точнее подбирает значение и тратит 3 подсказки из дневного запаса вместо одной. Где есть Apple Intelligence, значение показывается сразу и бесплатно."
                             : "Перевод слова именно в этом предложении — в карточке слова в читалке.")
                    }

                    // Озвучка
                    Section(header: Text("Озвучка"), footer: Text("При переводе с русского на английский слово звучит после ответа, чтобы не подсказывать.")) {
                        Picker("Акцент", selection: $speechAccent) {
                            Text("Американский").tag("en-US")
                            Text("Британский").tag("en-GB")
                        }
                        .pickerStyle(.segmented)

                        NavigationLink {
                            VoicePickerView()
                        } label: {
                            LabeledContent("Голос", value: VoiceSummary.current(accent: speechAccent, voiceID: speechVoice))
                        }

                        NavigationLink {
                            NeuralVoiceSettingsView()
                        } label: {
                            LabeledContent("Нейросетевой голос", value: neuralVoiceSummary)
                        }

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

                    Section {
                        Toggle("Помогать улучшать словарь", isOn: $improveDictionary)
                    } footer: {
                        Text("Анонимно, без имени и почты: ваши правки слов из встроенного словаря, слова, добавленные из книг (с предложением), и слова, которые долго не запоминаются. По ним исправляются переводы для всех.")
                    }

                    // Резервная копия
                    BackupSection()
                    #if DEBUG
                    Section {
                        NavigationLink("🛠️ Раздел разработчика") {
                            DeveloperView()
                        }
                    }
                    #endif
                }
                // Строки — тёплого цвета карточек, а не системного серого
                .listRowBackground(Color.cardBackground)
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
            .sheet(isPresented: $isChoosingAvatar) {
                AvatarPickerView(name: profile.name) { data in
                    profile.avatarData = data
                    selectedPhotoItem = nil
                }
                .appThemedColorScheme()
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
