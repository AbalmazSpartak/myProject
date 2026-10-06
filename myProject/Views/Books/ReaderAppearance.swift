import SwiftUI

/// Оформление читалки: тема, размер и шрифт, интервал, свои цвета. Общее для всех книг
enum ReaderTheme: String, CaseIterable, Identifiable {
    case app, paper, sepia, gray, night, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "Как в приложении"
        case .paper: return "Бумага"
        case .sepia: return "Сепия"
        case .gray: return "Серая"
        case .night: return "Ночь"
        case .custom: return "Своя"
        }
    }

    /// Готовые цвета; у «Как в приложении» — цвета приложения, у «Своей» — выбранные
    var colors: (background: Color, text: Color)? {
        switch self {
        case .app, .custom: return nil
        case .paper: return (Self.rgb(0xFFFFFF), Self.rgb(0x111111))
        case .sepia: return (Self.rgb(0xF4ECD8), Self.rgb(0x5B4636))
        case .gray: return (Self.rgb(0x4A4A4C), Self.rgb(0xE3E3E3))
        case .night: return (Self.rgb(0x000000), Self.rgb(0xB8B8B8))
        }
    }

    /// Тёмный фон — светлый статус-бар
    var isDark: Bool? {
        switch self {
        case .gray, .night: return true
        case .paper, .sepia: return false
        case .app, .custom: return nil
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum ReaderFont: String, CaseIterable, Identifiable {
    case serif, sans, georgia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: return "С засечками"
        case .sans: return "Без засечек"
        case .georgia: return "Georgia"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .serif: return .system(size: size, design: .serif)
        case .sans: return .system(size: size)
        case .georgia: return .custom("Georgia", size: size)
        }
    }
}

enum ReaderSpacing: String, CaseIterable, Identifiable {
    case tight, normal, loose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tight: return "Плотно"
        case .normal: return "Обычно"
        case .loose: return "Свободно"
        }
    }

    /// Доля размера шрифта между строками
    var factor: CGFloat {
        switch self {
        case .tight: return 0.12
        case .normal: return 0.28
        case .loose: return 0.5
        }
    }
}

/// Ключи настроек и разбор своих цветов (хранятся строкой «r,g,b»)
enum ReaderSettings {
    static let themeKey = "reader_theme"
    static let fontSizeKey = "reader_font_size"
    static let fontKey = "reader_font"
    static let spacingKey = "reader_spacing"
    static let customTextKey = "reader_custom_text"
    static let customBackgroundKey = "reader_custom_background"

    static let defaultFontSize = 19.0
    static let fontSizeRange = 14.0...34.0

    static func color(from raw: String, fallback: Color) -> Color {
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 3 else { return fallback }
        return Color(red: parts[0], green: parts[1], blue: parts[2])
    }

    static func raw(from color: Color) -> String {
        let resolved = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b].map { String(format: "%.4f", Double($0)) }.joined(separator: ",")
    }
}

/// Текущее оформление: читается из настроек в читалке и в шторке «Оформление»
struct ReaderStyle: Equatable {
    let theme: ReaderTheme
    let fontSize: CGFloat
    let font: ReaderFont
    let spacing: ReaderSpacing
    let customText: Color
    let customBackground: Color

    /// Снимок настроек. Читалка берёт его при открытии и после шторки «Оформление», а не на каждый кадр:
    /// чтение и разбор настроек для каждого абзаца делали прокрутку в 4 раза рывистее (замер Instruments)
    static func current() -> ReaderStyle {
        let defaults = UserDefaults.standard
        return ReaderStyle(
            theme: defaults.string(forKey: ReaderSettings.themeKey).flatMap(ReaderTheme.init(rawValue:)) ?? .app,
            fontSize: defaults.object(forKey: ReaderSettings.fontSizeKey) as? Double ?? ReaderSettings.defaultFontSize,
            font: defaults.string(forKey: ReaderSettings.fontKey).flatMap(ReaderFont.init(rawValue:)) ?? .serif,
            spacing: defaults.string(forKey: ReaderSettings.spacingKey).flatMap(ReaderSpacing.init(rawValue:)) ?? .normal,
            customText: ReaderSettings.color(from: defaults.string(forKey: ReaderSettings.customTextKey) ?? "", fallback: .black),
            customBackground: ReaderSettings.color(from: defaults.string(forKey: ReaderSettings.customBackgroundKey) ?? "", fallback: .white))
    }

    var background: Color {
        switch theme {
        case .app: return .brandBackground
        case .custom: return customBackground
        default: return theme.colors!.background
        }
    }

    var text: Color {
        switch theme {
        case .app: return .brandDark
        case .custom: return customText
        default: return theme.colors!.text
        }
    }

    /// Для статус-бара: тема явно тёмная или светлая; у «Своей» — по яркости фона; nil — как в приложении
    var colorScheme: ColorScheme? {
        if let isDark = theme.isDark { return isDark ? .dark : .light }
        guard theme == .custom else { return nil }
        var white: CGFloat = 0, alpha: CGFloat = 0
        UIColor(customBackground).getWhite(&white, alpha: &alpha)
        return white < 0.5 ? .dark : .light
    }
}

// MARK: - Шторка «Оформление»

struct ReaderAppearanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReaderSettings.themeKey) private var theme = ReaderTheme.app
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @AppStorage(ReaderSettings.fontKey) private var font = ReaderFont.serif
    @AppStorage(ReaderSettings.spacingKey) private var spacing = ReaderSpacing.normal
    @AppStorage(ReaderSettings.customTextKey) private var customTextRaw = ""
    @AppStorage(ReaderSettings.customBackgroundKey) private var customBackgroundRaw = ""

    private var style: ReaderStyle {
        ReaderStyle(theme: theme, fontSize: fontSize, font: font, spacing: spacing,
                    customText: ReaderSettings.color(from: customTextRaw, fallback: .black),
                    customBackground: ReaderSettings.color(from: customBackgroundRaw, fallback: .white))
    }

    private var customText: Binding<Color> {
        Binding(get: { style.customText }, set: { customTextRaw = ReaderSettings.raw(from: $0); theme = .custom })
    }

    private var customBackground: Binding<Color> {
        Binding(get: { style.customBackground }, set: { customBackgroundRaw = ReaderSettings.raw(from: $0); theme = .custom })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sample

                    section("Тема")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(ReaderTheme.allCases) { item in
                            themeTile(item)
                        }
                    }

                    section("Размер шрифта")
                    HStack(spacing: 14) {
                        stepButton("textformat.size.smaller", delta: -1)
                        Slider(value: $fontSize, in: ReaderSettings.fontSizeRange, step: 1)
                            .tint(.brandTint)
                        stepButton("textformat.size.larger", delta: 1)
                    }
                    Text("\(Int(fontSize)) пт")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)

                    section("Шрифт")
                    Picker("Шрифт", selection: $font) {
                        ForEach(ReaderFont.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    section("Интервал между строками")
                    Picker("Интервал", selection: $spacing) {
                        ForEach(ReaderSpacing.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    section("Свои цвета")
                    VStack(spacing: 0) {
                        ColorPicker("Цвет текста", selection: customText, supportsOpacity: false)
                            .padding(.vertical, 10)
                        Divider()
                        ColorPicker("Цвет фона", selection: customBackground, supportsOpacity: false)
                            .padding(.vertical, 10)
                    }
                    .padding(.horizontal, 14)
                    .background(Color.cardBackground)
                    .cornerRadius(14)
                    Text("Выбор цвета включает тему «Своя».")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)

                    Button("Сбросить оформление") {
                        theme = .app
                        fontSize = ReaderSettings.defaultFontSize
                        font = .serif
                        spacing = .normal
                    }
                    .foregroundColor(.brandTint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
                .padding(20)
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Оформление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
    }

    /// Образец текста в выбранном оформлении
    private var sample: some View {
        Text("It was a bright cold day in April. — Был ясный холодный апрельский день.")
            .font(font.font(size: fontSize))
            .lineSpacing(fontSize * spacing.factor)
            .foregroundColor(style.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(style.background)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: fontSize)
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .scaledFont(size: 15, weight: .semibold)
            .foregroundColor(.gray)
    }

    private func themeTile(_ item: ReaderTheme) -> some View {
        let preview = ReaderStyle(theme: item, fontSize: 17, font: font, spacing: spacing,
                                  customText: style.customText, customBackground: style.customBackground)
        return Button { theme = item } label: {
            VStack(spacing: 6) {
                Text("Aa")
                    .font(font.font(size: 22))
                    .foregroundColor(preview.text)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(preview.background)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme == item ? Color.brandTint : Color.gray.opacity(0.3), lineWidth: theme == item ? 2.5 : 1)
                    )
                Text(item.title)
                    .scaledFont(size: 12, weight: theme == item ? .semibold : .regular)
                    .foregroundColor(.brandDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(theme == item ? .isSelected : [])
    }

    private func stepButton(_ icon: String, delta: Double) -> some View {
        Button {
            fontSize = min(max(fontSize + delta, ReaderSettings.fontSizeRange.lowerBound), ReaderSettings.fontSizeRange.upperBound)
        } label: {
            Image(systemName: icon)
                .scaledFont(size: 18, weight: .semibold)
                .foregroundColor(.brandDark)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.cardBackground))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta < 0 ? "Меньше" : "Больше")
    }
}
