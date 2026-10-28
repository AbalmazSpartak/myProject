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
    @AppStorage(BookWordsAI.choiceKey) private var bookWordsTranslator = ""
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
    @AppStorage(NeuralVoice.booksKey) private var neuralReadsBooks = true
    @State private var neuralVoice = NeuralVoice.shared
    @State private var kokoroML = KokoroML.shared

    private var neuralVoiceSummary: String {
        NeuralVoice.isInstalled ? "скачан" : "не скачан"
    }
    /// Скачан хоть один нейроголос — Kokoro (процессор или нейроядро) или Piper
    private var hasNeuralVoice: Bool {
        neuralVoice.phase == .ready || kokoroML.isReady
            || neuralVoice.piperPhase("en") == .ready || neuralVoice.piperPhase("ru") == .ready
    }
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(DailyReminder.timeKey) private var reminderTime = DailyReminder.defaultTime
    /// Пользователь запретил уведомления — подсказываем, где их включить
    @State private var notificationsDenied = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isChoosingAvatar = false
    
    /// Имя и фото — только в «Изучении»
    @ViewBuilder
    private var personalSection: some View {
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
    
    }

    /// Озвучка
    @ViewBuilder
    private var voiceSection: some View {
        Section(header: Text("Озвучка"), footer: Text(mode == .learning
                                                      ? "При переводе с русского на английский слово звучит после ответа, чтобы не подсказывать. Если скачан нейросетевой голос Kokoro, слова озвучивает он (голос выбирается на его экране), а акцент и голос выше — для обычного голоса."
                                                      : "Акцент, голос и скорость — для английских книг. Книги на других языках читает голос своего языка.")) {
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

            SpeechRateSlider(rate: $speechRate)

            if mode == .learning {
                Toggle("Озвучивать слово сразу", isOn: $autoSpeak)
            }

            Button {
                TextToSpeechManager.shared.speak("Hello! This is how English words will sound.")
            } label: {
                Label("Прослушать", systemImage: "speaker.wave.2.fill")
            }
        }
    }

    /// Нейроголос: экран со скачиванием и выбором голосов, а «Читать книги этим голосом» — здесь, на виду
    @ViewBuilder
    private var neuralSection: some View {
        Section {
            NavigationLink {
                NeuralVoiceSettingsView()
            } label: {
                LabeledContent("Нейросетевой голос", value: neuralVoiceSummary)
            }

            Toggle("Читать книги этим голосом", isOn: $neuralReadsBooks)

            if neuralReadsBooks && !hasNeuralVoice {
                Label("Чтобы заработало, откройте «Нейросетевой голос» и скачайте голос. Пока его нет, книги читает обычный голос iPhone.",
                      systemImage: "info.circle")
                    .scaledFont(size: 14)
                    .foregroundColor(.orange)
            }
        } footer: {
            Text("Включено — книги читает нейросетевой голос (Kokoro или Piper), если он скачан. Выключено — обычный голос iPhone с акцентом, голосом и скоростью из «Озвучки». Нейроголос тратит больше заряда.")
        }
    }

    /// Выбор режима приложения
    @ViewBuilder
    private var modeSection: some View {
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
    }

    /// Тема и вид «Обзора»
    @ViewBuilder
    private var appearanceSection: some View {
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
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    // В каждом режиме свой порядок: «Изучение» — личное и озвучка, «Чтение» — оформление и режим сверху
                    if mode == .learning {
                        personalSection
                        voiceSection
                        neuralSection
                        modeSection
                        appearanceSection
                    } else {
                        appearanceSection
                        modeSection
                        voiceSection
                        neuralSection
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

                    // ИИ-подсказки и перевод слов из книг — для изучения; в «Чтении» спрятаны и выключены
                    if mode == .learning {
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

                        Section {
                            Picker("Слова из книг", selection: $bookWordsTranslator) {
                                Text("Спрашивать").tag("")
                                Text("ИИ").tag("ai")
                                Text("Встроенный").tag("apple")
                            }
                        } footer: {
                            Text("Перевод новых слов, когда словарь создаётся из книги или файла. ИИ переводит в значении из предложения и понимает диалект; нужен интернет, слово и предложение уходят на сервер WordLearner без имени и почты.")
                        }
                    }

                    // Напоминание
                    Section {
                        Toggle(mode == .learning ? "Напоминать заниматься" : "Напоминать о чтении",
                               isOn: Binding(get: { reminderEnabled }, set: setReminder))
                        if reminderEnabled {
                            DatePicker("Время", selection: reminderDate, displayedComponents: .hourAndMinute)
                        }
                    } header: {
                        Text("Напоминание")
                    } footer: {
                        Text(notificationsDenied
                             ? "Уведомления запрещены — включите их в Настройках iPhone → WordLearner → Уведомления."
                             : mode == .learning
                             ? "Раз в день, без спешки и счётчиков — просто повод уделить словам пару минут."
                             : "Раз в день, без спешки — просто повод почитать пару страниц.")
                    }

                    if mode == .learning {
                        Section {
                            Toggle("Помогать улучшать словарь", isOn: $improveDictionary)
                        } footer: {
                            Text("Анонимно, без имени и почты: ваши правки слов из встроенного словаря, слова, добавленные из книг (с предложением), и слова, которые долго не запоминаются. По ним исправляются переводы для всех.")
                        }
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
