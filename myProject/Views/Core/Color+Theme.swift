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


struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
