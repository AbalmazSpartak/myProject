import WidgetKit
import SwiftUI

/// Виджеты приложения в галерее: «Повторение» и «Серия дней»
@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
        StreakWidget()
    }
}
