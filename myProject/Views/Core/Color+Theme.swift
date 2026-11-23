import SwiftUI

// Палитра «журнал»: днём — тёплый кремовый фон, тёплый белый для карточек, шалфейный акцент;
// ночью — тёплый почти чёрный фон, карточки чуть светлее, кремовый текст, приглушённый шалфей
extension Color {
    nonisolated private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    nonisolated private static func themed(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Поверхность фона: ночью при «Чёрном фоне» — свой чёрный оттенок вместо цвета выбранного фона
    nonisolated private static func surface(_ pair: AppPalette.Pair, black: UInt32) -> Color {
        themed(light: rgb(pair.0), dark: rgb(AppPalette.isBlack ? black : pair.1))
    }

    // LexiStream: палитра с холста агента-дизайнера — тёплая бумага и один тёмно-бирюзовый акцент.
    // Основной цвет, цвет кнопок и фон выбираются в Настройках (AppPalette); по умолчанию — как на холсте.

    /// Основной текст
    nonisolated static var brandDark: Color { themed(light: rgb(0x1F2421), dark: rgb(0xE9E6DD)) }

    /// Фон экранов
    nonisolated static var brandBackground: Color { surface(AppPalette.background.bg, black: 0x000000) }

    /// Фон полей ввода и переключателей
    nonisolated static var brandInputBg: Color { surface(AppPalette.background.fill, black: 0x1E1E1E) }

    /// Фон карточек
    nonisolated static var cardBackground: Color { surface(AppPalette.background.card, black: 0x141414) }

    /// Подложки: блоки групп, плашки иконок, полосы прогресса
    nonisolated static var brandFill: Color { surface(AppPalette.background.fill, black: 0x1E1E1E) }

    /// Цвет элементов управления (переключатели, выбранная вкладка, иконки)
    nonisolated static var brandTint: Color { themed(light: rgb(AppPalette.accent.tint.0), dark: rgb(AppPalette.accent.tint.1)) }

    /// Цвет кнопок: по умолчанию совпадает с основным
    nonisolated static var brandButton: Color { themed(light: rgb(AppPalette.button.tint.0), dark: rgb(AppPalette.button.tint.1)) }

    /// Текст и значки на кнопках: днём белый, ночью тёмный — иначе на светлом цвете плохо читается
    nonisolated static var brandOnButton: Color { themed(light: rgb(0xFFFFFF), dark: rgb(0x0E1A18)) }
    nonisolated static var brandOnTint: Color { brandOnButton }

    /// Шкала для статистики (песочный → тёмная бирюза): состояния слов и ответы, без красного и тревожных цветов
    nonisolated static let brandScale1 = themed(light: rgb(0xD8C7A0), dark: rgb(0x8F8159))
    nonisolated static let brandScale2 = themed(light: rgb(0xA9CFC5), dark: rgb(0x3F7A70))
    nonisolated static let brandScale3 = themed(light: rgb(0x4F9A8C), dark: rgb(0x5FAE9F))
    nonisolated static let brandScale4 = themed(light: rgb(0x1F6F63), dark: rgb(0xA6E0D3))

    /// Линии-разделители
    nonisolated static var brandBorder: Color { surface(AppPalette.background.border, black: 0x2A2A2A) }

    /// Приглушённый текст подписей
    nonisolated static let brandMuted = themed(light: rgb(0x5F6560), dark: rgb(0xA4A9A5))

    /// Мягкий акцентный фон: плашки, подсветка
    nonisolated static var brandAccent: Color { themed(light: rgb(AppPalette.accent.soft.0), dark: rgb(AppPalette.accent.soft.1)) }

    /// Текст и значки на мягком акцентном фоне (выбранные чипы, плашки)
    nonisolated static var brandOnSoft: Color { themed(light: rgb(AppPalette.accent.onSoft.0), dark: rgb(AppPalette.accent.onSoft.1)) }

    /// Состояния слова в словаре (холст «Словарь»): новое — синее, учу — янтарное, знаю — основной цвет; значки ещё и разной формы
    nonisolated static let statusNew = themed(light: rgb(0x2F5D8A), dark: rgb(0x8DB6E0))
    nonisolated static let statusLearning = themed(light: rgb(0x8A4F05), dark: rgb(0xE3A857))
    nonisolated static var statusKnown: Color { brandTint }
}

/// Готовые цвета приложения: основной, кнопок и фон. Выбор — Настройки → «Цвета приложения»; тёмные варианты подобраны заранее
nonisolated enum AppPalette {
    static let accentKey = "palette_accent"
    static let buttonKey = "palette_button"
    static let backgroundKey = "palette_background"
    /// «Чёрный фон ночью» (для OLED-экранов): в тёмной теме фон чисто чёрный при любом выбранном фоне
    static let blackKey = "palette_black"

    typealias Pair = (UInt32, UInt32)

    nonisolated enum Accent: String, CaseIterable, Identifiable {
        case teal, indigo, plum, clay, forest, ocean
        var id: String { rawValue }
        var title: String {
            switch self {
            case .teal: "Бирюзовый"
            case .indigo: "Индиго"
            case .plum: "Слива"
            case .clay: "Глина"
            case .forest: "Хвоя"
            case .ocean: "Океан"
            }
        }
        /// (день, ночь)
        var tint: Pair {
            switch self {
            case .teal: (0x1F6F63, 0x6FC2B3)
            case .indigo: (0x3F4A9E, 0x9AA5F0)
            case .plum: (0x8A3F6B, 0xE0A1C6)
            case .clay: (0xA8553A, 0xF0A98E)
            case .forest: (0x3F6B2E, 0xA3D68E)
            case .ocean: (0x1F6A8A, 0x7CC4E6)
            }
        }
        var soft: Pair {
            switch self {
            case .teal: (0xDCEDE8, 0x1F3A36)
            case .indigo: (0xE3E6F7, 0x262B4D)
            case .plum: (0xF3E2EC, 0x4A2A3D)
            case .clay: (0xF6E3DA, 0x4D2E22)
            case .forest: (0xE4EFDC, 0x2B3E22)
            case .ocean: (0xDCEBF3, 0x1F3846)
            }
        }
        /// Текст на мягком фоне (день, ночь)
        var onSoft: Pair {
            switch self {
            case .teal: (0x14524A, 0xBFE6DE)
            case .indigo: (0x2A3375, 0xCDD3FA)
            case .plum: (0x6A2A50, 0xF2CBE0)
            case .clay: (0x7C3A25, 0xF6CDBD)
            case .forest: (0x2B4E1F, 0xCDEBBE)
            case .ocean: (0x14506A, 0xBEE3F5)
            }
        }
    }

    nonisolated enum Background: String, CaseIterable, Identifiable {
        case paper, white, mist, sand
        var id: String { rawValue }
        var title: String {
            switch self {
            case .paper: "Бумага"
            case .white: "Белый"
            case .mist: "Туман"
            case .sand: "Песок"
            }
        }
        var bg: Pair {
            switch self {
            case .paper: (0xFAF7F0, 0x1F1D18)
            case .white: (0xFFFFFF, 0x18191B)
            case .mist: (0xF3F6F8, 0x121A24)
            case .sand: (0xF1E9DA, 0x251B12)
            }
        }
        var card: Pair {
            switch self {
            case .paper: (0xFFFFFF, 0x2A2721)
            case .white: (0xF6F6F4, 0x232426)
            case .mist: (0xFFFFFF, 0x1B2531)
            case .sand: (0xFBF7EE, 0x30241A)
            }
        }
        var fill: Pair {
            switch self {
            case .paper: (0xEDE7D9, 0x34302A)
            case .white: (0xEFEFEC, 0x2D2E31)
            case .mist: (0xE4EAEF, 0x24303E)
            case .sand: (0xE6DCC8, 0x3B2E22)
            }
        }
        var border: Pair {
            switch self {
            case .paper: (0xE6E0D2, 0x454037)
            case .white: (0xE4E4E0, 0x3D3E42)
            case .mist: (0xDCE3E9, 0x334255)
            case .sand: (0xDDD1BB, 0x4D3C2D)
            }
        }
    }

    nonisolated private static func stored(_ key: String) -> String? { UserDefaults.standard.string(forKey: key) }

    nonisolated static var accent: Accent { stored(accentKey).flatMap(Accent.init(rawValue:)) ?? .teal }
    /// Кнопки: свой цвет или, пока не выбран, основной
    nonisolated static var button: Accent { stored(buttonKey).flatMap(Accent.init(rawValue:)) ?? accent }
    nonisolated static var isBlack: Bool { UserDefaults.standard.bool(forKey: blackKey) }
    nonisolated static var background: Background { stored(backgroundKey).flatMap(Background.init(rawValue:)) ?? .paper }
}

extension View {
    /// Списки и формы на кремовом фоне вместо системного серого
    func brandListBackground() -> some View {
        Group {
            if AppDesign.isSketch {
                // «Скетч»: шрифт PT Sans в стандартных строках, жёлтые переключатели, тонкие тёмные разделители
                scrollContentBackground(.hidden)
                    .background(Color.brandBackground)
                    .font(.custom("PTSans-Regular", size: 17, relativeTo: .body))
                    .toggleStyle(SwitchToggleStyle(tint: NewStyle.yellow))
                    .listRowSeparatorTint(NewStyle.outline.opacity(0.25))
            } else {
                scrollContentBackground(.hidden)
                    .background(Color.brandBackground)
            }
        }
    }
}

struct AppThemeModifier: ViewModifier {
    @AppStorage("app_theme") private var appTheme: String = "system"

    // preferredColorScheme не обновляет уже открытые fullScreenCover/sheet
    // и не сбрасывается обратно на системную тему, поэтому стиль задаётся
    // всему окну — его сразу наследуют все экраны, включая модальные
    func body(content: Content) -> some View {
        content
            .onAppear(perform: applyThemeToWindows)
            .onChange(of: appTheme) { _, _ in applyThemeToWindows() }
    }

    private var resolvedStyle: UIUserInterfaceStyle {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return .unspecified
        }
    }

    private func applyThemeToWindows() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            window.overrideUserInterfaceStyle = resolvedStyle
        }
    }
}

extension View {
    func appThemedColorScheme() -> some View {
        modifier(AppThemeModifier())
    }
}
