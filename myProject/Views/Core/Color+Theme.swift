import SwiftUI

extension Color {
    // Темно-синий в светлой, белый в темной
    static let brandDark = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .white : UIColor(red: 26/255, green: 37/255, blue: 68/255, alpha: 1)
    })
    
    // Светло-серый фон в светлой, глубокий черный в темной
    static let brandBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .systemBackground : UIColor(red: 247/255, green: 249/255, blue: 253/255, alpha: 1)
    })
    
    // Фон полей ввода
    static let brandInputBg = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .secondarySystemBackground : UIColor(red: 245/255, green: 247/255, blue: 251/255, alpha: 1)
    })
    
    // Фон карточек (белый в светлой, темно-серый в темной)
    static let cardBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .secondarySystemGroupedBackground : .white
    })
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
