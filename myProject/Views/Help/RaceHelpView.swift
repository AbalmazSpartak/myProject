import SwiftUI

struct RaceHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Идея", icon: "lightbulb.fill", color: .yellow) {
                    HelpParagraph("Соревнование на скорость для двух и более игроков, которые находятся рядом. Побеждает тот, кто правильно переведёт больше слов.")
                }

                HelpCard(title: "Как начать", icon: "list.number", color: .green) {
                    HelpStep(number: 1, text: "Телефоны должны быть рядом, в одной сети Wi-Fi. Разрешите приложению доступ к локальной сети, если появится запрос.")
                    HelpStep(number: 2, text: "Один игрок нажимает «Создать комнату», остальные — «Найти комнату» и выбирают её в списке.")
                    HelpStep(number: 3, text: "Когда все подключились, создатель комнаты нажимает «Начать гонку».")
                }

                HelpCard(title: "Правила", icon: "flag.checkered", color: .indigo) {
                    HelpBullet("У всех одни и те же 10 слов. Для каждого нужно выбрать перевод из трёх вариантов.")
                    HelpBullet("Правильный ответ сразу переводит к следующему слову, ошибка блокирует ответы на секунду.")
                    HelpBullet("Гонка заканчивается для всех, как только кто-то ответит на все слова.")
                    HelpBullet("Места — по числу правильных ответов, при равенстве выше тот, кто закончил быстрее.")
                }

                HelpCard(title: "Полезно знать", icon: "info.circle.fill", color: .gray) {
                    HelpBullet("Слова берутся из словарей, выбранных в настройках у создателя комнаты.")
                    HelpBullet("Ваше имя в гонке — имя из профиля.")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Гонка слов")
        .navigationBarTitleDisplayMode(.inline)
    }
}
