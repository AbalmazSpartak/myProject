import SwiftUI

/// Урок 2: местоимения во второй форме, вопросительные слова, предлоги направления — и упражнение
struct PolyglotLesson2View: View {
    var body: some View {
        PolyglotLessonPage(number: 2, title: "Местоимения, вопросы, предлоги",
                           videoURL: URL(string: "https://youtu.be/85wd0n9g2HY"),
                           makeRound: { PolyglotLesson2.round() }) {
            PolyglotParagraph("Схема глаголов — та же, что в уроке 1. Теперь к ней добавляются: кого и кому (me, him, them…), вопросительные слова (what, where…) и предлоги направления (in, to, from).")

            PolyglotHeading("Тысячи слов за минуту")
            PolyglotParagraph("Многие слова вы уже знаете. Русское -ция почти всегда становится английским -tion, а -сия — -sion: корень тот же.")
            PolyglotGridTable(rows: [
                ["Русский", "Английский"],
                ["нация", "nation"],
                ["станция", "station"],
                ["информация", "information"],
                ["ситуация", "situation"],
                ["традиция", "tradition"],
                ["профессия", "profession"],
                ["версия", "version"],
                ["миссия", "mission"],
                ["дискуссия", "discussion"],
            ])

            PolyglotLesson2Reference()

            PolyglotHeading("Примеры")
            PolyglotExamples(examples: [
                ("I see him.", "Я вижу его."),
                ("She loves you.", "Она любит тебя."),
                ("We help them.", "Мы помогаем им."),
                ("What did you take?", "Что ты взял?"),
                ("Where do you live?", "Где ты живёшь?"),
                ("When will she help?", "Когда она поможет?"),
                ("Why do you ask?", "Почему ты спрашиваешь?"),
                ("How do you work?", "Как ты работаешь?"),
                ("I will come to you.", "Я приду к тебе."),
                ("You fly from Moscow.", "Ты летишь из Москвы."),
                ("He lives in a house.", "Он живёт в доме."),
                ("We worked in London.", "Мы работали в Лондоне."),
            ])
            PolyglotParagraph("Who — особый случай. Если «кто» — это тот, кто действует, do, does и did не нужны: **Who knows?** — «Кто знает?», **Who helped?** — «Кто помог?».")

            PolyglotHeading("Слова для запоминания")
            PolyglotGridTable(rows: [
                ["Слово", "Перевод"],
                ["ask", "просить, спрашивать"],
                ["answer", "отвечать"],
                ["help", "помогать"],
                ["hope", "надеяться"],
                ["travel", "путешествовать"],
                ["give (gave)", "давать"],
                ["take (took)", "брать"],
                ["speak (spoke)", "говорить"],
            ])
        } scheme: {
            VStack(spacing: 20) {
                PolyglotLesson2Reference()
                PolyglotTableView()
            }
        }
    }
}

/// Таблицы урока 2 — и в уроке, и в подсказке «Схема» во время упражнения
struct PolyglotLesson2Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Местоимения: кто? и кого? кому?")
            PolyglotGridTable(rows: [
                ["Кто?", "Кого? Кому?"],
                ["I — я", "me — меня, мне"],
                ["you — ты, вы", "you — тебя, тебе, вас, вам"],
                ["he — он", "him — его, ему"],
                ["she — она", "her — её, ей"],
                ["we — мы", "us — нас, нам"],
                ["they — они", "them — их, им"],
            ])
            note("Падежей в английском нет: одна форма и для «кого», и для «кому» — I see **him**, I help **him**.")

            title("Вопросительные слова")
            PolyglotGridTable(rows: [
                ["Слово", "Перевод"],
                ["what", "что, какой"],
                ["where", "где, куда"],
                ["when", "когда"],
                ["why", "почему, зачем"],
                ["who", "кто"],
                ["how", "как, каким образом"],
            ])
            note("Вопросительное слово встаёт перед схемой вопроса: **Where** do you live? Слова сочетаются: **how much** — сколько.")

            title("Предлоги направления")
            PolyglotGridTable(rows: [
                ["Предлог", "Значение"],
                ["in", "в, внутри — где?"],
                ["to", "к, в — куда? к кому?"],
                ["from", "из, от — откуда? от кого?"],
            ])
            note("По-русски «в» бывает и «где», и «куда»: в Лондоне — **in** London, в Лондон — **to** London.")
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 20, weight: .semibold, design: .serif)
            .foregroundColor(.brandDark)
            .padding(.top, 6)
    }

    private func note(_ text: String) -> some View {
        Text(TopicText.attributed(text))
            .scaledFont(size: 15)
            .foregroundColor(.brandDark)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Простая таблица в стиле схемы урока 1: тонкие линии, первая строка — шапка
struct PolyglotGridTable: View {
    let rows: [[String]]
    /// Узкий первый столбец под короткие подписи (in, a, -er); nil — все столбцы поровну
    var firstColumnWidth: CGFloat? = nil
    /// Меньше — для широких таблиц, чтобы длинные слова (everywhere) не рвались посередине
    var fontSize: CGFloat = 15

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                        if column > 0 {
                            Rectangle().fill(Color.brandDark.opacity(0.3)).frame(width: 1)
                        }
                        Text(cell)
                            .scaledFont(size: fontSize, weight: index == 0 ? .semibold : .regular)
                            .foregroundColor(.brandDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(width: column == 0 ? firstColumnWidth : nil)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(index == 0 ? Color.brandFill : Color.cardBackground)
                if index < rows.count - 1 {
                    Rectangle().fill(Color.brandDark.opacity(0.3)).frame(height: 1)
                }
            }
        }
        .overlay(Rectangle().stroke(Color.brandDark.opacity(0.6), lineWidth: 1))
    }
}
