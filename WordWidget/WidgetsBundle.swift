import WidgetKit
import SwiftUI

/// Виджеты приложения в галерее: «Повторение», «Серия дней», «Продолжить чтение» и «Слово дня из книги»
@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        WordWidget()
        StreakWidget()
        ReadingWidget()
        BookWordWidget()
    }
}
