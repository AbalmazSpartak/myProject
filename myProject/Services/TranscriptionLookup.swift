import Foundation

/// Транскрипция слова из бесплатного словаря dictionaryapi.dev — для автозаполнения в форме «Новое слово».
/// В запрос уходит только само английское слово. Британская запись предпочтительнее (как в базе слов);
/// если её нет — любая другая; нет слова или нет сети — nil, поле остаётся пустым
enum TranscriptionLookup {
    /// Слово из букв, дефиса и апострофа, без пробелов: фразы словарь не ищет
    nonisolated static func isLookupable(_ word: String) -> Bool {
        word.count >= 2 && word.count <= 40
            && word.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" }
            && word.unicodeScalars.allSatisfy { $0.isASCII }
    }

    /// Транскрипция без скобок, например «kjʊəriˈɒsəti»
    nonisolated static func lookup(_ word: String) async -> String? {
        let lowered = word.lowercased()
        guard isLookupable(lowered),
              let encoded = lowered.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return parse(data)
    }

    /// Из ответа: британская запись (метка «-uk» у звукозаписи), иначе без метки, иначе американская
    nonisolated static func parse(_ data: Data) -> String? {
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        var british: [String] = [], neutral: [String] = [], american: [String] = []
        for entry in entries {
            if let phonetics = entry["phonetics"] as? [[String: Any]] {
                for item in phonetics {
                    guard let text = item["text"] as? String, !text.isEmpty else { continue }
                    let audio = (item["audio"] as? String ?? "").lowercased()
                    if audio.contains("-uk") || audio.contains("-gb") {
                        british.append(text)
                    } else if audio.contains("-us") || audio.contains("-au") {
                        american.append(text)
                    } else {
                        neutral.append(text)
                    }
                }
            }
            if let text = entry["phonetic"] as? String, !text.isEmpty { neutral.append(text) }
        }
        guard let raw = (british + neutral + american).first else { return nil }
        let bare = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]/"))
        // Знаки как в нашей базе: r вместо ɹ, e вместо ɛ
        let normalized = bare.replacingOccurrences(of: "ɹ", with: "r").replacingOccurrences(of: "ɛ", with: "e")
        return normalized.isEmpty ? nil : normalized
    }
}
