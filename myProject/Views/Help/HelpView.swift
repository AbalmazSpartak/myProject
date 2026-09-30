import SwiftUI

// Разделы справки. Новый раздел — новый case и его экран в destination
enum HelpTopic: String, CaseIterable, Identifiable {
    case flashcards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flashcards: return "Карточки для запоминания"
        }
    }

    var icon: String {
        switch self {
        case .flashcards: return "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .flashcards: return .blue
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .flashcards: FlashcardsHelpView()
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
