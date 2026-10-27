import Foundation

/// ИИ-подсказка «В этом предложении» через свой сервер wordlearner-ai — по кнопке в карточке слова.
/// Включается в Настройках («ИИ-подсказки», по умолчанию выключено): на сервер уходят слово, предложение и случайный номер установки.
/// Обычная — Claude Haiku (1 подсказка из дневного запаса), более точная — Claude Sonnet (3). Повтор уже заданного — бесплатно
enum CloudContext {
    static let enabledKey = "ai_hints_enabled"
    static let qualityKey = "ai_hints_quality"
    nonisolated static let baseURL = URL(string: "https://wordlearner-ai.abalmazspartak.workers.dev")!

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    enum Quality: String, CaseIterable {
        case normal, precise

        var title: String {
            switch self {
            case .normal: "Обычная"
            case .precise: "Более точная"
            }
        }

        static var current: Quality {
            UserDefaults.standard.string(forKey: qualityKey).flatMap(Quality.init) ?? .normal
        }
    }

    struct Meaning: Decodable {
        /// По-русски, 1–3 варианта через запятую
        let ru: String
        /// Короткое английское пояснение
        let en: String
    }

    enum Outcome {
        case meaning(Meaning)
        /// Дневной запас подсказок кончился
        case limit
        /// Нет сети, сервер или ИИ не ответили
        case failed
    }

    private struct Request: Encodable {
        let word: String
        let sentence: String
        let install: String
        let quality: String
    }

    static func meaning(of word: String, in sentence: String) async -> Outcome {
        var request = URLRequest(url: baseURL.appending(path: "context"), timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Request(word: word, sentence: sentence, install: DictionarySignals.installID,
                                                             quality: Quality.current.rawValue))
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { return .failed }
        if status == 429, String(decoding: data, as: UTF8.self).contains("\"limit\"") { return .limit }
        guard status == 200, let meaning = try? JSONDecoder().decode(Meaning.self, from: data), !meaning.ru.isEmpty else { return .failed }
        return .meaning(meaning)
    }
}
