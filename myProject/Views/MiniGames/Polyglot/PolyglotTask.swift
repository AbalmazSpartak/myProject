import Foundation

/// Задание «Составь фразу»: фраза на русском, правильный порядок карточек и все карточки вперемешку (с лишними)
struct PolyglotTask: Identifiable {
    let id = UUID()
    let russian: String
    let answer: [String]
    let isQuestion: Bool
    let tiles: [String]

    /// Правильный ответ целиком: «Does she love?»
    var answerText: String {
        Self.sentence(answer, isQuestion: isQuestion)
    }

    /// Сокращения считаются как полные формы: didn't = did not, won't = will not
    func isCorrect(_ words: [String]) -> Bool {
        Self.normalized(words) == Self.normalized(answer)
    }

    private static func normalized(_ words: [String]) -> String {
        words.joined(separator: " ").lowercased()
            .replacingOccurrences(of: "won't", with: "will not")
            .replacingOccurrences(of: "didn't", with: "did not")
            .replacingOccurrences(of: "doesn't", with: "does not")
            .replacingOccurrences(of: "don't", with: "do not")
    }

    /// Карточки → предложение: с заглавной буквы и знаком в конце
    static func sentence(_ words: [String], isQuestion: Bool) -> String {
        guard !words.isEmpty else { return "" }
        return words.joined(separator: " ").capitalizedFirst + (isQuestion ? "?" : ".")
    }
}

extension String {
    /// Первая буква — заглавная, остальное как есть
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
