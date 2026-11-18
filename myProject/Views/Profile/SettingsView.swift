import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var profile: UserProfile
    
    @AppStorage("app_theme") private var selectedTheme: String = "system"
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.askKey) private var asksMode = false
    @AppStorage(AppPalette.accentKey) private var storedAccent = ""
    @AppStorage(AppPalette.buttonKey) private var storedButton = ""
    @AppStorage(AppPalette.backgroundKey) private var storedBackground = ""
    @State private var pickedAccent: AppPalette.Accent?
    @State private var pickedButton: AppPalette.Accent?
    @State private var pickedBackground: AppPalette.Background?
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false

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
            Toggle("Только читалка", isOn: Binding(get: { readerOnly },
                                                   set: { readerOnly = $0; if $0 { mode = .reading } }))
            if !readerOnly {
                Picker("Режим", selection: modeChoice) {
                    ForEach(AppMode.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                    Text("Спрашивать").tag("ask")
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text("Режим")
        } footer: {
            Text(readerOnly
                 ? "Приложение работает как читалка: библиотека, аудио и закладки. Раздел «Обучение» и переключатель режимов скрыты, слова и прогресс сохраняются."
                 : asksMode
                 ? "При каждом запуске приложение спросит, что открыть: изучение слов или читалку."
                 : mode == .learning
                 ? "Слова, повторения, тренировки, игры и книги."
                 : "Только библиотека и читалка. Слова и прогресс сохраняются — вернуть «Изучение» можно в любой момент.")
                .textSelection(.enabled)
        }
    }

    private var shownAccent: AppPalette.Accent { pickedAccent ?? AppPalette.accent }
    private var shownButton: AppPalette.Accent { pickedButton ?? (storedButton.isEmpty ? shownAccent : AppPalette.button) }
    private var shownBackground: AppPalette.Background { pickedBackground ?? AppPalette.background }
    private var hasPaletteChanges: Bool {
        shownAccent != AppPalette.accent || shownButton != (storedButton.isEmpty ? AppPalette.accent : AppPalette.button) || shownBackground != AppPalette.background
    }

    /// Готовые цвета: основной, кнопок и фон. Применяются кнопкой — приложение перестраивается целиком
    @ViewBuilder
    private var paletteSection: some View {
        Section {
            // Пока кнопки не выбирали отдельно, они идут за основным цветом
            swatchRow("Основной цвет", selection: Binding(get: { shownAccent }, set: { pickedAccent = $0 }))
            swatchRow("Цвет кнопок", selection: Binding(get: { shownButton }, set: { pickedButton = $0 }))
            VStack(alignment: .leading, spacing: 10) {
                Text("Цвет фона")
                HStack(spacing: 14) {
                    ForEach(AppPalette.Background.allCases) { item in
                        let isOn = shownBackground == item
                        Button { pickedBackground = item } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(UIColor(red: CGFloat(item.bg.0 >> 16 & 0xFF) / 255, green: CGFloat(item.bg.0 >> 8 & 0xFF) / 255, blue: CGFloat(item.bg.0 & 0xFF) / 255, alpha: 1)))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(isOn ? Color.brandTint : Color.brandBorder, lineWidth: isOn ? 3 : 1))
                                Text(item.title).scaledFont(size: 11).foregroundColor(isOn ? .brandDark : .brandMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Фон: \(item.title)")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
            if hasPaletteChanges {
                Button("Применить цвета") {
                    storedAccent = shownAccent.rawValue
                    if pickedButton != nil { storedButton = shownButton.rawValue }
                    storedBackground = shownBackground.rawValue
                    pickedAccent = nil; pickedButton = nil; pickedBackground = nil
                }
            }
            if !storedAccent.isEmpty || !storedButton.isEmpty || !storedBackground.isEmpty {
                Button("Вернуть цвета по умолчанию", role: .destructive) {
                    storedAccent = ""; storedButton = ""; storedBackground = ""
                    pickedAccent = nil; pickedButton = nil; pickedBackground = nil
                }
            }
        } header: {
            Text("Цвета приложения")
        } footer: {
            Text("Основной цвет — вкладки, значки и подсветка; цвет кнопок — «Читать», «Слушать», «Войти» и другие. После «Применить» приложение перерисуется.")
        }
    }

    private func swatchRow(_ title: String, selection: Binding<AppPalette.Accent>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
            HStack(spacing: 14) {
                ForEach(AppPalette.Accent.allCases) { item in
                    let isOn = selection.wrappedValue == item
                    Button { selection.wrappedValue = item } label: {
                        Circle()
                            .fill(Color(UIColor(red: CGFloat(item.tint.0 >> 16 & 0xFF) / 255, green: CGFloat(item.tint.0 >> 8 & 0xFF) / 255, blue: CGFloat(item.tint.0 & 0xFF) / 255, alpha: 1)))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.brandDark, lineWidth: isOn ? 3 : 0).padding(-4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
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
                        paletteSection
                    } else {
                        appearanceSection
                        paletteSection
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
                                Text(Account.shared.email ?? "Войти").foregroundColor(Color.brandMuted)
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
