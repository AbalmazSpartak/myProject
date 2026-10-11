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

/// «Слово дня» на «Обзоре»: картинка (если есть), слово, перевод; нажатие — послушать слово
struct WordOfDayRow: View {
    @AppStorage("show_word_images") private var showWordImages = true
    let word: Word

    var body: some View {
        Button {
            TextToSpeechManager.shared.speak(word.english)
        } label: {
            HStack(spacing: 14) {
                picture
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(word.english)
                        .scaledFont(size: 24, weight: .regular, design: .serif)
                        .foregroundColor(.brandDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(word.russian)
                        .scaledFont(size: 15)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "speaker.wave.2.fill")
                    .scaledFont(size: 20)
                    .foregroundColor(.orange)
            }
            .padding(14)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Озвучить слово")
        .task(id: word.persistentModelID) {
            if showWordImages { await WordImageLoader.loadIfNeeded(word) }
        }
    }

    @ViewBuilder
    private var picture: some View {
        if showWordImages, !word.isImageHidden, let data = word.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            // Без картинки — тёмный «ночной» градиент с молнией, как раньше на большой карточке
            LinearGradient(colors: [Color(red: 0.10, green: 0.12, blue: 0.22), Color(red: 0.28, green: 0.20, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Image(systemName: "bolt.fill")
                        .scaledFont(size: 22)
                        .foregroundColor(.white.opacity(0.85))
                }
        }
    }
}
