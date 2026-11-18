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

    // LexiStream: палитра с холста агента-дизайнера — тёплая бумага и один тёмно-бирюзовый акцент.
    // Основной цвет, цвет кнопок и фон выбираются в Настройках (AppPalette); по умолчанию — как на холсте.

    /// Основной текст
    nonisolated static var brandDark: Color { themed(light: rgb(0x1F2421), dark: rgb(0xE9E6DD)) }

    /// Фон экранов
    nonisolated static var brandBackground: Color { themed(light: rgb(AppPalette.background.bg.0), dark: rgb(AppPalette.background.bg.1)) }

    /// Фон полей ввода и переключателей
    nonisolated static var brandInputBg: Color { themed(light: rgb(AppPalette.background.fill.0), dark: rgb(AppPalette.background.fill.1)) }

    /// Фон карточек
    nonisolated static var cardBackground: Color { themed(light: rgb(AppPalette.background.card.0), dark: rgb(AppPalette.background.card.1)) }

    /// Подложки: блоки групп, плашки иконок, полосы прогресса
    nonisolated static var brandFill: Color { themed(light: rgb(AppPalette.background.fill.0), dark: rgb(AppPalette.background.fill.1)) }

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
    nonisolated static var brandBorder: Color { themed(light: rgb(AppPalette.background.border.0), dark: rgb(AppPalette.background.border.1)) }

    /// Приглушённый текст подписей
    nonisolated static let brandMuted = themed(light: rgb(0x5F6560), dark: rgb(0xA4A9A5))

    /// Мягкий акцентный фон: плашки, подсветка
    nonisolated static var brandAccent: Color { themed(light: rgb(AppPalette.accent.soft.0), dark: rgb(AppPalette.accent.soft.1)) }
}

/// Готовые цвета приложения: основной, кнопок и фон. Выбор — Настройки → «Цвета приложения»; тёмные варианты подобраны заранее
nonisolated enum AppPalette {
    static let accentKey = "palette_accent"
    static let buttonKey = "palette_button"
    static let backgroundKey = "palette_background"

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
            case .paper: (0xFAF7F0, 0x141617)
            case .white: (0xFFFFFF, 0x101112)
            case .mist: (0xF3F6F8, 0x12161A)
            case .sand: (0xF1E9DA, 0x1A1714)
            }
        }
        var card: Pair {
            switch self {
            case .paper: (0xFFFFFF, 0x202324)
            case .white: (0xF6F6F4, 0x1C1E1F)
            case .mist: (0xFFFFFF, 0x1C2227)
            case .sand: (0xFBF7EE, 0x26211C)
            }
        }
        var fill: Pair {
            switch self {
            case .paper: (0xEDE7D9, 0x2C3032)
            case .white: (0xEFEFEC, 0x2A2C2D)
            case .mist: (0xE4EAEF, 0x2A3238)
            case .sand: (0xE6DCC8, 0x332D26)
            }
        }
        var border: Pair {
            switch self {
            case .paper: (0xE6E0D2, 0x34383A)
            case .white: (0xE4E4E0, 0x333536)
            case .mist: (0xDCE3E9, 0x333B42)
            case .sand: (0xDDD1BB, 0x3B342C)
            }
        }
    }

    nonisolated private static func stored(_ key: String) -> String? { UserDefaults.standard.string(forKey: key) }

    nonisolated static var accent: Accent { stored(accentKey).flatMap(Accent.init(rawValue:)) ?? .teal }
    /// Кнопки: свой цвет или, пока не выбран, основной
    nonisolated static var button: Accent { stored(buttonKey).flatMap(Accent.init(rawValue:)) ?? accent }
    nonisolated static var background: Background { stored(backgroundKey).flatMap(Background.init(rawValue:)) ?? .paper }
}

extension View {
    /// Списки и формы на кремовом фоне вместо системного серого
    func brandListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.brandBackground)
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
