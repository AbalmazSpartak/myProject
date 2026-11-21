import SwiftUI

/// Детали «Нового стиля»: тонкий тёмный контур и цветная смещённая тень у карточек и кнопок, пастельные круги, жёлтая главная кнопка
enum NewStyle {
    static let yellow = Color(red: 0.922, green: 0.749, blue: 0.278)
    static let blue = Color(red: 0.447, green: 0.686, blue: 0.890)
    static let peach = Color(red: 0.937, green: 0.710, blue: 0.620)
    static let outline = Color.brandDark
    static let lineWidth: CGFloat = 1.5
    static let yellowShadow = Color(red: 0.710, green: 0.541, blue: 0.118)

    /// Пастельные круги разделов: читаю, слушаю, закладки, подписки
    static let pastels: [Color] = [
        Color(red: 1.0, green: 0.949, blue: 0.80),
        Color(red: 0.867, green: 0.929, blue: 0.984),
        Color(red: 0.941, green: 0.867, blue: 0.918),
        Color(red: 0.867, green: 0.941, blue: 0.867)
    ]
}

extension View {
    /// Карточка с контуром и смещённой цветной тенью
    func newCard(radius: CGFloat = 14, fill: Color = Color.cardBackground, shadow: Color = NewStyle.blue, offset: CGFloat = 4) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(shadow).offset(x: offset, y: offset)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(NewStyle.outline, lineWidth: NewStyle.lineWidth))
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
        .newCard(radius: 14, fill: isMain ? NewStyle.yellow : Color.cardBackground, shadow: isMain ? NewStyle.yellowShadow : NewStyle.blue.opacity(0.0), offset: 3)
    }
}

/// Обложка с контуром и персиковой смещённой тенью
struct NewCover: View {
    let book: Book
    var shadow: Color = NewStyle.peach
    var offset: CGFloat = 6

    var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay { BookCover(data: book.coverData, title: book.title) }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(NewStyle.outline, lineWidth: NewStyle.lineWidth))
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(shadow).offset(x: offset, y: offset))
    }
}

/// Вкладки «Скетча»: пилюли с контуром, выбранная — жёлтая
struct SketchTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: KeyPath<Item, String>
    @Binding var selection: Item

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                let isOn = item == selection
                Button { withAnimation { selection = item } } label: {
                    Text(item[keyPath: title])
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(isOn ? Color.black : Color.brandDark)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(isOn ? NewStyle.yellow : Color.cardBackground))
                        .overlay(Capsule().stroke(NewStyle.outline, lineWidth: NewStyle.lineWidth))
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
                Capsule().fill(Color.cardBackground)
                Capsule().fill(NewStyle.yellow).frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: 9)
        .overlay(Capsule().stroke(NewStyle.outline, lineWidth: 1))
    }
}

extension View {
    /// «Скетч»: контур и смещённая цветная тень поверх уже заданной заливки; в классическом виде ничего не меняет
    @ViewBuilder
    func sketchFrame(_ on: Bool, radius: CGFloat = 12, shadow: Color = NewStyle.blue, offset: CGFloat = 3) -> some View {
        if on {
            self
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(NewStyle.outline, lineWidth: NewStyle.lineWidth))
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(shadow).offset(x: offset, y: offset))
        } else {
            self
        }
    }
}
