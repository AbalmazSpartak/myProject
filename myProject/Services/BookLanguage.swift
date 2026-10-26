import Foundation
import NaturalLanguage

/// Язык книги — по кусочку текста из начала и середины: перевод, подсветка правил чтения и голос — только для английского
nonisolated enum BookLanguage {
    static let english = "en"

    /// Код языка («en», «ru»…); не распознался — считаем английским, как было до режимов
    static func detect(_ chapters: [BookChapter]) -> String {
        let paragraphs = chapters.flatMap(\.paragraphs)
        guard !paragraphs.isEmpty else { return english }
        var sample = ""
        for start in [0, paragraphs.count / 2] {
            for paragraph in paragraphs[start...].prefix(40) where sample.count < 6000 {
                sample += paragraph + "\n"
            }
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        return recognizer.dominantLanguage?.rawValue ?? english
    }
}
