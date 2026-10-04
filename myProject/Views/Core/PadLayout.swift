import SwiftUI

/// Вёрстка под iPad. Всё, что здесь, срабатывает только на iPad — на iPhone экраны остаются как были
enum PadLayout {
    static let isPad = UIDevice.current.userInterfaceIdiom == .pad
    /// Ширина колонки: на экране iPad в 1000+ точек строки и карточки во всю ширину читать неудобно
    static let columnWidth: CGFloat = 680
    /// Плитки «Обзора» и «Сообщества»: на iPad крупнее, на iPhone — 150 × 96, как были
    static let tileSize = isPad ? CGSize(width: 210, height: 134) : CGSize(width: 150, height: 96)
    /// Карточка «Слова дня» на iPad не шире этого — иначе картинка растягивается на весь экран
    static let wordOfDayMaxWidth: CGFloat = isPad ? 560 : .infinity
}

extension View {
    /// На iPad — колонка по центру, по бокам фон приложения; на iPhone ничего не меняет
    func readableColumn(_ maxWidth: CGFloat = PadLayout.columnWidth) -> some View {
        modifier(ReadableColumn(maxWidth: maxWidth))
    }
}

private struct ReadableColumn: ViewModifier {
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if PadLayout.isPad {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
                .background(Color.brandBackground.ignoresSafeArea())
        } else {
            content
        }
    }
}
