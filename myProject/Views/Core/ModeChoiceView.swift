import SwiftUI

/// Первый запуск: для чего приложение — учить английский или читать книги. Потом меняется в Настройках
struct ModeChoiceView: View {
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.chosenKey) private var chosen = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Как будете пользоваться?")
                .scaledFont(size: 28, weight: .bold, design: .serif)
                .foregroundColor(.brandDark)
                .multilineTextAlignment(.center)
            Text("Выбор можно поменять в Настройках, ничего не пропадёт.")
                .scaledFont(size: 16)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            option(.learning, icon: "graduationcap.fill",
                   text: "Слова, повторения, тренировки, игры и книги с переводом по нажатию.")
            option(.reading, icon: "books.vertical.fill",
                   text: "Только библиотека и читалка: книги на английском и русском, толкование слов.")
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Color.brandBackground.ignoresSafeArea())
    }

    private func option(_ option: AppMode, icon: String, text: String) -> some View {
        Button {
            Haptics.tap()
            mode = option
            chosen = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .scaledFont(size: 28)
                    .foregroundColor(.brown)
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(option == .learning ? "Учить английский" : "Читать книги")
                        .scaledFont(size: 19, weight: .semibold)
                        .foregroundColor(.brandDark)
                    Text(text)
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .background(Color.cardBackground)
            .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}
