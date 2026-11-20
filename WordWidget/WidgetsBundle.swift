import WidgetKit
import SwiftUI

/// Виджеты приложения в галерее: «Повторение», «Серия дней» и «Продолжить чтение»
@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
        StreakWidget()
        ReadingWidget()
    }
}
