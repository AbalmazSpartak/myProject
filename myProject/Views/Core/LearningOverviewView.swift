import SwiftUI

/// «Обзор» режима «Обучение»: три раздела для запоминания слов
struct LearningOverviewView: View {
    let open: (ActiveScreen) -> Void

    private struct Section: Identifiable {
        let screen: ActiveScreen
        let title: String
        let text: String
        let icon: String
        var id: String { title }
    }

    private let sections = [
        Section(screen: .flashcardsFSRS, title: "Интервальное повторение",
                text: "Слова возвращаются, когда пора повторить", icon: "rectangle.stack"),
        Section(screen: .speak, title: "Произнести",
                text: "Скажите слово вслух — приложение проверит", icon: "mic"),
        Section(screen: .inputCards, title: "Карточки ввода",
                text: "Впишите слово по переводу", icon: "keyboard"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Обзор")
                    .scaledFont(size: 34, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                    .padding(.bottom, 4)
                ForEach(sections) { section in
                    Button {
                        Haptics.tap()
                        open(section.screen)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: section.icon)
                                .scaledFont(size: 24)
                                .foregroundColor(.brandTint)
                                .frame(width: 56, height: 56)
                                .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(section.title)
                                    .scaledFont(size: 17, weight: .semibold)
                                    .foregroundColor(.brandDark)
                                    .multilineTextAlignment(.leading)
                                Text(section.text)
                                    .scaledFont(size: 14)
                                    .foregroundColor(.brandMuted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.brandMuted)
                        }
                        .padding(16)
                        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }
}
