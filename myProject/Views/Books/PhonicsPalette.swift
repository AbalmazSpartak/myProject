import SwiftUI

/// Цвета и начертания подсветки правил чтения — вариант C холста «LexiStream: Подсветка правил чтения».
/// Заливка только у трёх редких категорий (исключения, немая e, окончания); остальные — линиями разного вида,
/// немые буквы — перечёркнуты, разговорные формы — линия-пунктир с точкой и курсив. Категория всегда видна и по форме, не только по цвету.
/// Значения посчитаны под каждую тему читалки так, чтобы текст на заливке имел контраст не ниже 4,5 (проверяет run_tests.sh)
nonisolated struct PhonicsPalette: Sendable {
    /// Цвет линии или текста категории и цвет заливки (непрозрачный, уже посчитан поверх фона темы)
    struct Entry: Sendable {
        let ink: UInt32
        let fill: UInt32
    }

    /// Какой набор: бумага и сепия — светлые, серая и ночь — тёмные; «Как в приложении» — по теме экрана
    enum Variant: String, Sendable, CaseIterable {
        case paper, app, sepia, gray, night
    }

    let variant: Variant
    /// Фон и цвет текста темы — для проверки контраста
    let background: UInt32
    let text: UInt32
    let vowelPair: Entry
    let magicE: Entry
    let rControlled: Entry
    let consonantPair: Entry
    let ending: Entry
    let exception: Entry
    let colloquial: Entry
    /// Немые буквы: цвет текста с перечёркиванием
    let silent: UInt32

    var isDark: Bool { variant == .gray || variant == .night }

    static func entries(_ palette: PhonicsPalette) -> [Entry] {
        [palette.vowelPair, palette.magicE, palette.rControlled, palette.consonantPair, palette.ending, palette.exception, palette.colloquial]
    }

    static func make(_ variant: Variant) -> PhonicsPalette {
        switch variant {
        case .paper:
            return PhonicsPalette(variant: variant, background: 0xFFFFFF, text: 0x111111,
                vowelPair: .init(ink: 0x1F6BC4, fill: 0xD2E1F3), magicE: .init(ink: 0xB02F78, fill: 0xE1B0CC),
                rControlled: .init(ink: 0x6A4BC8, fill: 0xD2C9EE), consonantPair: .init(ink: 0x586B7E, fill: 0xE8EAED),
                ending: .init(ink: 0x5E7316, fill: 0xD5DBC2), exception: .init(ink: 0xB8500F, fill: 0xE7C4AD),
                colloquial: .init(ink: 0x7D5A2E, fill: 0xE0D7CD), silent: 0x737373)
        case .app:
            return PhonicsPalette(variant: variant, background: 0xFAF7F0, text: 0x1C1B19,
                vowelPair: .init(ink: 0x1F6BC4, fill: 0xCEDBE7), magicE: .init(ink: 0xB02F78, fill: 0xDEABC2),
                rControlled: .init(ink: 0x6A4BC8, fill: 0xCFC3E4), consonantPair: .init(ink: 0x586B7E, fill: 0xE3E3E0),
                ending: .init(ink: 0x5E7316, fill: 0xD1D5B7), exception: .init(ink: 0xB8500F, fill: 0xE4BEA3),
                colloquial: .init(ink: 0x7D5A2E, fill: 0xDCD1C1), silent: 0x716D63)
        case .sepia:
            return PhonicsPalette(variant: variant, background: 0xF4ECD8, text: 0x5B4636,
                vowelPair: .init(ink: 0x1F6BC4, fill: 0xD2D7D5), magicE: .init(ink: 0xA52B6E, fill: 0xDEB6BA),
                rControlled: .init(ink: 0x6244BC, fill: 0xD1C4D1), consonantPair: .init(ink: 0x566A7C, fill: 0xE1DCCD),
                ending: .init(ink: 0x586B12, fill: 0xD5D2B0), exception: .init(ink: 0xA94A0C, fill: 0xE0C2A3),
                colloquial: .init(ink: 0x6E4E22, fill: 0xDCD0B7), silent: 0x7A6552)
        case .gray:
            return PhonicsPalette(variant: variant, background: 0x4A4A4C, text: 0xE3E3E3,
                vowelPair: .init(ink: 0x7DB4FF, fill: 0x525A67), magicE: .init(ink: 0xF58CC0, fill: 0x715967),
                rControlled: .init(ink: 0xB7A2FF, fill: 0x5F5B6E), consonantPair: .init(ink: 0xA9BCCF, fill: 0x55585C),
                ending: .init(ink: 0xB4CB62, fill: 0x5C6050), exception: .init(ink: 0xFFA05C, fill: 0x705C4F),
                colloquial: .init(ink: 0xE0C08A, fill: 0x625D56), silent: 0xBABABC)
        case .night:
            return PhonicsPalette(variant: variant, background: 0x000000, text: 0xB8B8B8,
                vowelPair: .init(ink: 0x5FA2F5, fill: 0x1B2D45), magicE: .init(ink: 0xE56FAE, fill: 0x5C2C46),
                rControlled: .init(ink: 0x9C84F0, fill: 0x383056), consonantPair: .init(ink: 0x8FA3B8, fill: 0x1D2125),
                ending: .init(ink: 0xA0B84A, fill: 0x303716), exception: .init(ink: 0xF28A3C, fill: 0x522F14),
                colloquial: .init(ink: 0xCDAA72, fill: 0x352C1E), silent: 0x8A8A8A)
        }
    }

    /// Контраст двух цветов по WCAG
    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            func channel(_ shift: UInt32) -> Double {
                let value = Double((hex >> shift) & 0xFF) / 255
                return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        }
        let first = luminance(a), second = luminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    /// Яркость цвета (0…1) — для темы «Своя»
    static func brightness(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}

extension Color {
    /// Цвет из шестнадцатеричного числа 0xRRGGBB
    nonisolated init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// Линия под или через слово: узор (0 сплошная, 1 штрих, 2 точки, 3 штрих-точка) и цвет. SwiftUI-текст читает свои атрибуты сам,
/// а для текста с переносами (UILabel) линии переносятся по этой метке
nonisolated struct PhonicsLine: Hashable, Sendable {
    let pattern: Int
    let color: UInt32
    /// true — линия идёт через буквы (немые буквы), иначе под ними
    var strike = false
}

nonisolated enum PhonicsLineKey: AttributedStringKey {
    typealias Value = PhonicsLine
    static let name = "phonicsLine"
}
