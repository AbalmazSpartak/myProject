import SwiftUI

// Палитра «журнал» (светлая): тёплый кремовый фон, тёплый белый для карточек, шалфейный акцент.
// Тёмные значения — прежние; приложение пока всегда светлое (см. AppThemeModifier)
extension Color {
    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func themed(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Основной текст — почти чёрный с тёплым оттенком
    static let brandDark = themed(light: rgb(0x1F1B16), dark: .white)

    /// Фон экранов — тёплый кремовый
    static let brandBackground = themed(light: rgb(0xF3EEE3), dark: .systemBackground)

    /// Фон полей ввода
    static let brandInputBg = themed(light: rgb(0xEAE3D5), dark: .secondarySystemBackground)

    /// Фон карточек — тёплый белый
    static let cardBackground = themed(light: rgb(0xFBF8F2), dark: .secondarySystemGroupedBackground)

    /// Подложки: блоки групп, плашки иконок, полосы прогресса
    static let brandFill = themed(light: rgb(0xE8E1D3), dark: .systemGray5)

    /// Приглушённый шалфейно-зелёный акцент, как блок с примером на макете
    static let brandAccent = themed(light: rgb(0xC5D0B8), dark: rgb(0x4A5A43))
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

    /// Пока у оформления «журнал» есть только светлая палитра — приложение всегда светлое.
    /// Выбор темы в настройках скрыт, но сохранённое значение остаётся до появления тёмной палитры
    private var resolvedStyle: UIUserInterfaceStyle {
        .light
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
