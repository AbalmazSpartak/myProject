import UIKit
import Vision

/// Таблица, распознанная на фото: текст ячеек, объединения и цвет текста
nonisolated struct RecognizedTable: Sendable {
    struct Span: Sendable {
        let row: Int
        let column: Int
        let rowSpan: Int
        let columnSpan: Int
    }

    enum Tone: Sendable {
        case normal, red, gray
    }

    var cells: [[String]]
    var spans: [Span] = []
    /// Ключ — «строка:столбец», только для красного и серого
    var tones: [String: Tone] = [:]
    /// Таблица была больше, чем помещается в редактор, — лишнее отрезано
    var wasTrimmed = false

    var rows: Int { cells.count }
    var columns: Int { cells.first?.count ?? 0 }
}

/// Распознаёт таблицу на фото. iOS 26+ — встроенным распознаванием документов (строки, столбцы, объединения);
/// на iOS 18 или если таблица не нашлась — по тексту и линиям сетки на фото
nonisolated enum TableRecognizer {
    enum Failure: Error {
        case noText
    }

    /// layoutOnly — сразу способ для iOS 18 (для проверки)
    static func recognize(_ cgImage: CGImage, maxRows: Int, maxColumns: Int, layoutOnly: Bool = false) async throws -> RecognizedTable {
        let pixels = PixelBuffer(cgImage)
        if !layoutOnly, #available(iOS 26.0, macOS 26.0, *), let table = try? await recognizeDocument(cgImage, pixels: pixels) {
            return trimmed(table, maxRows: maxRows, maxColumns: maxColumns)
        }
        return trimmed(try await recognizeByLayout(cgImage, pixels: pixels), maxRows: maxRows, maxColumns: maxColumns)
    }

    static let languages = [Locale.Language(identifier: "en-US"), Locale.Language(identifier: "ru-RU")]

    // MARK: - iOS 26: распознавание документа

    @available(iOS 26.0, macOS 26.0, *)
    private static func recognizeDocument(_ image: CGImage, pixels: PixelBuffer?) async throws -> RecognizedTable? {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = languages
        request.textRecognitionOptions.useLanguageCorrection = true
        let documents = try await request.perform(on: image)
        // Самая большая таблица на фото
        guard let table = documents.flatMap(\.document.tables).max(by: { cellCount($0) < cellCount($1) }),
              cellCount(table) > 1 else { return nil }

        let allCells = table.rows.flatMap { $0 }
        let rows = (allCells.map(\.rowRange.upperBound).max() ?? 0) + 1
        let columns = (allCells.map(\.columnRange.upperBound).max() ?? 0) + 1
        var result = RecognizedTable(cells: Array(repeating: Array(repeating: "", count: columns), count: rows))
        var seen: Set<String> = []
        for cell in allCells {
            let row = cell.rowRange.lowerBound, column = cell.columnRange.lowerBound
            // Объединённая ячейка может прийти в нескольких строках — берём один раз
            guard seen.insert("\(row):\(column)").inserted else { continue }
            let lines = cell.content.text.lines
            result.cells[row][column] = lines.map(\.transcript).joined(separator: "\n")
            if cell.rowRange.count > 1 || cell.columnRange.count > 1 {
                result.spans.append(.init(row: row, column: column,
                                          rowSpan: cell.rowRange.count, columnSpan: cell.columnRange.count))
            }
            if let pixels, let tone = tone(of: lines.map(\.boundingBox.cgRect), in: pixels) {
                result.tones["\(row):\(column)"] = tone
            }
        }
        return result.cells.joined().contains(where: { !$0.isEmpty }) ? result : nil
    }

    @available(iOS 26.0, macOS 26.0, *)
    private static func cellCount(_ table: DocumentObservation.Container.Table) -> Int {
        table.rows.reduce(0) { $0 + $1.count }
    }

    // MARK: - iOS 18: текст + линии сетки

    /// Строка текста на фото; координаты Vision — от 0 до 1, начало внизу слева
    private struct TextLine {
        let text: String
        let box: CGRect
    }

    private static func recognizeByLayout(_ image: CGImage, pixels: PixelBuffer?, straightened: Bool = false) async throws -> RecognizedTable {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: image)
        let lines = observations.compactMap { observation -> TextLine? in
            guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces),
                  !text.isEmpty else { return nil }
            return TextLine(text: text, box: observation.boundingBox.cgRect)
        }
        guard !lines.isEmpty else { throw Failure.noText }

        // Фото чуть повёрнуто — строки текста сползают в соседние строки таблицы. Выравниваем и распознаём заново
        if !straightened, let angle = skew(of: observations, imageWidth: image.width, imageHeight: image.height),
           abs(angle) > 0.4 * .pi / 180, let rotated = rotate(image, by: -angle) {
            return try await recognizeByLayout(rotated, pixels: PixelBuffer(rotated), straightened: true)
        }

        // Область таблицы — где есть текст, с небольшим запасом
        let textArea = lines.map(\.box).reduce(lines[0].box) { $0.union($1) }.insetBy(dx: -0.02, dy: -0.02)
        let gridLines = pixels.map { GridLines(in: $0, area: textArea) }

        // Сверху вниз: у Vision y растёт вверх
        let rowBands = Array(bands(lines: gridLines?.horizontal ?? [], fallback: lines.map { ($0.box.minY, $0.box.maxY) },
                                   merge: false).reversed())
        // Широкий текст во всю таблицу («Simple tenses») склеил бы все столбцы — столбцы ищем по обычному
        let widths = lines.map(\.box.width).sorted()
        let typicalWidth = widths[widths.count / 2]
        let narrow = lines.filter { $0.box.width <= typicalWidth * 2.5 }
        let columnBands = bands(lines: gridLines?.vertical ?? [], fallback: narrow.map { ($0.box.minX, $0.box.maxX) },
                                merge: true)
        guard !rowBands.isEmpty, !columnBands.isEmpty else { throw Failure.noText }

        // Сетка из строк текста: [строка][столбец] → строки текста
        var grid = Array(repeating: Array(repeating: [TextLine](), count: columnBands.count), count: rowBands.count)
        var spans: [RecognizedTable.Span] = []
        for line in lines {
            let rowSpan = covered(rowBands, from: line.box.minY, to: line.box.maxY)
            let columnSpan = covered(columnBands, from: line.box.minX, to: line.box.maxX)
            guard let row = rowSpan.first, let column = columnSpan.first else { continue }
            grid[row][column].append(line)
            if rowSpan.count > 1 || columnSpan.count > 1, !spans.contains(where: { $0.row == row && $0.column == column }) {
                spans.append(.init(row: row, column: column, rowSpan: rowSpan.count, columnSpan: columnSpan.count))
            }
        }
        joinContinuationRows(&grid, spans: &spans)
        removeEmpty(&grid, spans: &spans)
        spanTitleRows(&grid, spans: &spans, table: textArea)

        var result = RecognizedTable(cells: grid.map { $0.map(joined) })
        for (row, cells) in grid.enumerated() {
            for (column, cellText) in cells.enumerated() where !cellText.isEmpty {
                if let pixels, let tone = tone(of: cellText.map(\.box), in: pixels) {
                    result.tones["\(row):\(column)"] = tone
                }
            }
        }
        result.spans = nonOverlapping(spans)
        return result
    }

    /// Без сетки ячейка в две строки («I worked / she worked») распадается на две строки таблицы.
    /// Строка-продолжение: подпись слева пустая, у предыдущей есть, текст только там, где он есть и выше, и стоит вплотную
    private static func joinContinuationRows(_ grid: inout [[[TextLine]]], spans: inout [RecognizedTable.Span]) {
        var row = 1
        while row < grid.count {
            let previous = grid[row - 1], current = grid[row]
            let filled = current.indices.filter { !current[$0].isEmpty }
            let gap = (previous.flatMap { $0 }.map(\.box.minY).min() ?? 0) - (current.flatMap { $0 }.map(\.box.maxY).max() ?? 0)
            let lineHeight = current.flatMap { $0 }.map(\.box.height).max() ?? 0
            if current[0].isEmpty, !previous[0].isEmpty, !filled.isEmpty,
               filled.allSatisfy({ !previous[$0].isEmpty }), gap < lineHeight * 0.8 {
                for column in filled { grid[row - 1][column] += current[column] }
                remove(row: row, from: &grid, spans: &spans)
            } else {
                row += 1
            }
        }
    }

    /// Пустые строки и столбцы — от рамки или полей фото
    private static func removeEmpty(_ grid: inout [[[TextLine]]], spans: inout [RecognizedTable.Span]) {
        for row in grid.indices.reversed() where grid[row].allSatisfy({ $0.isEmpty }) && grid.count > 1 {
            remove(row: row, from: &grid, spans: &spans)
        }
        for column in (grid.first?.indices ?? 0..<0).reversed() where grid.allSatisfy({ $0[column].isEmpty }) && grid[0].count > 1 {
            for row in grid.indices { grid[row].remove(at: column) }
            spans = spans.compactMap { span in
                if span.column > column { return .init(row: span.row, column: span.column - 1, rowSpan: span.rowSpan, columnSpan: span.columnSpan) }
                if span.column + span.columnSpan > column {
                    return span.columnSpan > 1 ? .init(row: span.row, column: span.column, rowSpan: span.rowSpan, columnSpan: span.columnSpan - 1) : nil
                }
                return span
            }
        }
    }

    private static func remove(row: Int, from grid: inout [[[TextLine]]], spans: inout [RecognizedTable.Span]) {
        grid.remove(at: row)
        spans = spans.compactMap { span in
            if span.row > row { return .init(row: span.row - 1, column: span.column, rowSpan: span.rowSpan, columnSpan: span.columnSpan) }
            if span.row + span.rowSpan > row {
                return span.rowSpan > 1 ? .init(row: span.row, column: span.column, rowSpan: span.rowSpan - 1, columnSpan: span.columnSpan) : nil
            }
            return span
        }
    }

    /// Строка с одним текстом посередине таблицы («Simple tenses») — заголовок на всю ширину
    private static func spanTitleRows(_ grid: inout [[[TextLine]]], spans: inout [RecognizedTable.Span], table: CGRect) {
        let columns = grid.first?.count ?? 0
        guard columns > 1 else { return }
        for row in grid.indices {
            let filled = grid[row].indices.filter { !grid[row][$0].isEmpty }
            guard filled.count == 1, let column = filled.first,
                  let middle = grid[row][column].map(\.box.midX).max(),
                  abs(middle - table.midX) < table.width * 0.15 else { continue }
            grid[row][0] = grid[row][column]
            if column != 0 { grid[row][column] = [] }
            spans.removeAll { $0.row == row }
            spans.append(.init(row: row, column: 0, rowSpan: 1, columnSpan: columns))
        }
    }

    /// Наклон в радианах: текст одной строки таблицы, стоящий далеко друг от друга, на ровном фото — на одной высоте.
    /// Берём медиану по таким парам; nil — если пар мало
    private static func skew(of observations: [RecognizedTextObservation], imageWidth: Int, imageHeight: Int) -> CGFloat? {
        let boxes = observations.map { $0.boundingBox.cgRect }
        var angles: [CGFloat] = []
        for (index, a) in boxes.enumerated() {
            for b in boxes[(index + 1)...] {
                let (left, right) = a.midX < b.midX ? (a, b) : (b, a)
                let dx = (right.midX - left.midX) * CGFloat(imageWidth)
                let dy = (right.midY - left.midY) * CGFloat(imageHeight)
                let height = max(left.height, right.height) * CGFloat(imageHeight)
                guard dx > CGFloat(imageWidth) * 0.2, abs(dy) < height * 1.5 else { continue }
                angles.append(atan2(dy, dx))
            }
        }
        guard angles.count >= 3 else { return nil }
        angles.sort()
        return angles[angles.count / 2]
    }

    /// Поворот вокруг центра; углы, вышедшие за край, — белые
    private static func rotate(_ image: CGImage, by angle: CGFloat) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        context.rotate(by: angle)
        context.draw(image, in: CGRect(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2, width: CGFloat(width), height: CGFloat(height)))
        return context.makeImage()
    }

    /// Полосы строк или столбцов: между линиями сетки, если их видно, иначе — по просветам между текстом.
    /// Возвращает полосы по возрастанию координаты
    private static func bands(lines: [CGFloat], fallback extents: [(CGFloat, CGFloat)], merge: Bool) -> [(CGFloat, CGFloat)] {
        if lines.count >= 3 {
            let sorted = lines.sorted()
            let between = zip(sorted, sorted.dropFirst()).map { ($0, $1) }
            // Только полосы, где есть текст
            return between.filter { band in extents.contains { $0.0 < band.1 && $0.1 > band.0 } }
        }
        // Без сетки: соседний текст, который перекрывается по координате, — одна полоса
        var result: [(CGFloat, CGFloat)] = []
        for extent in extents.sorted(by: { $0.0 < $1.0 }) {
            if let last = result.last, extent.0 < last.1 - (merge ? 0 : (last.1 - last.0) * 0.4) {
                result[result.count - 1].1 = max(last.1, extent.1)
            } else {
                result.append(extent)
            }
        }
        // Между полосами — граница посередине просвета, чтобы любая строка текста попала в полосу
        for index in result.indices.dropLast() {
            let middle = (result[index].1 + result[index + 1].0) / 2
            result[index].1 = middle
            result[index + 1].0 = middle
        }
        return result
    }

    /// Какие полосы занимает текст: основная — где его середина, соседние — если текст заходит в них больше чем наполовину
    private static func covered(_ bands: [(CGFloat, CGFloat)], from low: CGFloat, to high: CGFloat) -> [Int] {
        let middle = (low + high) / 2
        guard let main = bands.firstIndex(where: { middle >= $0.0 && middle <= $0.1 })
                ?? bands.indices.min(by: { abs(center(bands[$0]) - middle) < abs(center(bands[$1]) - middle) })
        else { return [] }
        var first = main, last = main
        while first > 0, overlap(bands[first - 1], low, high) > 0.5 { first -= 1 }
        while last < bands.count - 1, overlap(bands[last + 1], low, high) > 0.5 { last += 1 }
        return Array(first...last)
    }

    private static func center(_ band: (CGFloat, CGFloat)) -> CGFloat { (band.0 + band.1) / 2 }

    /// Какая доля полосы закрыта текстом
    private static func overlap(_ band: (CGFloat, CGFloat), _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        let width = band.1 - band.0
        guard width > 0 else { return 0 }
        return max(0, min(band.1, high) - max(band.0, low)) / width
    }

    /// Строки ячейки — сверху вниз; на одной высоте — слева направо через пробел
    private static func joined(_ lines: [TextLine]) -> String {
        let sorted = lines.sorted { $0.box.midY > $1.box.midY }
        var rows: [[TextLine]] = []
        for line in sorted {
            if let last = rows.last?.first, abs(last.box.midY - line.box.midY) < last.box.height * 0.5 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
            .joined(separator: "\n")
    }

    /// Объединения не должны накрывать друг друга — лишние отбрасываем
    private static func nonOverlapping(_ spans: [RecognizedTable.Span]) -> [RecognizedTable.Span] {
        var taken: Set<String> = []
        var result: [RecognizedTable.Span] = []
        for span in spans.sorted(by: { $0.rowSpan * $0.columnSpan > $1.rowSpan * $1.columnSpan }) {
            let keys = (span.row..<span.row + span.rowSpan).flatMap { r in
                (span.column..<span.column + span.columnSpan).map { "\(r):\($0)" }
            }
            guard keys.allSatisfy({ !taken.contains($0) }) else { continue }
            taken.formUnion(keys)
            result.append(span)
        }
        return result
    }

    // MARK: - Цвет текста

    /// Красный или серый текст — по цвету «чернил» внутри рамок строк; обычный тёмный — nil
    private static func tone(of boxes: [CGRect], in pixels: PixelBuffer) -> RecognizedTable.Tone? {
        var red = 0, gray = 0, total = 0
        for box in boxes {
            guard let ink = pixels.inkColor(in: box) else { continue }
            total += 1
            let (r, g, b) = ink
            let brightness = (r + g + b) / 3
            let saturation = max(r, g, b) - min(r, g, b)
            if r > 110, r - max(g, b) > 45 {
                red += 1
            } else if saturation < 35, brightness > 95 {
                gray += 1
            }
        }
        guard total > 0 else { return nil }
        if red * 2 > total { return .red }
        if gray * 2 > total { return .gray }
        return nil
    }

    private static func trimmed(_ table: RecognizedTable, maxRows: Int, maxColumns: Int) -> RecognizedTable {
        guard table.rows > maxRows || table.columns > maxColumns else { return table }
        var result = table
        result.cells = table.cells.prefix(maxRows).map { Array($0.prefix(maxColumns)) }
        result.spans = table.spans.compactMap { span in
            guard span.row < maxRows, span.column < maxColumns else { return nil }
            return .init(row: span.row, column: span.column, rowSpan: min(span.rowSpan, maxRows - span.row),
                         columnSpan: min(span.columnSpan, maxColumns - span.column))
        }
        result.tones = table.tones.filter { key, _ in
            let position = key.split(separator: ":").compactMap { Int($0) }
            return position.count == 2 && position[0] < maxRows && position[1] < maxColumns
        }
        result.wasTrimmed = true
        return result
    }
}

/// Пиксели фото в RGBA — для цвета текста и линий сетки
nonisolated struct PixelBuffer: Sendable {
    let width: Int
    let height: Int
    private let data: [UInt8]

    init?(_ image: CGImage) {
        // Для анализа хватает ~1500 точек по большей стороне
        let scale = min(1, 1500 / CGFloat(max(image.width, image.height)))
        let w = max(1, Int(CGFloat(image.width) * scale))
        let h = max(1, Int(CGFloat(image.height) * scale))
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        width = w
        height = h
        data = bytes
    }

    /// Цвет точки; y — как у Vision, снизу вверх
    func rgb(x: Int, y: Int) -> (Int, Int, Int) {
        let row = height - 1 - y
        let index = (row * width + x) * 4
        return (Int(data[index]), Int(data[index + 1]), Int(data[index + 2]))
    }

    func brightness(x: Int, y: Int) -> Int {
        let (r, g, b) = rgb(x: x, y: y)
        return (r + g + b) / 3
    }

    /// Средний цвет самых тёмных точек в рамке (буквы), если они заметно темнее фона
    func inkColor(in box: CGRect) -> (Int, Int, Int)? {
        let x0 = max(0, Int(box.minX * CGFloat(width))), x1 = min(width - 1, Int(box.maxX * CGFloat(width)))
        let y0 = max(0, Int(box.minY * CGFloat(height))), y1 = min(height - 1, Int(box.maxY * CGFloat(height)))
        guard x1 > x0, y1 > y0 else { return nil }
        var samples: [(brightness: Int, color: (Int, Int, Int))] = []
        let step = max(1, (x1 - x0) * (y1 - y0) / 4000)
        var index = 0
        for y in y0...y1 {
            for x in x0...x1 {
                index += 1
                guard index % step == 0 else { continue }
                let color = rgb(x: x, y: y)
                samples.append(((color.0 + color.1 + color.2) / 3, color))
            }
        }
        guard samples.count > 20 else { return nil }
        samples.sort { $0.brightness < $1.brightness }
        let background = samples[samples.count * 3 / 4].brightness
        let ink = samples.prefix(max(3, samples.count / 12))
        guard let darkest = ink.last?.brightness, background - darkest > 40 else { return nil }
        let sum = ink.reduce((0, 0, 0)) { ($0.0 + $1.color.0, $0.1 + $1.color.1, $0.2 + $1.color.2) }
        return (sum.0 / ink.count, sum.1 / ink.count, sum.2 / ink.count)
    }
}

/// Линии сетки таблицы: длинные тёмные полосы поперёк области с текстом. Координаты — как у Vision, 0…1
nonisolated struct GridLines {
    var horizontal: [CGFloat] = []
    var vertical: [CGFloat] = []

    init(in pixels: PixelBuffer, area: CGRect) {
        let x0 = max(0, Int(area.minX * CGFloat(pixels.width))), x1 = min(pixels.width - 1, Int(area.maxX * CGFloat(pixels.width)))
        let y0 = max(0, Int(area.minY * CGFloat(pixels.height))), y1 = min(pixels.height - 1, Int(area.maxY * CGFloat(pixels.height)))
        guard x1 - x0 > 20, y1 - y0 > 20 else { return }
        // Порог «тёмного» — заметно темнее типичного фона
        var sample: [Int] = []
        for y in stride(from: y0, through: y1, by: 7) {
            for x in stride(from: x0, through: x1, by: 7) { sample.append(pixels.brightness(x: x, y: y)) }
        }
        sample.sort()
        let background = sample[sample.count * 3 / 4]
        let threshold = background - 45

        horizontal = Self.lines(count: y1 - y0 + 1, length: x1 - x0 + 1, minFraction: 0.6) { i, j in
            pixels.brightness(x: x0 + j, y: y0 + i) < threshold
        }.map { CGFloat(y0 + $0) / CGFloat(pixels.height) }
        // Вертикальные линии рвутся у объединённых ячеек — достаточно трети высоты
        vertical = Self.lines(count: x1 - x0 + 1, length: y1 - y0 + 1, minFraction: 0.35) { i, j in
            pixels.brightness(x: x0 + i, y: y0 + j) < threshold
        }.map { CGFloat(x0 + $0) / CGFloat(pixels.width) }
        // Края таблицы — тоже границы, даже если рамки нет
        if !horizontal.isEmpty {
            horizontal = Self.withEdges(horizontal, area.minY, area.maxY)
        }
        if !vertical.isEmpty {
            vertical = Self.withEdges(vertical, area.minX, area.maxX)
        }
    }

    /// Позиции, где тёмные точки занимают не меньше minFraction длины; соседние позиции — одна линия
    private static func lines(count: Int, length: Int, minFraction: Double, isDark: (Int, Int) -> Bool) -> [Int] {
        var found: [Int] = []
        var runStart: Int?
        for i in 0..<count {
            var dark = 0
            for j in stride(from: 0, to: length, by: 2) where isDark(i, j) { dark += 1 }
            let isLine = Double(dark) / Double((length + 1) / 2) >= minFraction
            if isLine, runStart == nil { runStart = i }
            if !isLine, let start = runStart {
                found.append((start + i - 1) / 2)
                runStart = nil
            }
        }
        if let start = runStart { found.append((start + count - 1) / 2) }
        return found
    }

    private static func withEdges(_ lines: [CGFloat], _ low: CGFloat, _ high: CGFloat) -> [CGFloat] {
        var result = lines
        if let first = result.min(), first - low > 0.02 { result.append(low) }
        if let last = result.max(), high - last > 0.02 { result.append(high) }
        return result.sorted()
    }
}

// MARK: - UIKit

nonisolated extension TableRecognizer {
    static func recognize(_ image: UIImage, maxRows: Int, maxColumns: Int) async throws -> RecognizedTable {
        guard let cgImage = upright(image) else { throw Failure.noText }
        return try await recognize(cgImage, maxRows: maxRows, maxColumns: maxColumns)
    }

    /// Фото с камеры часто повёрнуто метаданными — рисуем как видно на экране, крупные уменьшаем
    static func upright(_ image: UIImage) -> CGImage? {
        let maxSide: CGFloat = 3000
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
