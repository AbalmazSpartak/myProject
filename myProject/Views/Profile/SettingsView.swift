import SwiftUI
import SwiftData

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
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(DailyReminder.timeKey) private var reminderTime = DailyReminder.defaultTime
    /// Пользователь запретил уведомления — подсказываем, где их включить
    @State private var notificationsDenied = false
    @AppStorage(ReaderSelectionPanel.systemTranslatorKey) private var selectionSystemTranslator = false

    private func note(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 12)
            .foregroundColor(.gray)
            .textSelection(.enabled)
    }

    /// Озвучка и нейросетевой голос — на отдельном экране
    @ViewBuilder
    private var speechLink: some View {
        Section {
            NavigationLink {
                SpeechSettingsView(mode: mode)
            } label: {
                Label("Озвучка", systemImage: "speaker.wave.2.fill")
            }
        } footer: {
            Text("Раздел, где вы настраиваете, как приложение произносит слова и читает книги вслух.")
                .textSelection(.enabled)
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
                .textSelection(.enabled)
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
                        speechLink
                        modeSection
                        appearanceSection
                    } else {
                        appearanceSection
                        modeSection
                        speechLink
                    }

                    // Обучение
                    if mode == .learning {
                        Section(header: Text("Обучение"), footer: Text("Новые слова в «На повторение» идут от простых к сложным, счётчик обнуляется в полночь. После подхода можно продолжить или вернуться в меню.").textSelection(.enabled)) {
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

                    // Перевод слов из книг: всё в одном разделе, только в «Изучении»; в «Чтении» разбора слов нет, раздел спрятан
                    if mode == .learning {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Переводчик iOS для выделенных слов", isOn: $selectionSystemTranslator)
                            note("По умолчанию слово, выделенное в книге, переводится из словаря приложения. Если включить, в панели выделения появится кнопка «Перевести»: встроенный переводчик iOS. Он переводит слово без контекста и иногда ошибается, например, «do» → «вечеринка».")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                                Toggle("ИИ-подсказки", isOn: $aiHints)
                                if aiHints {
                                    Picker("Подсказка", selection: $aiHintsQuality) {
                                        ForEach(CloudContext.Quality.allCases, id: \.self) { quality in
                                            Text(quality.title).tag(quality.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                note(aiHints
                                     ? "Кнопка «Значение в этом предложении» в карточке слова в читалке. Слово и предложение уходят на сервер WordLearner (ИИ Claude), без имени и почты. Обычная — быстрая; более точная — точнее подбирает значение и тратит 3 подсказки из дневного запаса вместо одной. Где есть Apple Intelligence, значение показывается сразу и бесплатно."
                                     : "Перевод слова именно в этом предложении — в карточке слова в читалке.")
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Picker("Слова из книг", selection: $bookWordsTranslator) {
                                    Text("Спрашивать").tag("")
                                    Text("ИИ").tag("ai")
                                    Text("Встроенный").tag("apple")
                                }
                                note("Перевод новых слов, когда словарь создаётся из книги или файла. ИИ переводит в значении из предложения и понимает диалект; нужен интернет, слово и предложение уходят на сервер WordLearner без имени и почты.")
                            }
                    } header: {
                        Text("Перевод слов из книг")
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
                            .textSelection(.enabled)
                    }

                    if mode == .learning {
                        Section {
                            Toggle("Помогать улучшать словарь", isOn: $improveDictionary)
                        } footer: {
                            Text("Анонимно, без имени и почты: ваши правки слов из встроенного словаря, слова, добавленные из книг (с предложением), и слова, которые долго не запоминаются. По ним исправляются переводы для всех.")
                                .textSelection(.enabled)
                        }
                    }

                    // Аккаунт
                    Section {
                        NavigationLink {
                            AccountView()
                        } label: {
                            HStack {
                                Label("Аккаунт", systemImage: "person.crop.circle")
                                Spacer()
                                Text(Account.shared.email ?? "Войти").foregroundColor(.gray)
                            }
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
