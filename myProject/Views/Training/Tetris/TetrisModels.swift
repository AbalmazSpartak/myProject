import SwiftUI

// Структура относительной позиции блока в фигуре
struct BlockPosition {
    var x: Int
    var y: Int
}

// 7 классических фигур Тетриса
enum TetrominoShape: CaseIterable {
    case I, J, L, O, S, T, Z

    var relativeBlocks: [BlockPosition] {
        switch self {
        case .I: return [BlockPosition(x: 0, y: 0), BlockPosition(x: -1, y: 0), BlockPosition(x: 1, y: 0), BlockPosition(x: 2, y: 0)]
        case .J: return [BlockPosition(x: 0, y: 0), BlockPosition(x: -1, y: 0), BlockPosition(x: 1, y: 0), BlockPosition(x: -1, y: -1)]
        case .L: return [BlockPosition(x: 0, y: 0), BlockPosition(x: -1, y: 0), BlockPosition(x: 1, y: 0), BlockPosition(x: 1, y: -1)]
        case .O: return [BlockPosition(x: 0, y: 0), BlockPosition(x: 1, y: 0), BlockPosition(x: 0, y: -1), BlockPosition(x: 1, y: -1)]
        case .S: return [BlockPosition(x: 0, y: 0), BlockPosition(x: -1, y: 0), BlockPosition(x: 0, y: -1), BlockPosition(x: 1, y: -1)]
        case .T: return [BlockPosition(x: 0, y: 0), BlockPosition(x: -1, y: 0), BlockPosition(x: 1, y: 0), BlockPosition(x: 0, y: -1)]
        case .Z: return [BlockPosition(x: 0, y: 0), BlockPosition(x: 1, y: 0), BlockPosition(x: 0, y: -1), BlockPosition(x: -1, y: -1)]
        }
    }

    var color: Color {
        switch self {
        case .I: return .cyan
        case .J: return .blue
        case .L: return .orange
        case .O: return .yellow
        case .S: return .green
        case .T: return .purple
        case .Z: return .red
        }
    }
}
