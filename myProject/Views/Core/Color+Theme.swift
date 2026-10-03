import SwiftUI

// Палитра «журнал»: днём — тёплый кремовый фон, тёплый белый для карточек, шалфейный акцент;
// ночью — тёплый почти чёрный фон, карточки чуть светлее, кремовый текст, приглушённый шалфей
extension Color {
    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    nonisolated private static func themed(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Основной текст — почти чёрный с тёплым оттенком
    static let brandDark = themed(light: rgb(0x1F1B16), dark: rgb(0xEDE6D8))

    /// Фон экранов — тёплый кремовый
    static let brandBackground = themed(light: rgb(0xF3EEE3), dark: rgb(0x1A1714))

    /// Фон полей ввода
    static let brandInputBg = themed(light: rgb(0xEAE3D5), dark: rgb(0x2E2A25))

    /// Фон карточек — тёплый белый
    static let cardBackground = themed(light: rgb(0xFBF8F2), dark: rgb(0x26221E))

    /// Подложки: блоки групп, плашки иконок, полосы прогресса
    static let brandFill = themed(light: rgb(0xE8E1D3), dark: rgb(0x35302A))

    /// Цвет элементов управления (переключатели, выбранная вкладка): днём — как текст,
    /// ночью — шалфейный, иначе включённый переключатель светлый с белым кружком и не читается
    static let brandTint = themed(light: rgb(0x1F1B16), dark: rgb(0x8FA67F))

    /// Приглушённый шалфейно-зелёный акцент, как блок с примером на макете
    static let brandAccent = themed(light: rgb(0xC5D0B8), dark: rgb(0x3E4A37))
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
