import Foundation

/// Какие куски абзацев попадают на страницу, занимающую символы `chars` склеенного текста (абзацы через «\n»).
/// Идёт только по абзацам страницы, а не по всей главе: первый находится бинарным поиском
nonisolated enum PageSegments {
    /// Кусок абзаца на странице: номер абзаца, где начинается и сколько символов
    struct Piece: Equatable, Sendable {
        let paragraph: Int
        let location: Int
        let length: Int
    }

    /// starts — с какого символа склеенного текста начинается каждый абзац; lengths — длины абзацев
    static func pieces(starts: [Int], lengths: [Int], chars: NSRange) -> [Piece] {
        guard !starts.isEmpty, starts.count == lengths.count else { return [] }
        // Последний абзац, который начинается не позже начала страницы
        var low = 0, high = starts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if starts[middle] <= chars.location { low = middle } else { high = middle - 1 }
        }
        var result: [Piece] = []
        var index = low
        while index < starts.count, starts[index] < NSMaxRange(chars) {
            let from = max(chars.location, starts[index]), to = min(NSMaxRange(chars), starts[index] + lengths[index])
            if to > from { result.append(Piece(paragraph: index, location: from - starts[index], length: to - from)) }
            index += 1
        }
        return result
    }
}
