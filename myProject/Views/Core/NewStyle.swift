import SwiftUI

/// Детали стиля «Скетч»: тонкий контур «от руки», цветная смещённая тень, пастельные круги, жёлтая главная кнопка
enum NewStyle {
    static let yellow = Color(red: 0.922, green: 0.749, blue: 0.278)
    static let blue = Color(red: 0.447, green: 0.686, blue: 0.890)
    static let peach = Color(red: 0.937, green: 0.710, blue: 0.620)
    static let outline = Color.brandDark
    static let lineWidth: CGFloat = 1.5
    static let yellowShadow = Color(red: 0.710, green: 0.541, blue: 0.118)

    /// Пастельные плашки: кремовая, голубая, розовая, зелёная
    static let pastels: [Color] = [
        Color(red: 1.0, green: 0.945, blue: 0.788),
        Color(red: 0.878, green: 0.929, blue: 0.980),
        Color(red: 0.941, green: 0.882, blue: 0.925),
        Color(red: 0.886, green: 0.937, blue: 0.863)
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

        var state = seed &+ UInt64(rect.width * 10) &* 31 &+ UInt64(rect.height * 10)
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
        .foregroundStyle(isMain ? Color.black : Color.brandDark)
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
            .overlay { BookCover(data: book.coverData, title: book.title) }
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
                        .foregroundStyle(isOn ? Color.black : Color.brandDark)
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
