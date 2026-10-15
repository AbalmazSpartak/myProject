import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Значение слова именно в этом предложении — встроенная модель Apple Intelligence, без интернета и бесплатно.
/// Есть только на iPhone 15 Pro и новее (iOS 26+) при включённом Apple Intelligence; русский модель не знает,
/// поэтому отвечает коротким английским пояснением («driving too fast»), а на русский его переводит переводчик iOS.
/// Объяснение грамматики («Почему?») модели не доверяем — на проверке ошибалась в формах; это задача облачного ИИ
enum ContextMeaning {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    /// Короткое английское пояснение слова в предложении; nil — модель недоступна
    static func meaning(of word: String, in sentence: String) async throws -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), SystemLanguageModel.default.isAvailable {
            let session = LanguageModelSession(instructions: """
                You help a learner of English understand one word in a sentence. \
                Give the meaning of that word only as it is used in the sentence.
                """)
            let response = try await session.respond(to: "Sentence: \"\(sentence)\"\nWord: \"\(word)\"",
                                                     generating: Sense.self,
                                                     options: GenerationOptions(temperature: 0.2))
            let meaning = response.content.meaning.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            return meaning.isEmpty ? nil : meaning
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
@Generable
private struct Sense {
    @Guide(description: "A short simple English paraphrase (2-6 words) of what the word means in THIS sentence. For a verb use the base form starting with 'to' (e.g. 'to drive too fast'); for a noun a noun phrase; for an adjective an adjective phrase.")
    var meaning: String
}
#endif
