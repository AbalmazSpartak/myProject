import Foundation

/// Произношение английских слов: CMU Pronouncing Dictionary (cmudict.txt, ~124 тыс. слов, лицензия — cmudict-LICENSE.txt).
/// Файл отсортирован, строки «word PH1 PH2 …» (ARPAbet со знаками ударения 0/1/2). Читается через отображение в память
/// и двоичный поиск — в памяти только начала строк, сам словарь целиком не разбирается
nonisolated final class PronunciationDictionary: Sendable {
    static let shared = PronunciationDictionary()

    private let data: Data
    private let starts: [Int32]

    private init() {
        guard let url = Bundle.main.url(forResource: "cmudict", withExtension: "txt"),
              let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
            data = Data()
            starts = []
            return
        }
        self.data = data
        var starts: [Int32] = [0]
        starts.reserveCapacity(130_000)
        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for i in 0..<bytes.count where bytes[i] == 10 && i + 1 < bytes.count {
                starts.append(Int32(i + 1))
            }
        }
        self.starts = starts
    }

    /// Звуки слова в ARPAbet, например knight → ["N", "AY1", "T"]; nil — слова нет в словаре
    func phones(for word: String) -> [String]? {
        let key = Array(word.lowercased().replacingOccurrences(of: "’", with: "'").utf8)
        guard !key.isEmpty, !starts.isEmpty else { return nil }
        return data.withUnsafeBytes { raw -> [String]? in
            let bytes = raw.bindMemory(to: UInt8.self)
            var low = 0
            var high = starts.count - 1
            while low <= high {
                let mid = (low + high) / 2
                let start = Int(starts[mid])
                let order = compare(key, bytes, at: start)
                if order == 0 {
                    var end = start + key.count + 1
                    while end < bytes.count, bytes[end] != 10 { end += 1 }
                    guard start + key.count + 1 < end else { return nil }
                    let line = String(decoding: UnsafeBufferPointer(rebasing: bytes[(start + key.count + 1)..<end]), as: UTF8.self)
                    return line.split(separator: " ").map(String.init)
                }
                if order < 0 { high = mid - 1 } else { low = mid + 1 }
            }
            return nil
        }
    }

    /// Сравнение ключа со словом в начале строки: −1 — ключ раньше, 1 — позже, 0 — совпало
    private func compare(_ key: [UInt8], _ bytes: UnsafeBufferPointer<UInt8>, at start: Int) -> Int {
        var i = 0
        while true {
            let byte = start + i < bytes.count ? bytes[start + i] : 10
            let wordEnded = byte == 32 || byte == 10
            if i == key.count { return wordEnded ? 0 : -1 }
            if wordEnded { return 1 }
            if key[i] != byte { return key[i] < byte ? -1 : 1 }
            i += 1
        }
    }
}
