import SwiftUI

/// Оформление приложения: «Классический» или «Скетч» (тонкий контур, цветные смещённые тени, пастельные круги, жёлтая главная кнопка).
/// Расположение элементов одинаковое, меняется только стиль. Экраны переходят на «Скетч» по одному
nonisolated enum AppDesign: String, CaseIterable, Identifiable {
    case classic
    case sketch

    static let storageKey = "app_design"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Классический"
        case .sketch: "Скетч"
        }
    }

    /// Выбранный сейчас дизайн
    static var current: AppDesign {
        AppDesign(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .classic
    }

    /// Включён ли «Скетч» (приложение перестраивается при смене, поэтому достаточно прочитать один раз)
    static var isSketch: Bool { current == .sketch }
}
