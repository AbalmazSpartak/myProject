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

    // LexiStream: палитра с холста агента-дизайнера — тёплая бумага и один тёмно-бирюзовый акцент

    /// Основной текст
    nonisolated static let brandDark = themed(light: rgb(0x1F2421), dark: rgb(0xE9E6DD))

    /// Фон экранов — тёплая бумага
    nonisolated static let brandBackground = themed(light: rgb(0xFAF7F0), dark: rgb(0x141617))

    /// Фон полей ввода и переключателей
    nonisolated static let brandInputBg = themed(light: rgb(0xEDE7D9), dark: rgb(0x2C3032))

    /// Фон карточек
    nonisolated static let cardBackground = themed(light: rgb(0xFFFFFF), dark: rgb(0x202324))

    /// Подложки: блоки групп, плашки иконок, полосы прогресса
    nonisolated static let brandFill = themed(light: rgb(0xEDE7D9), dark: rgb(0x2C3032))

    /// Цвет элементов управления (переключатели, выбранная вкладка, главные кнопки)
    nonisolated static let brandTint = themed(light: rgb(0x1F6F63), dark: rgb(0x6FC2B3))

    /// Текст и значки на бирюзовых кнопках: днём белый, ночью тёмный — иначе на светлом бирюзовом плохо читается
    nonisolated static let brandOnTint = themed(light: rgb(0xFFFFFF), dark: rgb(0x0E1A18))

    /// Мягкий бирюзовый акцент: плашки, подсветка
    nonisolated static let brandAccent = themed(light: rgb(0xDCEDE8), dark: rgb(0x1F3A36))

    /// Линии-разделители
    nonisolated static let brandBorder = themed(light: rgb(0xE6E0D2), dark: rgb(0x34383A))

    /// Приглушённый текст подписей
    nonisolated static let brandMuted = themed(light: rgb(0x5F6560), dark: rgb(0xA4A9A5))
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
