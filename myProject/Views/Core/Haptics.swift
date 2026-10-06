import UIKit

/// Лёгкая вибрация на нажатия пунктов меню и вкладок (⚙️ → «Вибрация»).
/// Выключенный в iPhone «Тактильный отклик» iOS учитывает сама
enum Haptics {
    static let enabledKey = "haptics_enabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
