import SwiftUI

/// Часть речи рядом со словом: can · гл. и can · сущ. — разные слова
struct PartOfSpeechBadge: View {
    let word: Word

    var body: some View {
        let text = word.russianPartOfSpeech
        if !text.isEmpty {
            Text(text)
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.brandFill))
                .fixedSize()
                .accessibilityLabel("Часть речи: \(text)")
        }
    }
}
