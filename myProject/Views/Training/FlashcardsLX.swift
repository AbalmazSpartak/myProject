import SwiftUI

// Карточки для запоминания по холсту «LexiStream: Словарь» (экраны 8–10): лицо, оборот, итог подхода.
// Оценок по-прежнему четыре (FSRS), три кнопки из дизайна не вводим.

/// Одна из четырёх оценок FSRS в ряду под карточкой
struct FlashcardRatingButton: View {
    let rating: FSRSRating
    let action: () -> Void

    private var title: String {
        switch rating {
        case .again: "Снова"
        case .hard: "Трудно"
        case .good: "Хорошо"
        case .easy: "Легко"
        }
    }

    private var symbol: String {
        switch rating {
        case .again: "arrow.counterclockwise"
        case .hard: "circle.righthalf.filled"
        case .good: "checkmark.circle"
        case .easy: "checkmark.circle.fill"
        }
    }

    private var foreground: Color {
        switch rating {
        case .again: .statusLearning
        case .hard: .brandDark
        case .good: .brandOnSoft
        case .easy: .brandOnButton
        }
    }

    private var background: Color {
        switch rating {
        case .again, .hard: .clear
        case .good: .brandAccent
        case .easy: .brandButton
        }
    }

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).scaledFont(size: 20)
                Text(title).scaledFont(size: 14, weight: .semibold)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if background == .clear {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Пример под словом: слово на мягкой подложке, ниже — из какой книги
struct FlashcardExample: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Color.brandBorder)
            Text(WordDetailView.highlighted(word.example))
                .scaledFont(size: 18, design: .serif)
                .italic()
                .foregroundStyle(Color.brandDark)
                .lineSpacing(3)
                .padding(.top, 8)
            if let source = word.lists.first {
                Label(DictionaryView.shortName(source.name, limit: 40), systemImage: "book.closed")
                    .scaledFont(size: 13)
                    .foregroundStyle(Color.brandMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Итог подхода: что ответили и какие слова вернутся позже
struct FlashcardsSummary: View {
    /// Сколько ответов каждой оценки
    let counts: [FSRSRating: Int]
    let total: Int
    let returnLater: [Word]
    let onContinue: () -> Void
    let onExit: () -> Void

    private var known: Int { (counts[.good] ?? 0) + (counts[.easy] ?? 0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Хорошо позанимались")
                    .scaledFont(size: 34, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                Text("Вы посмотрели \(DictionaryCounts.cards(total)). Остановиться можно в любой момент.")
                    .foregroundStyle(Color.brandMuted)
                    .padding(.top, 6)

                HStack(spacing: 8) {
                    tile(symbol: "checkmark.circle", color: .statusKnown, value: known, title: "Знаю")
                    tile(symbol: "circle.righthalf.filled", color: .statusLearning, value: counts[.hard] ?? 0, title: "Трудно")
                    tile(symbol: "arrow.counterclockwise", color: .brandMuted, value: counts[.again] ?? 0, title: "Снова")
                }
                .padding(.top, 20)

                if !returnLater.isEmpty {
                    LXSectionLabel(text: "Вернутся позже")
                        .padding(.top, 22)
                        .padding(.bottom, 8)
                    LXCard {
                        VStack(spacing: 0) {
                            ForEach(returnLater) { word in
                                LXWordRow(word: word)
                            }
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
                LXButton(title: "Ещё подход", action: onContinue)
                LXButton(title: "Закончить", style: .outline, action: onExit)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.brandBackground)
        }
    }

    private func tile(symbol: String, color: Color, value: Int, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).scaledFont(size: 22).foregroundStyle(color)
            Text("\(value)").scaledFont(size: 30, design: .serif).foregroundStyle(Color.brandDark)
            Text(title).scaledFont(size: 12).foregroundStyle(Color.brandMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
