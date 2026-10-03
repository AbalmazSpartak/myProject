import SwiftUI

/// Место ячейки в сетке: строка, столбец и сколько строк и столбцов она занимает
nonisolated struct GridCellPlacement: Hashable {
    var row: Int
    var column: Int
    var rowSpan = 1
    var columnSpan = 1
}

private nonisolated struct GridCellPlacementKey: LayoutValueKey {
    static let defaultValue = GridCellPlacement(row: 0, column: 0)
}

extension View {
    func gridCellPlacement(_ placement: GridCellPlacement) -> some View {
        layoutValue(key: GridCellPlacementKey.self, value: placement)
    }
}

/// Сетка с объединёнными ячейками: стандартный Grid умеет объединять только по горизонтали.
/// Ширина столбца — по самой широкой одиночной ячейке (не больше maxColumnWidth, дальше текст переносится),
/// высота строки — по самой высокой; объединённой ячейке не хватило места — добираем поровну в её столбцы и строки.
/// Таблица уже fillWidth — столбцы растягиваются до неё пропорционально своей ширине
struct SpanGridLayout: Layout {
    let rows: Int
    let columns: Int
    var minColumnWidth: CGFloat = 36
    var maxColumnWidth: CGFloat = 240
    /// Ширина, до которой растянуть узкую таблицу; 0 — не растягивать
    var fillWidth: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let (widths, heights) = measure(subviews)
        return CGSize(width: widths.reduce(0, +), height: heights.reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (widths, heights) = measure(subviews)
        let xs = offsets(widths)
        let ys = offsets(heights)
        for subview in subviews {
            let cell = clamped(subview[GridCellPlacementKey.self])
            let width = widths[cell.column..<cell.column + cell.columnSpan].reduce(0, +)
            let height = heights[cell.row..<cell.row + cell.rowSpan].reduce(0, +)
            subview.place(at: CGPoint(x: bounds.minX + xs[cell.column], y: bounds.minY + ys[cell.row]),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: height))
        }
    }

    private func measure(_ subviews: Subviews) -> (widths: [CGFloat], heights: [CGFloat]) {
        guard rows > 0, columns > 0 else { return ([], []) }
        let cells = subviews.map { clamped($0[GridCellPlacementKey.self]) }
        let ideals = subviews.map { min($0.sizeThatFits(.unspecified).width, maxColumnWidth) }

        var widths = Array(repeating: minColumnWidth, count: columns)
        for (index, cell) in cells.enumerated() where cell.columnSpan == 1 {
            widths[cell.column] = max(widths[cell.column], ideals[index])
        }
        for (index, cell) in cells.enumerated() where cell.columnSpan > 1 {
            grow(&widths, range: cell.column..<cell.column + cell.columnSpan, toFit: ideals[index])
        }
        // Растягиваем до ширины экрана до расчёта высот: в широкой ячейке текст переносится реже
        let total = widths.reduce(0, +)
        if fillWidth > total, total > 0 {
            let scale = fillWidth / total
            widths = widths.map { $0 * scale }
        }

        func height(_ index: Int) -> CGFloat {
            let cell = cells[index]
            let width = widths[cell.column..<cell.column + cell.columnSpan].reduce(0, +)
            return subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        var heights = Array(repeating: CGFloat(0), count: rows)
        for (index, cell) in cells.enumerated() where cell.rowSpan == 1 {
            heights[cell.row] = max(heights[cell.row], height(index))
        }
        for (index, cell) in cells.enumerated() where cell.rowSpan > 1 {
            grow(&heights, range: cell.row..<cell.row + cell.rowSpan, toFit: height(index))
        }
        return (widths, heights)
    }

    private func grow(_ sizes: inout [CGFloat], range: Range<Int>, toFit needed: CGFloat) {
        let current = sizes[range].reduce(0, +)
        guard needed > current else { return }
        let extra = (needed - current) / CGFloat(range.count)
        for index in range { sizes[index] += extra }
    }

    private func offsets(_ sizes: [CGFloat]) -> [CGFloat] {
        sizes.reduce(into: [0]) { $0.append($0.last! + $1) }
    }

    /// Объединение не выходит за край таблицы
    private func clamped(_ cell: GridCellPlacement) -> GridCellPlacement {
        let row = min(max(cell.row, 0), rows - 1)
        let column = min(max(cell.column, 0), columns - 1)
        return GridCellPlacement(row: row, column: column,
                                 rowSpan: min(max(cell.rowSpan, 1), rows - row),
                                 columnSpan: min(max(cell.columnSpan, 1), columns - column))
    }
}
