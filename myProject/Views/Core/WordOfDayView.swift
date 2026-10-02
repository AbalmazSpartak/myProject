import SwiftUI
import SwiftData

/// Слово дня: каждый день новое слово из основной базы с примером; у всех пользователей в один день — одно и то же
enum WordOfDay {
    /// Слова дня за последние `days` дней, сегодняшнее первым
    static func recent(days: Int, from words: [Word], today: Date = Date()) -> [Word] {
        let candidates = words
            .filter { !$0.isCustom && $0.clozeParts != nil }
            .sorted { ($0.english, $0.partOfSpeech, $0.russian) < ($1.english, $1.partOfSpeech, $1.russian) }
        guard !candidates.isEmpty else { return [] }
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
                  let day = calendar.ordinality(of: .day, in: .era, for: date) else { return nil }
            // Перемешиваем номер дня, чтобы соседние дни не давали соседние по алфавиту слова
            let index = Int(UInt64(day) &* 2_654_435_761 % UInt64(candidates.count))
            return candidates[index]
        }
    }
}

/// Карусель «Слово дня»: сегодняшнее и слова прошлых дней, листается вбок
struct WordOfDayCarousel: View {
    let words: [Word]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(words.enumerated()), id: \.offset) { offset, word in
                    WordOfDayCard(word: word, label: Self.label(daysAgo: offset))
                        .containerRelativeFrame(.horizontal) { width, _ in width - 56 }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }

    private static func label(daysAgo: Int) -> String {
        switch daysAgo {
        case 0: return "Слово дня"
        case 1: return "Вчера"
        default:
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return date.formatted(.dateTime.day().month(.wide))
        }
    }
}

private struct WordOfDayCard: View {
    @AppStorage("show_word_images") private var showWordImages = true
    let word: Word
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Картинка заполняет рамку карточки, но не раздвигает её
                Color.clear
                    .frame(height: 190)
                    .overlay { background }
                    .clipped()
                    .overlay(LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))

                Label(label, systemImage: "bolt.fill")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.white)
                    .padding(14)

                VStack(spacing: 4) {
                    Text(word.english)
                        .scaledFont(size: 38, weight: .regular, design: .serif)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(word.russian)
                        .scaledFont(size: 17)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
            }
            .frame(height: 190)

            Text(word.attributedExample)
                .scaledFont(size: 18, design: .serif)
                .foregroundColor(.brandDark)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.brandAccent)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
        // Нажатие — послушать слово
        .onTapGesture { TextToSpeechManager.shared.speak(word.english) }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Озвучить слово")
        .task(id: word.persistentModelID) {
            if showWordImages { await WordImageLoader.loadIfNeeded(word) }
        }
    }

    @ViewBuilder
    private var background: some View {
        if showWordImages, !word.isImageHidden, let data = word.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            // Без картинки — тёмный «ночной» градиент, как на макете
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.22), Color(red: 0.28, green: 0.20, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
