import SwiftUI

struct TetrisHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Идея", icon: "lightbulb.fill", color: .yellow) {
                    HelpParagraph("Обычный тетрис, в котором знание слов помогает: пока падают фигуры, вверху показано английское слово и три варианта перевода.")
                }

                HelpCard(title: "Управление", icon: "hand.draw.fill", color: .indigo) {
                    HelpBullet("Коснитесь поля — фигура повернётся.")
                    HelpBullet("Ведите палец влево или вправо — фигура сдвигается вслед за ним.")
                    HelpBullet("Ведите палец вниз и держите — фигура падает быстрее.")
                    HelpBullet("⏸ в шапке ставит игру на паузу.")
                }

                HelpCard(title: "Слова", icon: "textformat.abc", color: .purple) {
                    HelpBullet("Правильный перевод замедляет падение фигур на 5 секунд — успеете уложить их аккуратнее.")
                    HelpBullet("Ошибка отправляет слово в «Работу над ошибками». Такие слова показываются в первую очередь.")
                    HelpBullet("Когда собираете линию, слово озвучивается, уходит из ошибок и сменяется новым.")
                }

                HelpCard(title: "Очки", icon: "star.fill", color: .orange) {
                    HelpBullet("За каждую собранную линию — 100 очков. Чем больше очков, тем быстрее падают фигуры.")
                    HelpBullet("Игра заканчивается, когда новой фигуре некуда упасть. Лучший результат сохраняется как рекорд в профиле.")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Тетрис слов")
        .navigationBarTitleDisplayMode(.inline)
    }
}
