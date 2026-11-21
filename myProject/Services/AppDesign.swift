import SwiftUI

/// Дизайн приложения: «Классический» (как был) или «Новый стиль» (белый фон, контуры, цветные смещённые тени).
/// Экраны переходят на новый стиль по одному: пока у экрана нового вида нет, он остаётся классическим
enum AppDesign: String, CaseIterable, Identifiable {
    case classic
    case modern

    static let storageKey = "app_design"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Классический"
        case .modern: "Новый стиль"
        }
    }

    /// Выбранный сейчас дизайн
    static var current: AppDesign {
        AppDesign(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .classic
    }
}
