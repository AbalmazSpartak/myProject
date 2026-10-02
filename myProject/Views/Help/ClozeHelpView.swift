import SwiftUI

struct ClozeHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Идея", icon: "lightbulb.fill", color: .yellow) {
                    HelpParagraph("Слово запоминается лучше, когда вы видите, как оно работает в предложении. Здесь из примера убрано изучаемое слово — его нужно вписать.")
                }

                HelpCard(title: "Как заниматься", icon: "list.number", color: .pink) {
                    HelpStep(number: 1, text: "Прочитайте предложение с пропуском. Под ним — перевод слова и часть речи.")
                    HelpStep(number: 2, text: "Впишите пропущенное слово по-английски и нажмите «Проверить», затем «Дальше».")
                    HelpStep(number: 3, text: "После проверки предложение озвучивается целиком — послушайте, как звучит слово в контексте.")
                }

                HelpCard(title: "Как проверяется ответ", icon: "checkmark.circle.fill", color: .green) {
                    HelpRating(title: "Верно", color: .green, text: "Вписана та же форма, что в предложении (например, captured).")
                    HelpRating(title: "Почти", color: .orange, text: "Вписана словарная форма, а в предложении другая (capture вместо captured). Засчитывается как правильный ответ.")
                    HelpRating(title: "Неверно", color: .red, text: "Слово попадает в «Работу над ошибками».")
                    HelpParagraph("Регистр букв не важен.")
                }

                HelpCard(title: "Полезно знать", icon: "info.circle.fill", color: .indigo) {
                    HelpBullet("Длина пропуска подсказывает длину слова. Кнопка подсказки откроет первую букву.")
                    HelpBullet("Здесь только слова с примерами из словарей, выбранных в настройках.")
                    HelpBullet("Счёт «Верно» в углу — только для текущей сессии, в статистику профиля он не идёт.")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Слово в контексте")
        .navigationBarTitleDisplayMode(.inline)
    }
}
