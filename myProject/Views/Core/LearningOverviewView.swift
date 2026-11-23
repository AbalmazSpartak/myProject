import SwiftUI
import SwiftData

/// «Обзор» режима «Обучение»: три раздела для запоминания слов
struct LearningOverviewView: View {
    let open: (ActiveScreen) -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage(DailyNewWords.limitKey) private var newWordsPerDay = DailyNewWords.defaultLimit
    /// Сколько слов ждёт повторения сегодня: пересчитывается при каждом показе «Обзора»
    @State private var counts = WordCounts()

    private struct Section: Identifiable {
        let screen: ActiveScreen
        let title: String
        let text: String
        let icon: String
        var id: String { title }
    }

    private let sections = [
        Section(screen: .speak, title: "Произнести",
                text: "Скажите слово вслух — приложение проверит", icon: "mic"),
        Section(screen: .inputCards, title: "Карточки ввода",
                text: "Впишите слово по переводу", icon: "keyboard"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Обзор")
                    .lxScreenTitle()
                    .foregroundColor(.brandDark)
                    .padding(.bottom, 4)
                repeatNow
                ForEach(sections) { section in
                    LearningSectionRow(title: section.title, text: section.text, icon: section.icon) {
                        open(section.screen)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .onAppear {
            counts.refreshProgress(scope: studyScope, newWordsAllowance: DailyNewWords.allowance(limit: newWordsPerDay), in: modelContext)
        }
    }

    /// Главное действие «Обзора»: сразу к интервальному повторению, одним нажатием
    private var repeatNow: some View {
        VStack(alignment: .leading, spacing: 10) {
            LXSectionLabel(text: "Сегодня")
            Text(counts.due > 0 ? "\(DictionaryCounts.words(counts.due)) на повторение" : "На сегодня всё повторено")
                .scaledFont(size: 26, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
            Text("Интервальное повторение: слова возвращаются, когда пора повторить")
                .scaledFont(size: 14)
                .foregroundStyle(Color.brandMuted)
            LXButton(title: "Повторить сейчас", systemImage: "play.fill") {
                open(.flashcardsFSRS)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lxPlate(radius: 20)
    }
}

/// Строка раздела «Обзора» и «Практики»: значок, название, пояснение
struct LearningSectionRow: View {
    let title: String
    let text: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .scaledFont(size: 24)
                    .foregroundColor(AppDesign.isSketch ? .brandDark : .brandTint)
                    .frame(width: 56, height: 56)
                    .background(AppDesign.isSketch ? NewStyle.pastels[1] : Color.brandAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .sketchFrame(AppDesign.isSketch, radius: 14, shadow: NewStyle.yellow, offset: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .multilineTextAlignment(.leading)
                    Text(text)
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
            .lxPlate(radius: 16)
        }
        .buttonStyle(.plain)
    }
}

/// «Практика» — все тренировки в одном месте
struct PracticeView: View {
    let open: (ActiveScreen) -> Void

    private let items: [(screen: ActiveScreen, title: String, text: String, icon: String)] = [
        (.flashcardsFSRS, "Интервальное повторение", "Слова возвращаются, когда пора повторить", "rectangle.stack"),
        (.quiz, "Викторина", "Выберите перевод из четырёх вариантов", "list.bullet.rectangle"),
        (.inputCards, "Карточки ввода", "Впишите слово по переводу", "keyboard"),
        (.cloze, "Слово в контексте", "Впишите пропущенное слово в предложении", "text.quote"),
        (.review, "Повторение", "Прогон уже пройденных слов без сдвига расписания", "arrow.triangle.2.circlepath"),
        (.speak, "Произнести", "Скажите слово вслух — приложение проверит", "mic"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Практика")
                    .lxScreenTitle()
                    .foregroundColor(.brandDark)
                    .padding(.bottom, 4)
                ForEach(items, id: \.title) { item in
                    LearningSectionRow(title: item.title, text: item.text, icon: item.icon) { open(item.screen) }
                }
            }
            .padding(20)
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }
}
