import SwiftUI

/// Урок 15: there is / there are в трёх временах
struct PolyglotLesson15View: View {
    var body: some View {
        PolyglotLessonPage(number: 15, title: "Есть, был, будет: there is",
                           videoURL: nil,
                           makeRound: { PolyglotLesson15.round() }) {
            PolyglotParagraph("«На столе есть книга», «в холодильнике нет молока», «в саду была кошка». Когда мы сообщаем, что где-то что-то есть или нет, по-английски начинают с **there is / there are** — даже если по-русски «есть» не говорят: «На кухне три стула».")

            PolyglotLesson15Reference()

            PolyglotHeading("Порядок слов")
            PolyglotParagraph("По-русски место обычно впереди, по-английски — в конце: **there is** + что + где.")
            PolyglotExamples(examples: [
                ("There is a bank near my house.", "Рядом с моим домом есть банк."),
                ("There are two cars in the yard.", "Во дворе две машины."),
                ("There was a strange noise at night.", "Ночью был странный шум."),
                ("There will be a party on Saturday.", "В субботу будет вечеринка."),
            ])

            PolyglotHeading("Is или are")
            PolyglotParagraph("По тому, что идёт сразу после: один предмет или то, что не считают (milk, water, sugar), — **is / was**; много — **are / were**. В будущем для всех — **will be**.")

            PolyglotHeading("Вопрос и отрицание")
            PolyglotExamples(examples: [
                ("Is there a pharmacy here?", "Здесь есть аптека?"),
                ("Are there any questions?", "Есть вопросы?"),
                ("There isn't any bread left.", "Хлеба не осталось."),
                ("There won't be enough time.", "Времени не хватит."),
            ])

            PolyglotHeading("Some и any")
            PolyglotParagraph("Со многими предметами и с тем, что не считают: **some** — в утверждении, **any** — в вопросе и отрицании. С одним предметом — **a / an**.")

            PolyglotHeading("Есть — это не всегда have")
            PolyglotParagraph("«У меня есть собака» — **I have** a dog: у кого-то есть. «В парке есть собака» — **there is** a dog in the park: где-то есть.")
        } scheme: {
            PolyglotLesson15Reference()
        }
    }
}

struct PolyglotLesson15Reference: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PolyglotHeading("There is / there are")
            PolyglotGridTable(rows: [
                ["", "Да", "Нет", "Вопрос"],
                ["Есть", "There is a cat. / There are cats.", "There isn't… / aren't…", "Is there…? / Are there…?"],
                ["Было", "There was… / were…", "There wasn't… / weren't…", "Was there…? / Were there…?"],
                ["Будет", "There will be…", "There won't be…", "Will there be…?"],
            ], firstColumnWidth: 60, fontSize: 13)
            PolyglotParagraph("Один — a / an; много и неисчисляемое — **some**, в вопросе и отрицании — **any**.")
        }
    }
}
