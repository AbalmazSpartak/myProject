import SwiftUI

// Общие части тренировок «Викторина» и «Ввод» в стиле карточек LexiStream: чип выбора слов вверху,
// карточка с вопросом, строки ответов, итог подхода. Верно — цвет основной, ошибка — янтарный:
// красный и зелёный не используем, и по цвету одному ответ не отличают (есть значок).

/// Верхняя строка: чип «Что повторять», справка, «Закончить»
struct TrainingTopBar: View {
    let current: TrainingFilter
    let counts: WordCounts
    let categories: [Category]
    let helpTopic: HelpTopic
    let onSelect: (TrainingFilter) -> Void
    let onExit: () -> Void

    var body: some View {
        HStack {
            TrainingFilterMenu(
                current: current,
                counts: counts,
                categories: categories,
                includesDue: false,
                icon: "folder.fill",
                tint: Color.brandTint,
                usesChipStyle: true,
                onSelect: onSelect
            )
            Spacer()
            HelpButton(topic: helpTopic)
            LXTextButton(title: "Закончить", isMuted: true, action: onExit)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(minHeight: 52)
    }
}

/// Карточка тренировки: подпись счёта слева, уровень справа, дальше — содержимое
struct TrainingCard<Content: View>: View {
    let score: String
    let level: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(score)
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(Color.brandMuted)
                Spacer()
                LevelBadge(level: level)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lxPlate(radius: 24)
        .shadow(color: Color.black.opacity(AppDesign.isSketch ? 0 : 0.05), radius: 12, x: 0, y: 6)
    }
}

/// Слово-вопрос по центру карточки: крупно, транскрипция, часть речи, озвучка
struct TrainingQuestion: View {
    let word: Word
    let text: String
    /// Режим «англ → рус»: слово английское, есть транскрипция и озвучка
    let isEnglish: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(text)
                .scaledFont(size: 44, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            HStack(spacing: 8) {
                if isEnglish && !word.displayTranscription.isEmpty {
                    Text(word.displayTranscription)
                        .scaledFont(size: 17)
                        .foregroundStyle(Color.brandMuted)
                }
                PartOfSpeechBadge(word: word)
            }
            if isEnglish {
                ExampleFormHint(word: word)
            }
            Button { TextToSpeechManager.shared.speak(word.english) } label: {
                Image(systemName: "speaker.wave.2")
                    .scaledFont(size: 22)
                    .foregroundStyle(Color.brandOnSoft)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AppDesign.isSketch ? NewStyle.pastels[1] : Color.brandAccent))
                    .overlay { if AppDesign.isSketch { Circle().stroke(NewStyle.outline, style: NewStyle.stroke) } }
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityLabel("Озвучить слово")
        }
        .frame(maxWidth: .infinity)
    }
}

/// Пустой экран тренировки
struct TrainingEmpty: View {
    let systemImage: String
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: systemImage)
                .scaledFont(size: 56)
                .foregroundStyle(Color.statusKnown)
            Text(text)
                .scaledFont(size: 26, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

/// Итог подхода: плитки, слова с ошибками, «Ещё подход» и «Закончить»
struct TrainingSummary: View {
    struct Tile: Identifiable {
        let symbol: String
        let color: Color
        let value: Int
        let title: String
        var id: String { title }
    }

    let subtitle: String
    let tiles: [Tile]
    let laterTitle: String
    let later: [Word]
    /// false — «Ещё подход» не показываем (слова кончились)
    var showsContinue = true
    /// Дополнительная кнопка между «Ещё подход» и «Закончить», например «Повторить ошибки»
    var extraTitle: String?
    var onExtra: () -> Void = {}
    let onContinue: () -> Void
    let onExit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Хорошо позанимались")
                    .scaledFont(size: 34, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                Text(subtitle)
                    .foregroundStyle(Color.brandMuted)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    ForEach(tiles) { tile in
                        VStack(spacing: 4) {
                            Image(systemName: tile.symbol).scaledFont(size: 22).foregroundStyle(tile.color)
                            Text("\(tile.value)").scaledFont(size: 30, design: .serif).foregroundStyle(Color.brandDark)
                            Text(tile.title).scaledFont(size: 12).foregroundStyle(Color.brandMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .lxPlate(radius: 16)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 20)

                if !later.isEmpty {
                    LXSectionLabel(text: laterTitle)
                        .padding(.top, 22)
                        .padding(.bottom, 8)
                    LXCard {
                        VStack(spacing: 0) {
                            ForEach(later) { word in LXWordRow(word: word) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if showsContinue {
                    LXButton(title: "Ещё подход", action: onContinue)
                }
                if let extraTitle {
                    LXButton(title: extraTitle, style: showsContinue ? .soft : .primary, action: onExtra)
                }
                LXButton(title: "Закончить", style: .outline, action: onExit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.brandBackground)
        }
    }
}

/// Состояние строки ответа в викторине
enum QuizOptionState {
    case plain, correct, wrong, dimmed
}

/// Вариант ответа: во всю ширину; после ответа — значок и цвет (верный — основной, ошибка — янтарный)
struct QuizOptionRow: View {
    let text: String
    let state: QuizOptionState
    let isLocked: Bool
    let action: () -> Void

    private var tint: Color {
        switch state {
        case .correct: AppDesign.isSketch ? .brandDark : .brandOnSoft
        case .wrong: .statusLearning
        case .dimmed: .brandMuted
        case .plain: .brandDark
        }
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(text)
                    .scaledFont(size: 17, weight: state == .plain || state == .dimmed ? .medium : .semibold)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                switch state {
                case .correct: Image(systemName: "checkmark.circle.fill").scaledFont(size: 20)
                case .wrong: Image(systemName: "xmark.circle").scaledFont(size: 20)
                default: EmptyView()
                }
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(state == .correct ? (AppDesign.isSketch ? NewStyle.pastels[3] : Color.brandAccent) : Color.cardBackground,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(state == .wrong ? Color.statusLearning : state == .correct || AppDesign.isSketch ? Color.clear : Color.brandBorder,
                            lineWidth: state == .wrong ? 1.5 : 1)
            }
            .sketchFrame(AppDesign.isSketch, radius: 16, shadow: state == .correct ? NewStyle.yellow : NewStyle.blue, offset: 3)
            .opacity(state == .dimmed ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel(text + (state == .correct ? ", верно" : state == .wrong ? ", неверно" : ""))
    }
}
