import SwiftUI

/// Вход в приложение: три пути — читаем и учим слова, только читаем, только учим английский. Потом меняется в Настройках
struct ModeChoiceView: View {
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.chosenKey) private var chosen = false
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false
    @AppStorage(AppMode.learningOnlyKey) private var learningOnly = false
    /// Выбор сделан — закрыть экран (при «Спрашивать» он показывается на каждом запуске)
    var onChoose: () -> Void = {}

    private enum Path { case both, reading, learning }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("Как будете пользоваться?")
                .scaledFont(size: 32, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
            Text("Выбор можно поменять в Настройках, ничего не пропадёт.")
                .scaledFont(size: 16)
                .foregroundStyle(Color.brandMuted)
                .padding(.bottom, 6)

            option(.both, icon: "book.and.wrench", title: "Читаем и учим слова",
                   text: "Книги с переводом по нажатию и тренировки слов. Режимы переключаются сверху.")
            option(.reading, icon: "books.vertical", title: "Читаем",
                   text: "Только библиотека и читалка: книги на английском и русском, озвучка, закладки и заметки.")
            option(.learning, icon: "graduationcap", title: "Учим английский",
                   text: "Слова, повторения и тренировки. Без читалки.")
            // Снизу места вдвое больше — выбор стоит выше середины экрана
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Color.brandBackground.ignoresSafeArea())
    }

    private func option(_ path: Path, icon: String, title: String, text: String) -> some View {
        Button {
            Haptics.tap()
            switch path {
            case .both:
                readerOnly = false
                learningOnly = false
                mode = .reading
            case .reading:
                readerOnly = true
                learningOnly = false
                mode = .reading
            case .learning:
                readerOnly = false
                learningOnly = true
                mode = .learning
            }
            chosen = true
            onChoose()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .scaledFont(size: 24)
                    .foregroundStyle(Color.brandOnSoft)
                    .frame(width: 52, height: 52)
                    .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .scaledFont(size: 18, weight: .semibold)
                        .foregroundStyle(Color.brandDark)
                    Text(text)
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.brandMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(Color.brandMuted)
            }
            .padding(16)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
