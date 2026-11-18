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
        return content.font(AppFonts.font(size: scaled, weight: weight, design: design))
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

/// Шрифты LexiStream: Newsreader (заголовки, `.serif`) и Inter (текст). Файлы лежат в Resources/Fonts и регистрируются при запуске.
/// Нет файла — остаётся системный шрифт
enum AppFonts {
    nonisolated static func register() {
        let urls = ["ttf", "otf"].flatMap { Bundle.main.urls(forResourcesWithExtension: $0, subdirectory: nil) ?? [] }
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }

    nonisolated static func font(size: CGFloat, weight: Font.Weight, design: Font.Design, italic: Bool = false) -> Font {
        let family: String
        switch design {
        case .serif: family = "Newsreader"
        case .default: family = "Inter"
        default: return .system(size: size, weight: weight, design: design)
        }
        let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: uiWeight(weight)]
        var attrs: [UIFontDescriptor.AttributeName: Any] = [.family: family, .traits: traits]
        if italic { attrs[.face] = "Italic" }
        let font = UIFont(descriptor: UIFontDescriptor(fontAttributes: attrs), size: size)
        guard font.familyName == family else { return .system(size: size, weight: weight, design: design) }
        return Font(font)
    }

    nonisolated private static func uiWeight(_ w: Font.Weight) -> UIFont.Weight {
        switch w {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
