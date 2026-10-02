import SwiftUI

// Разделы справки. Новый раздел — новый case, его экран в destination и HelpButton(topic:) в шапке раздела
enum HelpTopic: String, CaseIterable, Identifiable {
    case profile
    case flashcards
    case quiz
    case cloze
    case inputCards
    case dictionary
    case tetris
    case race

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile: return "Мой профиль"
        case .flashcards: return "Карточки для запоминания"
        case .quiz: return "Викторина"
        case .cloze: return "Слово в контексте"
        case .inputCards: return "Карточки ввода"
        case .dictionary: return "Словарь"
        case .tetris: return "Тетрис слов"
        case .race: return "Гонка слов"
        }
    }

    var icon: String {
        switch self {
        case .profile: return "person.fill"
        case .flashcards: return "brain.head.profile"
        case .quiz: return "checkmark.seal.fill"
        case .cloze: return "text.insert"
        case .inputCards: return "keyboard.fill"
        case .dictionary: return "book.fill"
        case .tetris: return "gamecontroller.fill"
        case .race: return "car.fill"
        }
    }

    var color: Color {
        switch self {
        case .profile: return .teal
        case .flashcards: return .blue
        case .quiz: return .purple
        case .cloze: return .pink
        case .inputCards: return .teal
        case .dictionary: return .orange
        case .tetris: return .indigo
        case .race: return .green
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .profile: ProfileHelpView()
        case .flashcards: FlashcardsHelpView()
        case .quiz: QuizHelpView()
        case .cloze: ClozeHelpView()
        case .inputCards: InputCardsHelpView()
        case .dictionary: DictionaryHelpView()
        case .tetris: TetrisHelpView()
        case .race: RaceHelpView()
        }
    }
}

/// Кнопка «?» в шапке раздела — открывает справку этого раздела
struct HelpButton: View {
    let topic: HelpTopic
    /// Например, поставить игру на паузу, пока открыта справка
    var onOpen: (() -> Void)? = nil
    @State private var isShowing = false

    var body: some View {
        Button {
            onOpen?()
            isShowing = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(topic.color)
        }
        .accessibilityLabel("Справка")
        .sheet(isPresented: $isShowing) {
            NavigationStack {
                topic.destination
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Готово") { isShowing = false }
                                .fontWeight(.bold)
                        }
                    }
            }
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(HelpTopic.allCases) { topic in
                        NavigationLink {
                            topic.destination
                        } label: {
                            HelpTopicRow(topic: topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Справка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Меню")
                        }
                        .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
    }
}

private struct HelpTopicRow: View {
    let topic: HelpTopic

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(topic.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: topic.icon)
                    .foregroundColor(topic.color)
                    .font(.system(size: 18))
            }

            Text(topic.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.brandDark)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
