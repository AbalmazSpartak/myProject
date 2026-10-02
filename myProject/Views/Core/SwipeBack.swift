import SwiftUI
import UIKit

/// Свайп «назад» от левого края. Разделы прячут системную полосу навигации ради своих шапок,
/// а SwiftUI вместе с полосой отключает и этот жест — включаем его обратно
enum SwipeBack {
    /// Сколько открытых экранов запретили жест (например, Тетрис: там палец ведёт фигуру)
    fileprivate static var disabledCount = 0
}

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && SwipeBack.disabledCount == 0
    }
}

extension View {
    /// Запрещает свайп «назад», пока экран открыт: выйти можно только кнопкой
    func swipeBackDisabled() -> some View {
        onAppear { SwipeBack.disabledCount += 1 }
            .onDisappear { SwipeBack.disabledCount -= 1 }
    }
}
