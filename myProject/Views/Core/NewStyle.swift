import SwiftUI

/// Детали стиля «Скетч»: тонкий контур «от руки», цветная смещённая тень, пастельные круги, жёлтая главная кнопка
nonisolated enum NewStyle {
    /// Цвет пары «день / ночь»
    private static func themed(_ light: UInt32, _ dark: UInt32) -> Color {
        func ui(_ h: UInt32) -> UIColor {
            UIColor(red: CGFloat(h >> 16 & 0xFF) / 255, green: CGFloat(h >> 8 & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }

    /// Выбран ли в «Цветах приложения» свой цвет кнопок: тогда главные кнопки «Скетча» берут его, а не жёлтый
    private static var hasCustomButton: Bool { UserDefaults.standard.string(forKey: AppPalette.buttonKey) != nil }

    /// Главная заливка: жёлтая, пока не выбран цвет кнопок
    static var yellow: Color { hasCustomButton ? Color.brandButton : themed(0xEBBF47, 0xE0B040) }
    /// Текст на главной заливке
    static var onYellow: Color { hasCustomButton ? Color.brandOnButton : Color.black }
    /// Смещённая тень главной заливки
    static var yellowShadow: Color {
        hasCustomButton ? Color(UIColor { trait in
            UIColor(Color.brandButton).resolvedColor(with: trait).blended(0.35)
        }) : themed(0xB58A1E, 0x8A6A14)
    }
    static let blue = themed(0x72AFE3, 0x2F5278)
    static let peach = themed(0xEFB59E, 0x7A4A3A)
    static var outline: Color { Color.brandDark }
    static let lineWidth: CGFloat = 1.5

    /// Пастельные плашки: кремовая, голубая, розовая, зелёная (ночью — тёмные, чтобы светлый текст читался)
    static let pastels: [Color] = [
        themed(0xFFF1C9, 0x4A4326),
        themed(0xE0EDFA, 0x253A4D),
        themed(0xF0E1EC, 0x42303B),
        themed(0xE2EFDC, 0x2E3F2A)
    ]

    /// Штрих линии: круглые концы, как у маркера
    static var stroke: StrokeStyle { StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round) }
}

/// Устойчивое число из строки (не меняется между запусками, в отличие от `hashValue`): чтобы у каждой книги линия «дрожала» одинаково
nonisolated enum StableSeed {
    static func of(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return hash
    }
}

/// Скруглённый прямоугольник «от руки» (мягкий вариант): точки по периметру чуть смещены, углы сглажены.
/// Смещения зависят только от размера и `seed`, поэтому рисунок не мерцает и не пересчитывается случайно
nonisolated struct RoughRoundedRect: Shape {
    var radius: CGFloat = 12
    var seed: UInt64 = 7
    /// Размах «дрожания» в пунктах: 0.9 — едва заметно
    var jitter: CGFloat = 0.9

    func path(in rect: CGRect) -> Path {
        // Во время анимаций размер бывает нулевым, отрицательным или не числом — на таком не рисуем (UInt64(…) ниже иначе падает)
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 1, rect.height > 1 else { return Path() }
        let r = min(radius, min(rect.width, rect.height) / 2)
        var points: [CGPoint] = []
        func side(from a: CGPoint, to b: CGPoint) {
            let length = hypot(b.x - a.x, b.y - a.y)
            let steps = max(1, Int(length / 26))
            for i in 0..<steps {
                let t = CGFloat(i) / CGFloat(steps)
                points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        func corner(center: CGPoint, from angle: CGFloat) {
            for i in 0..<3 {
                let a = angle + CGFloat(i) * (.pi / 2) / 3
                points.append(CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a)))
            }
        }
        let minX = rect.minX, maxX = rect.maxX, minY = rect.minY, maxY = rect.maxY
        side(from: CGPoint(x: minX + r, y: minY), to: CGPoint(x: maxX - r, y: minY))
        corner(center: CGPoint(x: maxX - r, y: minY + r), from: -.pi / 2)
        side(from: CGPoint(x: maxX, y: minY + r), to: CGPoint(x: maxX, y: maxY - r))
        corner(center: CGPoint(x: maxX - r, y: maxY - r), from: 0)
        side(from: CGPoint(x: maxX - r, y: maxY), to: CGPoint(x: minX + r, y: maxY))
        corner(center: CGPoint(x: minX + r, y: maxY - r), from: .pi / 2)
        side(from: CGPoint(x: minX, y: maxY - r), to: CGPoint(x: minX, y: minY + r))
        corner(center: CGPoint(x: minX + r, y: minY + r), from: .pi)

        var state = seed &+ UInt64(min(rect.width, 100_000) * 10) &* 31 &+ UInt64(min(rect.height, 100_000) * 10)
        func next() -> CGFloat {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            z ^= z >> 31
            return CGFloat(Double(z % 2001) / 1000.0 - 1.0)
        }
        let shaken = points.map { CGPoint(x: $0.x + next() * jitter, y: $0.y + next() * jitter) }

        var path = Path()
        guard shaken.count > 2 else { return path }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(shaken[shaken.count - 1], shaken[0]))
        for i in 0..<shaken.count {
            let next = shaken[(i + 1) % shaken.count]
            path.addQuadCurve(to: mid(shaken[i], next), control: shaken[i])
        }
        path.closeSubpath()
        return path
    }
}

extension View {
    /// Карточка с контуром «от руки» и смещённой цветной тенью
    func newCard(radius: CGFloat = 14, fill: Color = Color.cardBackground, shadow: Color = NewStyle.blue, offset: CGFloat = 4) -> some View {
        background {
            ZStack {
                RoughRoundedRect(radius: radius, seed: 3).fill(shadow).offset(x: offset, y: offset)
                RoughRoundedRect(radius: radius, seed: 1).fill(fill)
            }
        }
        .overlay(RoughRoundedRect(radius: radius, seed: 1).stroke(NewStyle.outline, style: NewStyle.stroke))
    }

    /// «Скетч»: контур и смещённая цветная тень поверх уже заданной заливки; в классическом виде ничего не меняет
    @ViewBuilder
    func sketchFrame(_ on: Bool, radius: CGFloat = 12, shadow: Color = NewStyle.blue, offset: CGFloat = 3) -> some View {
        if on {
            self
                .overlay(RoughRoundedRect(radius: radius, seed: 5).stroke(NewStyle.outline, style: NewStyle.stroke))
                .background(RoughRoundedRect(radius: radius, seed: 9).fill(shadow).offset(x: offset, y: offset))
        } else {
            self
        }
    }
}

/// Кнопка нового стиля: контур, смещённая тень; `isMain` — жёлтая
struct NewButtonLabel: View {
    let title: String
    var systemImage: String?
    var isMain = false

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .scaledFont(size: 16, weight: .semibold)
        .foregroundStyle(isMain ? NewStyle.onYellow : Color.brandDark)
        .frame(maxWidth: .infinity, minHeight: 50)
        .newCard(radius: 14, fill: isMain ? NewStyle.yellow : Color.cardBackground, shadow: isMain ? NewStyle.yellowShadow : NewStyle.blue, offset: 3)
    }
}

/// Обложка с контуром «от руки» и цветной смещённой тенью
struct NewCover: View {
    let book: Book
    var shadow: Color = NewStyle.peach
    var offset: CGFloat = 6

    var body: some View {
        let seed = StableSeed.of(book.title)
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay { BookCover(data: book.coverData, title: book.title, author: book.author) }
            .clipShape(RoughRoundedRect(radius: 8, seed: seed))
            .overlay(RoughRoundedRect(radius: 8, seed: seed).stroke(NewStyle.outline, style: NewStyle.stroke))
            .background(RoughRoundedRect(radius: 8, seed: seed &+ 1).fill(shadow).offset(x: offset, y: offset))
    }
}

/// Вкладки «Скетча»: пилюли с контуром, выбранная — жёлтая
struct SketchTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: KeyPath<Item, String>
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { item in
                let isOn = item == selection
                Button { withAnimation { selection = item } } label: {
                    Text(item[keyPath: title])
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundStyle(isOn ? NewStyle.onYellow : Color.brandDark)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoughRoundedRect(radius: 22, seed: 4).fill(isOn ? NewStyle.yellow : Color.cardBackground))
                        .sketchFrame(true, radius: 22, shadow: isOn ? NewStyle.yellowShadow : NewStyle.blue.opacity(0), offset: 3)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// Полоска прогресса «Скетча»: контур, жёлтая заливка
struct SketchProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoughRoundedRect(radius: 4.5, seed: 2, jitter: 0.4).fill(Color.cardBackground)
                RoughRoundedRect(radius: 4.5, seed: 2, jitter: 0.4).fill(NewStyle.yellow)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 10)
        .overlay(RoughRoundedRect(radius: 4.5, seed: 2, jitter: 0.4).stroke(NewStyle.outline, style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)))
    }
}

extension View {
    /// Плашка блока: в «Скетче» — контур «от руки» с синей смещённой тенью, иначе тонкая рамка
    func lxFill(radius: CGFloat = 14) -> some View {
        Group {
            if AppDesign.isSketch {
                background(Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .sketchFrame(true, radius: radius, shadow: NewStyle.blue, offset: 3)
            } else {
                background(Color.brandFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
    }

    /// Выбираемая плашка (переключатель из двух-трёх): в «Скетче» выбранная — жёлтая с контуром
    func lxSelectable(isOn: Bool, radius: CGFloat = 14) -> some View {
        Group {
            if AppDesign.isSketch {
                background(isOn ? NewStyle.yellow : Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .sketchFrame(true, radius: radius, shadow: isOn ? NewStyle.yellowShadow : NewStyle.blue, offset: 3)
            } else {
                background(isOn ? Color.brandAccent : Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(isOn ? Color.clear : Color.brandBorder, lineWidth: 1))
            }
        }
    }

    /// Крупный заголовок экрана: Neucha в «Скетче», иначе шрифт с засечками
    func lxScreenTitle() -> some View {
        scaledFont(size: AppDesign.isSketch ? 38 : 32, weight: .medium, design: AppDesign.isSketch ? .rounded : .serif)
    }

    /// Название книги в каталоге: PT Serif Bold в «Скетче», иначе системный шрифт с засечками
    func lxBookTitleFont() -> some View {
        Group {
            if AppDesign.isSketch {
                scaledFont(size: 17, weight: .semibold, design: .serif)
            } else {
                font(.system(.body, design: .serif).weight(.semibold))
            }
        }
    }

    /// Плашка, как раньше без рамки; в «Скетче» — с контуром и тенью
    func cardPlate(radius: CGFloat) -> some View {
        Group {
            if AppDesign.isSketch { lxPlate(radius: radius) }
            else { background(Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous)) }
        }
    }

    func lxPlate(radius: CGFloat = 18) -> some View {
        background(Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(AppDesign.isSketch ? Color.clear : Color.brandBorder, lineWidth: 1))
            .sketchFrame(AppDesign.isSketch, radius: radius, shadow: NewStyle.blue, offset: 3)
    }
}

/// Нижняя панель вкладок в «Скетче»: белый фон, линия сверху, у выбранной вкладки жёлтая пилюля с контуром.
/// Настройка действует на панели, созданные после вызова (при смене оформления приложение перестраивается)
enum SketchChrome {
    @MainActor
    static func apply(_ sketch: Bool) {
        // Заголовки экранов (навигация): PT Sans Bold в «Скетче», системные иначе
        UINavigationBar.appearance().titleTextAttributes = sketch
            ? [.font: UIFont(name: "PTSans-Bold", size: 17) ?? UIFont.boldSystemFont(ofSize: 17)] : nil
        applySegmented(sketch)
        let tabBar = UITabBar.appearance()
        guard sketch else {
            tabBar.standardAppearance = UITabBarAppearance()
            tabBar.scrollEdgeAppearance = nil
            return
        }
        let ink = UIColor(NewStyle.outline)
        let muted = UIColor(red: 0.369, green: 0.353, blue: 0.322, alpha: 1)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.cardBackground)
        appearance.shadowColor = ink
        appearance.selectionIndicatorImage = pill(itemWidth: UIScreen.main.bounds.width / 4)
        let titleFont = UIFont(name: "PTSans-Bold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = muted
            item.normal.titleTextAttributes = [.foregroundColor: muted, .font: titleFont]
            item.selected.iconColor = ink
            item.selected.titleTextAttributes = [.foregroundColor: ink, .font: titleFont]
        }
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    /// Сегментные переключатели: плашки с контуром, выбранный сегмент жёлтый, надписи PT Sans
    @MainActor
    private static func applySegmented(_ sketch: Bool) {
        let control = UISegmentedControl.appearance()
        guard sketch else {
            for state in [UIControl.State.normal, .selected] {
                control.setBackgroundImage(nil, for: state, barMetrics: .default)
                control.setTitleTextAttributes(nil, for: state)
            }
            control.setDividerImage(nil, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
            control.selectedSegmentTintColor = nil
            return
        }
        func plate(fill: UIColor, stroke: UIColor, width: CGFloat) -> UIImage {
            let size = CGSize(width: 28, height: 32)
            return UIGraphicsImageRenderer(size: size).image { _ in
                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: width / 2, dy: width / 2), cornerRadius: 10)
                fill.setFill(); path.fill()
                stroke.setStroke(); path.lineWidth = width; path.stroke()
            }.resizableImage(withCapInsets: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12), resizingMode: .stretch)
        }
        let ink = UIColor(NewStyle.outline)
        control.setBackgroundImage(plate(fill: UIColor(Color.cardBackground), stroke: ink.withAlphaComponent(0.35), width: 1), for: .normal, barMetrics: .default)
        let selected = plate(fill: UIColor(NewStyle.yellow), stroke: ink, width: 1.5)
        control.setBackgroundImage(selected, for: .selected, barMetrics: .default)
        control.setBackgroundImage(selected, for: [.selected, .highlighted], barMetrics: .default)
        control.setDividerImage(UIImage(), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        control.setDividerImage(UIImage(), forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        control.setDividerImage(UIImage(), forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
        let font = UIFont(name: "PTSans-Bold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        control.setTitleTextAttributes([.font: font, .foregroundColor: ink], for: .normal)
        control.setTitleTextAttributes([.font: font, .foregroundColor: UIColor(NewStyle.onYellow)], for: .selected)
    }

    /// Жёлтая пилюля 58×32 с контуром и тёмно-жёлтой тенью под иконкой выбранной вкладки
    @MainActor
    private static func pill(itemWidth: CGFloat) -> UIImage {
        let size = CGSize(width: itemWidth, height: 49)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(x: (size.width - 58) / 2, y: 2, width: 58, height: 32)
            let shadow = UIBezierPath(roundedRect: rect.offsetBy(dx: 0, dy: 2), cornerRadius: 16)
            UIColor(NewStyle.yellowShadow).setFill()
            shadow.fill()
            let body = UIBezierPath(roundedRect: rect, cornerRadius: 16)
            UIColor(NewStyle.yellow).setFill()
            body.fill()
            UIColor(NewStyle.outline).setStroke()
            body.lineWidth = 1.5
            body.stroke()
        }
    }
}

private nonisolated extension UIColor {
    /// Темнее на долю `amount`: тень под цветной заливкой
    func blended(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount), alpha: a)
    }
}

/// Форма настроек: в «Скетче» — карточки с контуром вместо системного списка. Разделы (`Section`) разбираются как есть:
/// заголовок над карточкой, строки с разделителями внутри, пояснение под ней. Классический вид — обычный `Form`
struct LXForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if AppDesign.isSketch {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Group(sections: content) { sections in
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.brandBackground)
            // Кнопки и ссылки в строках — тёмные, а не системный синий
            .tint(NewStyle.outline)
            .font(.custom("PTSans-Regular", size: 17, relativeTo: .body))
            .navigationLinkIndicatorVisibility(.visible)
        } else {
            Form { content }
        }
    }

    private func sectionView(_ section: SectionConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group(subviews: section.header) { header in
                if !header.isEmpty { header[0].padding(.horizontal, 4) }
            }
            Group(subviews: section.content) { rows in
                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { index in
                            rows[index]
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            if index < rows.count - 1 { LXDivider() }
                        }
                    }
                    .lxPlate(radius: 18)
                }
            }
            Group(subviews: section.footer) { footer in
                if !footer.isEmpty {
                    footer[0]
                        .scaledFont(size: 13)
                        .foregroundStyle(Color.brandMuted)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - Нижняя панель «Скетча»

/// Вкладка своей нижней панели
struct SketchTabItem {
    let title: String
    let icon: String
    let selectedIcon: String
}

/// Что рисует своя нижняя панель: вкладки, выбранная и что делать при нажатии. Задаётся один раз на `TabView`
struct SketchTabBarConfig {
    let items: [SketchTabItem]
    let selected: Int
    let select: (Int) -> Void
}

private struct SketchTabBarKey: EnvironmentKey {
    static let defaultValue: SketchTabBarConfig? = nil
}

extension EnvironmentValues {
    var sketchTabBar: SketchTabBarConfig? {
        get { self[SketchTabBarKey.self] }
        set { self[SketchTabBarKey.self] = newValue }
    }
}

/// Панель вкладок «Скетча»: белый фон, линия сверху, у выбранной вкладки жёлтая пилюля с контуром.
/// Системная панель iOS 18 не даёт нарисовать пилюлю, поэтому в «Скетче» она скрыта, а эта стоит внизу корневого экрана каждой вкладки
/// (на вложенных экранах её нет — они закрывают корневой экран, как раньше закрывали системную панель)
private struct SketchTabBarInset: ViewModifier {
    @Environment(\.sketchTabBar) private var config
    @State private var isKeyboardShown = false

    func body(content: Content) -> some View {
        if AppDesign.isSketch, let config {
            content
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !isKeyboardShown { bar(config) }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardShown = true }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardShown = false }
        } else {
            content
        }
    }

    private func bar(_ config: SketchTabBarConfig) -> some View {
        HStack(spacing: 0) {
            ForEach(config.items.indices, id: \.self) { index in
                let item = config.items[index]
                let isOn = index == config.selected
                Button {
                    guard !isOn else { return }
                    config.select(index)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isOn ? item.selectedIcon : item.icon)
                            .scaledFont(size: 20)
                            .foregroundStyle(isOn ? NewStyle.onYellow : Color.brandMuted)
                            .frame(width: 58, height: 32)
                            .background {
                                if isOn {
                                    RoughRoundedRect(radius: 16, seed: UInt64(index + 3)).fill(NewStyle.yellow)
                                }
                            }
                            .overlay {
                                if isOn {
                                    RoughRoundedRect(radius: 16, seed: UInt64(index + 3)).stroke(NewStyle.outline, style: NewStyle.stroke)
                                }
                            }
                        Text(item.title)
                            .scaledFont(size: 11, weight: .bold)
                            .foregroundStyle(isOn ? Color.brandDark : Color.brandMuted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.cardBackground.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(NewStyle.outline.opacity(0.7)).frame(height: NewStyle.lineWidth) }
    }
}

extension View {
    /// Своя нижняя панель «Скетча» внизу корневого экрана вкладки (рядом с `modeSwitcherInset`)
    func sketchTabBarInset() -> some View { modifier(SketchTabBarInset()) }
}
