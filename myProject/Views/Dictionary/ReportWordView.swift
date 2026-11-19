import SwiftUI

/// «Ошибка в слове» по дизайну LexiStream — слово из встроенного словаря: что не так и комментарий
struct ReportWordView: View {
    @Environment(\.dismiss) private var dismiss
    let word: Word

    @State private var field = WordReports.Field.translation
    @State private var comment = ""
    @State private var state: SendState = .editing

    private enum SendState { case editing, sending, sent, queued }

    private var isFinished: Bool { state == .sent || state == .queued }

    var body: some View {
        VStack(spacing: 0) {
            LXNavBar(title: "Ошибка в слове") {
                LXTextButton(title: isFinished ? "Закрыть" : "Отмена", isMuted: true) { dismiss() }
            } trailing: {
                EmptyView()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    wordCard
                    LXSectionLabel(text: "Что не так")
                        .padding(.horizontal, 4)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    LXGroup {
                        ForEach(WordReports.Field.allCases) { option in optionRow(option) }
                    }
                    LXField(label: "Комментарий") {
                        TextField("Подскажите, как правильно — по желанию", text: $comment, axis: .vertical)
                            .scaledFont(size: 15)
                            .foregroundStyle(Color.brandDark)
                            .lineLimit(3...6)
                    }
                    .padding(.top, 16)
                    if isFinished {
                        Label(state == .sent ? "Отправлено — спасибо!" : "Сохранено, отправится, когда появится интернет",
                              systemImage: state == .sent ? "checkmark.circle" : "clock")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundStyle(state == .sent ? Color.statusKnown : Color.brandTint)
                            .padding(.top, 14)
                    }
                    LXButton(title: state == .sending ? "Отправляю…" : "Отправить", isEnabled: state == .editing, action: send)
                        .padding(.top, 16)
                    Text("Спасибо, что помогаете сделать словарь точнее. Слово и его текущие данные приложатся сами. Без интернета сообщение сохранится и уйдёт позже.")
                        .scaledFont(size: 13)
                        .foregroundStyle(Color.brandMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }

    private var wordCard: some View {
        LXCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.english)
                        .scaledFont(size: 24, weight: .medium, design: .serif)
                        .foregroundStyle(Color.brandDark)
                    Text("\(word.transcription.isEmpty ? "" : "[\(word.transcription)] · ")\(word.russian)")
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.brandMuted)
                }
                Spacer()
                LevelBadge(level: word.cefrLevel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func optionRow(_ option: WordReports.Field) -> some View {
        Button {
            Haptics.tap()
            field = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: field == option ? "largecircle.fill.circle" : "circle")
                    .scaledFont(size: 22)
                    .foregroundStyle(field == option ? Color.brandTint : Color.brandMuted)
                Text(title(of: option))
                    .scaledFont(size: 16)
                    .foregroundStyle(Color.brandDark)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(field == option ? .isSelected : [])
    }

    private func title(of option: WordReports.Field) -> String {
        switch option {
        case .translation: "Неверный перевод"
        case .transcription: "Ошибка в транскрипции"
        case .example: "Неточный пример"
        case .level: "Неверный уровень"
        case .partOfSpeech: "Неверная часть речи"
        case .topic: "Неверная тема"
        case .other: "Другое"
        }
    }

    private func send() {
        state = .sending
        let report = WordReports.report(word, field: field, comment: comment)
        Task {
            state = await WordReports.submit(report) ? .sent : .queued
            Haptics.tap()
        }
    }
}
