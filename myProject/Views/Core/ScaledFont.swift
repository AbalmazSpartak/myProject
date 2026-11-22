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
        // Шрифт собирается один раз на сочетание размера, веса, начертания и «Размера текста»: этот модификатор стоит на сотнях строк
        // «Скетч» меняет шрифты; при смене оформления приложение перестраивается целиком (см. MyApp), строки читают выбор заново
        let isSketch = AppDesign.current == .sketch
        let key = ScaledFontCache.Key(size: size, weight: weight, design: design, dynamicTypeSize: dynamicTypeSize, isSketch: isSketch)
        let font = ScaledFontCache.shared.font(for: key) {
            let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
            let scaled = UIFontMetrics(forTextStyle: Self.textStyle(for: size)).scaledValue(for: size, compatibleWith: traits)
            return AppFonts.font(size: scaled, weight: weight, design: design, sketch: isSketch)
        }
        return content.font(font)
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

/// Готовые шрифты `scaledFont`: сборка UIFont с поиском по семейству и запасным шрифтом дорогая, а вызывается на каждую перерисовку строки
nonisolated final class ScaledFontCache: @unchecked Sendable {
    nonisolated static let shared = ScaledFontCache()

    struct Key: Hashable {
        let size: CGFloat
        let weight: Font.Weight
        let design: Font.Design
        let dynamicTypeSize: DynamicTypeSize
        let isSketch: Bool
    }

    private let lock = NSLock()
    private var fonts: [Key: Font] = [:]

    func font(for key: Key, make: () -> Font) -> Font {
        lock.lock()
        if let cached = fonts[key] { lock.unlock(); return cached }
        lock.unlock()
        let font = make()
        lock.lock()
        fonts[key] = font
        lock.unlock()
        return font
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

    /// «Скетч»: PT Sans (текст), PT Serif (засечки), Neucha (рукописные заголовки — `.rounded`). Нет файла — системный шрифт
    nonisolated private static func sketchFont(size: CGFloat, weight: Font.Weight, design: Font.Design) -> Font? {
        let isBold = weight == .semibold || weight == .bold || weight == .heavy || weight == .black
        let name: String
        switch design {
        case .rounded: name = "Neucha"
        case .serif: name = isBold ? "PTSerif-Bold" : "PTSerif-Regular"
        case .default: name = isBold ? "PTSans-Bold" : "PTSans-Regular"
        default: return nil
        }
        guard let font = UIFont(name: name, size: size) else { return nil }
        return Font(font)
    }

    nonisolated static func font(size: CGFloat, weight: Font.Weight, design: Font.Design, italic: Bool = false, sketch: Bool = false) -> Font {
        if sketch, !italic, let font = sketchFont(size: size, weight: weight, design: design) { return font }
        let family: String
        switch design {
        case .serif: family = "Newsreader"
        case .default: family = "Inter"
        default: return .system(size: size, weight: weight, design: design)
        }
        let traits: [UIFontDescriptor.TraitKey: Any] = [.weight: uiWeight(weight)]
        var attrs: [UIFontDescriptor.AttributeName: Any] = [.family: family, .traits: traits]
        if italic { attrs[.face] = "Italic" }
        // У Newsreader нет кириллицы: русские буквы берём из системного шрифта с засечками (New York), а не без засечек
        if design == .serif,
           let fallback = UIFont.systemFont(ofSize: size, weight: uiWeight(weight)).fontDescriptor.withDesign(.serif) {
            attrs[.cascadeList] = [fallback]
        }
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
