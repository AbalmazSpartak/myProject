import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var profile: UserProfile
    
    @AppStorage("app_theme") private var selectedTheme: String = "system"
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
    @AppStorage(OverviewLayout.storageKey) private var overviewLayout = OverviewLayout.standard
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(DailyReminder.timeKey) private var reminderTime = DailyReminder.defaultTime
    /// Пользователь запретил уведомления — подсказываем, где их включить
    @State private var notificationsDenied = false

    /// Обучение: перевод, подход, словари, перевод слов из книг — на отдельном экране
    @ViewBuilder
    private var learningLink: some View {
        Section {
            NavigationLink {
                LearningSettingsView()
            } label: {
                Label("Обучение", systemImage: "graduationcap.fill")
            }
        } footer: {
            Text("Раздел, где вы настраиваете занятия: направление перевода, размер подхода, словари, перевод слов из книг.")
                .textSelection(.enabled)
        }
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

                    // Обучение — на отдельном экране, как «Озвучка»; только в «Изучении»
                    if mode == .learning { learningLink }

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
