import SwiftUI

extension Color {
    static let brandDark = Color(red: 26/255, green: 37/255, blue: 68/255)
    static let brandBackground = Color(red: 247/255, green: 249/255, blue: 253/255)
    static let brandInputBg = Color(red: 245/255, green: 247/255, blue: 251/255)
}

struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
