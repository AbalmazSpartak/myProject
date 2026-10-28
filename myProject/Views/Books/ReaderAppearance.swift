import SwiftUI

/// Оформление читалки: тема, размер и шрифт, интервал, свои цвета. Общее для всех книг
enum ReaderTheme: String, CaseIterable, Identifiable {
    case app, paper, sepia, gray, night, nightCustom, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "Как в приложении"
        case .paper: return "Бумага"
        case .sepia: return "Сепия"
        case .gray: return "Серая"
        case .night: return "Ночь"
        case .nightCustom: return "Моя ночь"
        case .custom: return "Своя"
        }
    }

    /// Готовые цвета; у «Как в приложении» — цвета приложения, у «Своей» — выбранные
    var colors: (background: Color, text: Color)? {
        switch self {
        case .app, .nightCustom, .custom: return nil
        case .paper: return (Self.rgb(0xFFFFFF), Self.rgb(0x111111))
        case .sepia: return (Self.rgb(0xF4ECD8), Self.rgb(0x5B4636))
        case .gray: return (Self.rgb(0x4A4A4C), Self.rgb(0xE3E3E3))
        case .night: return (Self.rgb(0x000000), Self.rgb(0xB8B8B8))
        }
    }

    /// Тёмный фон — светлый статус-бар
    var isDark: Bool? {
        switch self {
        case .gray, .night, .nightCustom: return true
        case .paper, .sepia: return false
        case .app, .custom: return nil
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// «Моя ночь»: три ползунка вместо колеса цветов — яркость фона, тёплость оттенка и яркость текста.
/// Оттенок (от холодного через белый и янтарный к красному) умножается на яркость, поэтому фон и текст одного тона
struct NightPalette: Equatable {
    /// Фон: 0 — чёрный, 0.3 — тёмно-серый
    var brightness = 0.06
    /// 0 — холодный, 0.25 — нейтральный, 0.7 — янтарный, 1 — красный
    var warmth = 0.6
    /// Текст: 0.3 — тусклый, 0.95 — почти белый
    var text = 0.72

    static let standard = NightPalette()
    static let brightnessRange = 0.0...0.3
    static let textRange = 0.3...0.95

    /// Заготовки: берёшь за основу и подправляешь ползунками
    static let presets: [(title: String, palette: NightPalette)] = [
        ("Тёплая", NightPalette(brightness: 0.06, warmth: 0.65, text: 0.72)),
        ("Холодная", NightPalette(brightness: 0.08, warmth: 0.0, text: 0.75)),
        ("Красная", NightPalette(brightness: 0.03, warmth: 1.0, text: 0.85)),
    ]

    private static let stops: [(at: Double, rgb: (Double, Double, Double))] = [
        (0, (0.82, 0.90, 1.0)), (0.25, (1, 1, 1)), (0.7, (1, 0.74, 0.45)), (1, (1, 0.40, 0.25)),
    ]

    private var tint: (r: Double, g: Double, b: Double) {
        let w = min(max(warmth, 0), 1)
        let stops = Self.stops
        let upper = stops.firstIndex { $0.at >= w } ?? stops.count - 1
        let lower = max(upper - 1, 0)
        let span = stops[upper].at - stops[lower].at
        let t = span > 0 ? (w - stops[lower].at) / span : 0
        let a = stops[lower].rgb, b = stops[upper].rgb
        return (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    private func color(_ level: Double) -> Color {
        let tint = tint
        return Color(red: tint.r * level, green: tint.g * level, blue: tint.b * level)
    }

    var backgroundColor: Color { color(brightness) }
    var textColor: Color { color(text) }

    /// Контраст текста и фона (WCAG): ниже 3 читать уже тяжело
    var contrast: Double {
        func luminance(_ level: Double) -> Double {
            let tint = tint
            func channel(_ value: Double) -> Double {
                value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(tint.r * level) + 0.7152 * channel(tint.g * level) + 0.0722 * channel(tint.b * level)
        }
        let a = luminance(text), b = luminance(brightness)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
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

/// Как идёт текст: по страницам (листать) или одной лентой (прокручивать)
enum ReaderLayout: String, CaseIterable, Identifiable {
    case pages, scroll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pages: return "Страницы"
        case .scroll: return "Прокрутка"
        }
    }
}

/// Анимация листания страниц
enum ReaderPageTurn: String, CaseIterable, Identifiable {
    case slide, curl, instant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slide: return "Сдвиг"
        case .curl: return "Загиб страницы"
        case .instant: return "Без анимации"
        }
    }
}

/// Ключи настроек и разбор своих цветов (хранятся строкой «r,g,b»)
enum ReaderSettings {
    static let themeKey = "reader_theme"
    static let fontSizeKey = "reader_font_size"
    static let fontKey = "reader_font"
    static let spacingKey = "reader_spacing"
    static let layoutKey = "reader_layout"
    static let pageTurnKey = "reader_page_turn"
    /// Подсветка правил чтения: "off" — выключена; иначе включена (раньше были режимы "tricky" и "all")
    /// Перевод под абзацами (книга с добавленным переводом, режим прокрутки)
    static let parallelKey = "reader_parallel"
    static let phonicsKey = "reader_phonics"
    /// Какие правила подсвечивать — галочки; пусто — как было в режиме («Все правила» → все, иначе «Сложное»)
    static let phonicsRulesKey = "reader_phonics_rules"

    static func phonicsOptions(mode: String, rules: String) -> Set<PhonicsOption> {
        PhonicsOption.options(from: rules) ?? (mode == "all" ? Set(PhonicsOption.allCases) : PhonicsOption.tricky)
    }
    static let customTextKey = "reader_custom_text"
    static let customBackgroundKey = "reader_custom_background"
    static let nightBrightnessKey = "reader_night_brightness"
    static let nightWarmthKey = "reader_night_warmth"
    static let nightTextKey = "reader_night_text"

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
    var layout: ReaderLayout = .pages
    var pageTurn: ReaderPageTurn = .slide
    /// nil — подсветка выключена
    var phonics: Set<PhonicsOption>?
    let customText: Color
    let customBackground: Color
    var night = NightPalette.standard

    /// Снимок настроек. Читалка берёт его при открытии и после шторки «Оформление», а не на каждый кадр:
    /// чтение и разбор настроек для каждого абзаца делали прокрутку в 4 раза рывистее (замер Instruments)
    static func current() -> ReaderStyle {
        let defaults = UserDefaults.standard
        return ReaderStyle(
            theme: defaults.string(forKey: ReaderSettings.themeKey).flatMap(ReaderTheme.init(rawValue:)) ?? .app,
            fontSize: defaults.object(forKey: ReaderSettings.fontSizeKey) as? Double ?? ReaderSettings.defaultFontSize,
            font: defaults.string(forKey: ReaderSettings.fontKey).flatMap(ReaderFont.init(rawValue:)) ?? .serif,
            spacing: defaults.string(forKey: ReaderSettings.spacingKey).flatMap(ReaderSpacing.init(rawValue:)) ?? .normal,
            layout: defaults.string(forKey: ReaderSettings.layoutKey).flatMap(ReaderLayout.init(rawValue:)) ?? .pages,
            pageTurn: defaults.string(forKey: ReaderSettings.pageTurnKey).flatMap(ReaderPageTurn.init(rawValue:)) ?? .slide,
            phonics: Self.phonics(defaults),
            customText: ReaderSettings.color(from: defaults.string(forKey: ReaderSettings.customTextKey) ?? "", fallback: .black),
            customBackground: ReaderSettings.color(from: defaults.string(forKey: ReaderSettings.customBackgroundKey) ?? "", fallback: .white),
            night: NightPalette(brightness: defaults.object(forKey: ReaderSettings.nightBrightnessKey) as? Double ?? NightPalette.standard.brightness,
                                warmth: defaults.object(forKey: ReaderSettings.nightWarmthKey) as? Double ?? NightPalette.standard.warmth,
                                text: defaults.object(forKey: ReaderSettings.nightTextKey) as? Double ?? NightPalette.standard.text))
    }

    private static func phonics(_ defaults: UserDefaults) -> Set<PhonicsOption>? {
        let mode = defaults.string(forKey: ReaderSettings.phonicsKey) ?? "off"
        guard mode != "off" else { return nil }
        return ReaderSettings.phonicsOptions(mode: mode, rules: defaults.string(forKey: ReaderSettings.phonicsRulesKey) ?? "")
    }

    /// Для перерисовки главы: меняется вместе с галочками
    var phonicsID: String { phonics.map(PhonicsOption.raw) ?? "off" }

    var background: Color {
        switch theme {
        case .app: return .brandBackground
        case .custom: return customBackground
        case .nightCustom: return night.backgroundColor
        default: return theme.colors!.background
        }
    }

    var text: Color {
        switch theme {
        case .app: return .brandDark
        case .custom: return customText
        case .nightCustom: return night.textColor
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
    @AppStorage(ReaderSettings.layoutKey) private var layout = ReaderLayout.pages
    @AppStorage(ReaderSettings.pageTurnKey) private var pageTurn = ReaderPageTurn.slide
    @AppStorage(ReaderSettings.phonicsKey) private var phonicsMode = "off"
    @AppStorage(ReaderSettings.phonicsRulesKey) private var phonicsRules = ""
    @AppStorage(ReaderSettings.customTextKey) private var customTextRaw = ""
    @AppStorage(ReaderSettings.customBackgroundKey) private var customBackgroundRaw = ""
    @AppStorage(ReaderSettings.nightBrightnessKey) private var nightBrightness = NightPalette.standard.brightness
    @AppStorage(ReaderSettings.nightWarmthKey) private var nightWarmth = NightPalette.standard.warmth
    @AppStorage(ReaderSettings.nightTextKey) private var nightText = NightPalette.standard.text

    private var style: ReaderStyle {
        ReaderStyle(theme: theme, fontSize: fontSize, font: font, spacing: spacing,
                    customText: ReaderSettings.color(from: customTextRaw, fallback: .black),
                    customBackground: ReaderSettings.color(from: customBackgroundRaw, fallback: .white),
                    night: night)
    }

    private var night: NightPalette {
        NightPalette(brightness: nightBrightness, warmth: nightWarmth, text: nightText)
    }

    private var phonicsOn: Binding<Bool> {
        Binding(get: { phonicsMode != "off" }, set: { isOn in
            // Галочки запоминаются до смены режима — выключили, включили, и всё как было
            // (у старого режима «Все правила» своих галочек ещё нет — берём их из режима)
            if PhonicsOption.options(from: phonicsRules) == nil {
                phonicsRules = PhonicsOption.raw(ReaderSettings.phonicsOptions(mode: phonicsMode, rules: phonicsRules))
            }
            phonicsMode = isOn ? "on" : "off"
        })
    }

    private var phonicsSelection: Binding<Set<PhonicsOption>> {
        Binding(get: { ReaderSettings.phonicsOptions(mode: phonicsMode, rules: phonicsRules) },
                set: { phonicsRules = PhonicsOption.raw($0) })
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
                    section("Листание")
                    Picker("Листание", selection: $layout) {
                        ForEach(ReaderLayout.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if layout == .pages {
                        Picker("Анимация", selection: $pageTurn) {
                            ForEach(ReaderPageTurn.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Правила чтения")
                    Toggle("Подсветка правил", isOn: phonicsOn)
                        .scaledFont(size: 16, weight: .semibold)
                        .tint(.brown)
                    if phonicsMode == "off" {
                        Text("Подсветка сочетаний букв, которые читаются по особым правилам. Нажмите на слово — карточка покажет, как его читать.")
                            .scaledFont(size: 13)
                            .foregroundColor(.gray)
                    } else {
                        PhonicsLegend(selection: phonicsSelection)
                    }

                    section("Тема")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                        ForEach(ReaderTheme.allCases) { item in
                            themeTile(item)
                        }
                    }
                    sample
                    if theme == .nightCustom { nightSettings }

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
                        layout = .pages
                        pageTurn = .slide
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
                                  customText: style.customText, customBackground: style.customBackground, night: night)
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

    /// Ползунки «Моя ночь»; образец вверху шторки меняется сразу
    @ViewBuilder
    private var nightSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(NightPalette.presets, id: \.title) { preset in
                    Button(preset.title) {
                        nightBrightness = preset.palette.brightness
                        nightWarmth = preset.palette.warmth
                        nightText = preset.palette.text
                    }
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(.brandTint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.cardBackground))
                }
            }
            nightSlider("Яркость фона", value: $nightBrightness, range: NightPalette.brightnessRange)
            nightSlider("Тёплость оттенка", value: $nightWarmth, range: 0...1)
            nightSlider("Яркость текста", value: $nightText, range: NightPalette.textRange)
            if night.contrast < 3 {
                Label("Текст почти сливается с фоном — прибавьте яркость текста", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(size: 13)
                    .foregroundColor(.orange)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    private func nightSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .scaledFont(size: 14)
                .foregroundColor(.gray)
            Slider(value: value, in: range)
                .tint(.brandTint)
        }
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
