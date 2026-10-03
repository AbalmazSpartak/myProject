import SwiftUI

struct CommunityHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HelpCard(title: "Что здесь", icon: "person.3.fill", color: .cyan) {
                    HelpParagraph("Темы с текстом и словами, разложенные по разделам: «Английский по кино», «Подборки слов» и разделы, которые создают сами пользователи, например «Грамматика».")
                    HelpBullet("Пока темы хранятся только на этом телефоне. Позже их будут видеть все пользователи приложения.")
                    HelpBullet("Ленты «Ваши подборки» и «Английский по кино» внизу — пример того, как будут выглядеть разделы.")
                }

                HelpCard(title: "Создать тему", icon: "square.and.pencil", color: .cyan) {
                    HelpBullet("Кнопка ＋ вверху или «Создать тему».")
                    HelpBullet("Выберите раздел или «Новый раздел…» и впишите название — тема появится в ленте этого раздела.")
                    HelpBullet("Заголовок обязателен, текст и слова — по желанию. Лишнюю строку слова удалите свайпом влево.")
                }

                HelpCard(title: "Слова из темы", icon: "plus.circle.fill", color: .green) {
                    HelpBullet("＋ у слова или «Добавить все в словарь» — слова попадают в ваш словарь с названием темы (Словарь → ваши словари).")
                    HelpBullet("Если слово с таким переводом уже есть в базе, добавляется оно само, с его уровнем и прогрессом. Иначе слово становится вашим и учится вместе с «Моими словами».")
                    HelpBullet("Удаление темы не трогает слова, которые вы уже добавили себе.")
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationTitle("Сообщество")
        .navigationBarTitleDisplayMode(.inline)
    }
}
