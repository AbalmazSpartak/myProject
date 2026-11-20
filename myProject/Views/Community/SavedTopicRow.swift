import SwiftUI
import SwiftData

/// Подборка из «Сообщества»: название и число слов
struct SavedTopicRow: View {
    let topic: CommunityTopic
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "text.book.closed.fill")
                    .scaledFont(size: 22)
                    .foregroundColor(Color.brandTint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .lineLimit(1)
                    Text([topic.words.isEmpty ? topic.section : "\(topic.words.count) \(DailyStudyCard.wordsNoun(topic.words.count))",
                          topic.ratingSummary].filter { !$0.isEmpty }.joined(separator: " · "))
                        .scaledFont(size: 14)
                        .foregroundColor(Color.brandMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(Color.brandMuted)
            }
            .padding(14)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
