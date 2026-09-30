import SwiftUI

struct FlashcardsHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Идея метода", icon: "lightbulb.fill", color: .yellow) {
                    HelpParagraph("Карточки работают по принципу интервального повторения: слово возвращается к вам именно тогда, когда вы начинаете его забывать. Так память закрепляет его надёжнее, чем при зубрёжке подряд.")
                    HelpParagraph("Расписание повторений рассчитывает алгоритм FSRS. Он подбирает интервалы так, чтобы вы вспоминали слово примерно в 90% случаев.")
                }

                HelpCard(title: "Как заниматься", icon: "list.number", color: .blue) {
                    HelpStep(number: 1, text: "Посмотрите на слово и постарайтесь вспомнить перевод — лучше вслух.")
                    HelpStep(number: 2, text: "Нажмите «Показать ответ» и сверьтесь.")
                    HelpStep(number: 3, text: "Честно оцените, насколько легко было вспомнить.")
                }

                HelpCard(title: "Кнопки оценки", icon: "hand.tap.fill", color: .purple) {
                    HelpRating(title: "Снова", color: .red, text: "Не вспомнили. Слово вернётся через 5 минут и попадёт в «Работу над ошибками».")
                    HelpRating(title: "Трудно", color: .orange, text: "Вспомнили с большим усилием. Следующий интервал будет коротким.")
                    HelpRating(title: "Хорошо", color: .green, text: "Вспомнили после небольшой паузы. Интервал заметно вырастет, слово уйдёт из ошибок.")
                    HelpRating(title: "Легко", color: .blue, text: "Вспомнили сразу. Интервал вырастет сильнее всего.")
                    HelpParagraph("Чем честнее оценка, тем точнее расписание. Если завышать её, трудные слова будут появляться слишком редко.")
                }

                HelpCard(title: "Режимы", icon: "line.3.horizontal.decrease.circle.fill", color: .teal) {
                    HelpBullet("«На повторение» — новые слова и те, чей срок повторения подошёл. Основной режим для ежедневных занятий.")
                    HelpBullet("«Работа над ошибками» — слова, на которых вы нажали «Снова».")
                    HelpBullet("«Все слова», категории и уровни A1–C2 — для тренировки по выбранной теме.")
                    HelpParagraph("Режим переключается кнопкой в правом верхнем углу. Оценки в любом режиме влияют на расписание слова.")
                }

                HelpCard(title: "Полезно знать", icon: "info.circle.fill", color: .indigo) {
                    HelpBullet("Кнопка с динамиком озвучивает английское слово.")
                    HelpBullet("Вместе с ответом показывается картинка к слову — она помогает связать слово с образом. Картинка загружается из интернета один раз и дальше доступна без сети.")
                    HelpBullet("Если картинка не подходит, нажмите ↻ — появится другая, или 👁 — чтобы скрыть её для этого слова.")
                    HelpBullet("Картинки можно отключить в профиле: ⚙️ → «Обучение» → «Картинки к словам».")
                }

                HelpCard(title: "Советы", icon: "star.fill", color: .orange) {
                    HelpBullet("Занимайтесь каждый день понемногу — 10–15 минут эффективнее, чем час раз в неделю.")
                    HelpBullet("Начинайте с режима «На повторение», пока он не опустеет.")
                    HelpBullet("Не подглядывайте в ответ, пока не попробуете вспомнить сами.")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Карточки для запоминания")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Компоненты справки

struct HelpCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.brandDark)
            }

            Divider()

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct HelpParagraph: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(.brandDark)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct HelpBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .foregroundColor(.gray)
            HelpParagraph(text)
        }
    }
}

struct HelpStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue))
            HelpParagraph(text)
        }
    }
}

struct HelpRating: View {
    let title: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 64)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .cornerRadius(8)
            HelpParagraph(text)
        }
    }
}
