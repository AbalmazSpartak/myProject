import SwiftUI

struct InputCardsHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Идея", icon: "lightbulb.fill", color: .yellow) {
                    HelpParagraph("Самый строгий способ проверить себя: перевод нужно не узнать среди вариантов, а написать самому.")
                }

                HelpCard(title: "Как заниматься", icon: "list.number", color: .teal) {
                    HelpStep(number: 1, text: "Прочитайте слово — кнопка с динамиком его озвучит.")
                    HelpStep(number: 2, text: "Впишите перевод и нажмите «Проверить» (или «Ввод» на клавиатуре).")
                    HelpStep(number: 3, text: "После проверки появится пример с этим словом, а при ошибке — и правильный ответ. Нажмите «Следующее слово».")
                }

                HelpCard(title: "Как проверяется ответ", icon: "checkmark.circle.fill", color: .green) {
                    HelpBullet("Подходит любой из вариантов перевода, записанных через запятую: для «ability» — «способность» или «умение».")
                    HelpBullet("Пояснение в скобках писать не нужно: для «статья (в газете)» достаточно «статья».")
                    HelpBullet("Регистр не важен, «е» и «ё» не различаются.")
                    HelpBullet("Ошибка отправляет слово в «Работу над ошибками», правильный ответ — убирает из неё.")
                }

                HelpCard(title: "Режимы", icon: "line.3.horizontal.decrease.circle.fill", color: .indigo) {
                    HelpBullet("«Все слова», «Работа над ошибками», темы и уровни A1–C2 — переключаются кнопкой в правом верхнем углу.")
                    HelpBullet("Направление (англ ➔ рус или рус ➔ англ) меняется в профиле: ⚙️ → «Обучение».")
                    HelpBullet("Ответы засчитываются в статистику карточек в профиле.")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Карточки ввода")
        .navigationBarTitleDisplayMode(.inline)
    }
}
