import SwiftUI

struct QuizHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Как играть", icon: "list.number", color: .purple) {
                    HelpStep(number: 1, text: "Прочитайте слово — кнопка с динамиком его озвучит.")
                    HelpStep(number: 2, text: "Выберите один из четырёх вариантов перевода.")
                    HelpStep(number: 3, text: "Правильный вариант подсветится зелёным, ошибочный — красным. Нажмите «Следующее слово».")
                }

                HelpCard(title: "Ошибки", icon: "exclamationmark.triangle.fill", color: .orange) {
                    HelpBullet("Слово, на котором вы ошиблись, попадает в «Работу над ошибками» — общую для всех тренировок.")
                    HelpBullet("Правильный ответ на такое слово убирает его из ошибок.")
                }

                HelpCard(title: "Режимы", icon: "line.3.horizontal.decrease.circle.fill", color: .teal) {
                    HelpBullet("«Все слова» — слова из словарей, выбранных в настройках, вперемешку.")
                    HelpBullet("«Работа над ошибками» — только слова с ошибками.")
                    HelpBullet("Темы и уровни A1–C2 — тренировка по выбранной теме или уровню.")
                    HelpParagraph("Режим переключается кнопкой в правом верхнем углу. Под ней — счёт текущей сессии.")
                }

                HelpCard(title: "Полезно знать", icon: "info.circle.fill", color: .indigo) {
                    HelpBullet("Направление (англ ➔ рус или рус ➔ англ) меняется в профиле: ⚙️ → «Обучение».")
                    HelpBullet("Ответы засчитываются в статистику «Викторины» в профиле.")
                    HelpBullet("Викторина не меняет расписание повторений — для этого есть «Карточки для запоминания».")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Викторина")
        .navigationBarTitleDisplayMode(.inline)
    }
}
