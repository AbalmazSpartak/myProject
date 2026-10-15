import SwiftUI
import SwiftData

/// Одно написание — разные слова: speed (сущ.) «скорость» и speed (гл.) «мчаться». В тестах слово показывается так,
/// чтобы было видно, какое из них загадано, а перевод другого значения не считается ошибкой
extension Word {
    /// Глагол, к которому в вопросе можно приписать to
    var isVerb: Bool {
        let tag = partOfSpeech.trimmingCharacters(in: .whitespaces).lowercased()
        return tag == "v." || tag == "phr. v."
    }

    /// Слово в вопросе: глагол, который пишется так же, как другое слово, — с to (to speed)
    func prompt(ambiguous: Bool) -> String {
        ambiguous && isVerb && !english.lowercased().hasPrefix("to ") ? "to \(english)" : english
    }

    /// Форма слова в примере, если она другая: speed → speeding
    var exampleForm: String? {
        guard let form = clozeParts?.answer.trimmingCharacters(in: .whitespaces),
              form.caseInsensitiveCompare(english) != .orderedSame else { return nil }
        return form
    }
}

enum Homographs {
    /// Другие слова с тем же написанием (speed гл. → speed сущ.)
    static func others(of word: Word, in context: ModelContext) -> [Word] {
        let text = word.english
        let id = word.persistentModelID
        let descriptor = FetchDescriptor<Word>(predicate: #Predicate { $0.english == text })
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.persistentModelID != id && !$0.russian.isEmpty }
    }

    /// Пояснение к ответу, подходящему к другому значению
    static func note(answered other: Word, expected word: Word) -> String {
        "Верно для «\(other.english)» (\(other.russianPartOfSpeech)) — \(other.russian). Здесь загадано \(word.russianPartOfSpeech): \(word.russian)."
    }
}

/// «в примере: speeding» — под словом в тестах, когда пример использует другую форму
struct ExampleFormHint: View {
    let word: Word

    var body: some View {
        if let form = word.exampleForm {
            Text("в примере: \(form)")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
                .accessibilityLabel("В примере форма \(form)")
        }
    }
}
