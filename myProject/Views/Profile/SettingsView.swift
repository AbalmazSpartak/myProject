import SwiftUI
import SwiftData

/// Новые цвета применяются перестройкой всего приложения: отметка «вернуться» — после неё снова открыты «Профиль» и Настройки
enum SettingsReturn {
    static var isPending = false

    /// Профиль появился — открыть Настройки, если их закрыла перестройка
    static func consume() -> Bool {
        defer { isPending = false }
        return isPending
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var profile: UserProfile
    
    @AppStorage("app_theme") private var selectedTheme: String = "system"
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.askKey) private var asksMode = false
    @AppStorage(AppPalette.accentKey) private var storedAccent = ""
    @AppStorage(AppPalette.buttonKey) private var storedButton = ""
    @AppStorage(AppPalette.backgroundKey) private var storedBackground = ""
    @AppStorage(AppPalette.blackKey) private var isBlack = false
    @State private var pickedAccent: AppPalette.Accent?
    @State private var pickedButton: AppPalette.Accent?
    @State private var pickedBackground: AppPalette.Background?
    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false
    @AppStorage(AppMode.learningOnlyKey) private var learningOnly = false

    @AppStorage(OverviewLayout.storageKey) private var overviewLayout = OverviewLayout.standard
    @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(DailyReminder.timeKey) private var reminderTime = DailyReminder.defaultTime
    /// Пользователь запретил уведомления — подсказываем, где их включить
    @State private var notificationsDenied = false

    /// Заголовок раздела по холсту: мелкие прописные, приглушённые
    static func header(_ text: String) -> some View {
        Text(text.uppercased())
            .tracking(0.5)
            .scaledFont(size: 12, weight: .semibold)
            .foregroundStyle(Color.brandMuted)
            .textCase(nil)
    }

    /// Строка-ссылка со значком основного цвета
    private func link(_ title: String, systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Color.brandTint)
        }
    }

    /// Обучение: перевод, подход, словари, перевод слов из книг — на отдельном экране
    @ViewBuilder
    private var learningLink: some View {
        Section {
            NavigationLink {
                LearningSettingsView()
            } label: {
                link("Обучение", systemImage: "graduationcap")
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
                link("Озвучка", systemImage: "speaker.wave.2")
            }
        } footer: {
            Text("Раздел, где вы настраиваете, как приложение произносит слова и читает книги вслух.")
                .textSelection(.enabled)
        }
    }

    /// Как пользуюсь: читаю и учу слова / только читаю / только учу
    private enum Usage: String, CaseIterable, Identifiable {
        case both, reader, learning
        var id: String { rawValue }
        var title: String {
            switch self {
            case .both: "Читаю и учу"
            case .reader: "Читаю"
            case .learning: "Учу"
            }
        }
    }

    private var usage: Binding<Usage> {
        Binding(
            get: { readerOnly ? .reader : (learningOnly ? .learning : .both) },
            set: { value in
                readerOnly = value == .reader
                learningOnly = value == .learning
                if value == .reader { mode = .reading }
                if value == .learning { mode = .learning }
            }
        )
    }

    /// Выбор режима приложения
    @ViewBuilder
    private var modeSection: some View {
        Section {
            Picker("Как пользуюсь", selection: usage) {
                ForEach(Usage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if !readerOnly && !learningOnly {
                Toggle("Спрашивать при запуске", isOn: $asksMode)
            }
        } header: {
            Self.header("Режим")
        } footer: {
            Text(readerOnly
                 ? "Приложение работает как читалка: библиотека, аудио и закладки. Обучение и переключатель режимов скрыты, слова и прогресс сохраняются."
                 : learningOnly
                 ? "Слова, практика и словарь, без читалки и переключателя режимов. Книги и закладки сохраняются."
                 : asksMode
                 ? "При каждом запуске приложение спросит, как вы хотите пользоваться."
                 : "Читалка и обучение вместе: режимы переключаются сверху.")
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
            themePicker
            Toggle("Чёрный фон ночью", isOn: Binding(get: { isBlack }, set: { SettingsReturn.isPending = true; isBlack = $0 }))
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
                                // Пополам: слева фон светлой темы, справа — тёмной
                                HStack(spacing: 0) {
                                    Self.color(item.bg.0)
                                    Self.color(item.bg.1)
                                }
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
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
                    SettingsReturn.isPending = true
                    storedAccent = shownAccent.rawValue
                    if pickedButton != nil { storedButton = shownButton.rawValue }
                    storedBackground = shownBackground.rawValue
                    pickedAccent = nil; pickedButton = nil; pickedBackground = nil
                }
            }
            if !storedAccent.isEmpty || !storedButton.isEmpty || !storedBackground.isEmpty {
                Button("Вернуть цвета по умолчанию", role: .destructive) {
                    SettingsReturn.isPending = true
                    storedAccent = ""; storedButton = ""; storedBackground = ""
                    pickedAccent = nil; pickedButton = nil; pickedBackground = nil
                }
            }
        } header: {
            Self.header("Цвета приложения")
        } footer: {
            Text("«Чёрный фон ночью» — в тёмной теме фон чисто чёрный: на экране iPhone это бережёт батарею. Кружки фона: слева — светлая тема, справа — тёмная. Основной цвет — вкладки, значки и подсветка; цвет кнопок — «Читать», «Слушать», «Войти» и другие. После «Применить» приложение перерисуется.")
        }
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1))
    }

    private var themePicker: some View {
        Picker("Тема оформления", selection: $selectedTheme) {
            Text("Системная").tag("system")
            Text("Светлая").tag("light")
            Text("Тёмная").tag("dark")
        }
        .pickerStyle(.segmented)
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

    /// Дизайн приложения: классический или новый стиль
    private var designSection: some View {
        Section {
            Picker("Оформление приложения", selection: Binding(get: { design }, set: { SettingsReturn.isPending = true; SketchChrome.apply($0 == AppDesign.sketch.rawValue); design = $0 })) {
                ForEach(AppDesign.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        } header: {
            Self.header("Оформление")
        } footer: {
            Text("«Скетч» — контуры «от руки», цветные тени, пастельные цвета и другие шрифты; расположение экранов то же. Подключается к экранам по одному, остальные пока классические. После выбора приложение перерисуется. Данные не меняются, вернуться можно в любой момент.")
                .textSelection(.enabled)
        }
    }

    /// Вид «Обзора» — только в «Изучении»; тема — в «Цветах приложения»
    private var appearanceSection: some View {
        Section(header: Self.header("Оформление")) {
            NavigationLink {
                OverviewSettingsView()
            } label: {
                LabeledContent("Обзор", value: overviewLayout == .standard ? "Стандартный" : "Настроен")
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    // В каждом режиме свой порядок: «Изучение» — личное и озвучка, «Чтение» — оформление и режим сверху
                    designSection
                    if mode == .learning {
                        speechLink
                        modeSection
                        appearanceSection
                        paletteSection
                    } else {
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
                        Self.header("Напоминание")
                    } footer: {
                        Text(notificationsDenied
                             ? "Уведомления запрещены — включите их в Настройках iPhone → LexiStream → Уведомления."
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
                                link("Аккаунт", systemImage: "person.crop.circle")
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
            .tint(Color.brandTint)
            .listRowSeparatorTint(Color.brandBorder)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Настройки")
                        .scaledFont(size: 20, weight: .semibold, design: .serif)
                        .foregroundStyle(Color.brandDark)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brandTint)
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
