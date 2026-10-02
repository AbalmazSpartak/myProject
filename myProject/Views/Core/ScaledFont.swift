import SwiftUI
import UIKit

/// Шрифт заданного размера, который растёт вместе с системной настройкой «Размер текста».
/// При стандартном размере — ровно `size`, при увеличенном — как ближайший системный стиль
nonisolated private struct ScaledFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let scaled = UIFontMetrics(forTextStyle: Self.textStyle(for: size)).scaledValue(for: size, compatibleWith: traits)
        return content.font(.system(size: scaled, weight: weight, design: design))
    }

    /// Системный стиль того же размера — у крупных стилей рост мягче, чтобы заголовки не разваливали экран
    private static func textStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<12: return .caption2
        case ..<13: return .caption1
        case ..<14: return .footnote
        case ..<16: return .subheadline
        case ..<17: return .callout
        case ..<19: return .body
        case ..<21: return .title3
        case ..<25: return .title2
        case ..<31: return .title1
        default: return .largeTitle
        }
    }
}

extension View {
    /// Вместо `.font(.system(size:weight:design:))` — учитывает «Размер текста» в настройках iPhone
    nonisolated func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
