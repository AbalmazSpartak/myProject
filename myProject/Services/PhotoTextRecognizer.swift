import Foundation
import Vision

/// Распознаёт английский текст на фото или скриншоте (на устройстве, без интернета)
enum PhotoTextRecognizer {
    static func text(in imageData: Data) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: imageData)
        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
