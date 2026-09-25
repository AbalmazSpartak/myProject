import SwiftUI
import SwiftData
import Combine

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

struct TetrisView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @Query private var profiles: [UserProfile]
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    // Поле 10х20
    private let cols = 10
    private let rows = 20
    
    @State private var grid: [[Color?]] = Array(repeating: Array(repeating: nil, count: 10), count: 20)
    
    // Падающая фигура
    @State private var currentShape: TetrominoShape = .I
    @State private var currentBlocks: [BlockPosition] = TetrominoShape.I.relativeBlocks
    @State private var currentOffset = BlockPosition(x: 4, y: 0)
    
    // Состояние игры
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var isPaused: Bool = false
    @State private var currentWord: Word?
    
    // Динамическая скорость
    @State private var dropInterval: Double = 0.6
    @State private var lastTickTime = Date()
    
    // Высокочастотный таймер для плавного учета переменной скорости
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                // Верхняя панель
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Меню")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.indigo)
                    }
                    
                    Spacer()
                    
                    Text("Тетрис слов")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.brandDark)
                    
                    // 👈 Кнопка паузы
                    Button(action: { isPaused.toggle() }) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.indigo)
                    }
                    
                    Spacer()
                    
                    Text("Счет: \(score)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.indigo)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Словарная карточка над полем
                if let word = currentWord {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(word.english)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.brandDark)
                            Text(word.russian)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: {
                            TextToSpeechManager.shared.speak(word.english)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.indigo)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
                
                // Игровое сетчатое поле
                VStack(spacing: 2) {
                    ForEach(0..<rows, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(0..<cols, id: \.self) { c in
                                Rectangle()
                                    .fill(cellColor(r: r, c: c))
                                    .frame(width: 22, height: 22)
                                    .cornerRadius(3)
                            }
                        }
                    }
                }
                .padding(6)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                .onTapGesture {
                    rotate()
                }
                
                // Кнопки управления (4 кнопки: Влево, Поворот, Вправо, Ускорение)
                HStack(spacing: 16) {
                    Button(action: moveLeft) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 42))
                    }
                    
                    Button(action: rotate) {
                        Image(systemName: "rotate.right.circle.fill")
                            .font(.system(size: 42))
                    }
                    
                    Button(action: moveRight) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 42))
                    }
                    
                    Button(action: dropDown) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 42))
                    }
                }
                .foregroundColor(.indigo)
                .padding(.top, 6)
                
                Spacer()
            }
            .background(Color.brandBackground.ignoresSafeArea())
            
            // Кастомный оверлей Game Over
            if isGameOver {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.yellow)
                    
                    Text("Игра окончена")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                    
                    VStack(spacing: 8) {
                        Text("Ваш счет: \(score)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.indigo)
                        
                        if let highScore = userProfile?.tetrisHighScore, highScore > 0 {
                            Text("Рекорд: \(highScore)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    
                    HStack(spacing: 14) {
                        Button(action: restartGame) {
                            Text("Заново")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.indigo)
                                .cornerRadius(14)
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("В меню")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.brandDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(14)
                        }
                    }
                }
                .padding(24)
                .background(Color.brandBackground)
                .cornerRadius(24)
                .padding(.horizontal, 32)
                .shadow(radius: 20)
            }
            // Кастомный оверлей Паузы
            if isPaused && !isGameOver {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.indigo)
                    
                    Text("Пауза")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                    
                    Button(action: { isPaused = false }) {
                        Text("Продолжить")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 28)
                            .background(Color.indigo)
                            .cornerRadius(12)
                    }
                }
                .padding(24)
                .background(Color.brandBackground)
                .cornerRadius(20)
                .shadow(radius: 10)
            }
        }
        .onAppear {
            restartGame()
        }
        .onReceive(timer) { _ in
            if !isGameOver && !isPaused {
                if Date().timeIntervalSince(lastTickTime) >= dropInterval {
                    gameTick()
                    lastTickTime = Date()
                }
            }
        }
    }
    
    // Цвет клетки с учетом зафиксированных и падающих блоков
    private func cellColor(r: Int, c: Int) -> Color {
        if let staticColor = grid[r][c] {
            return staticColor
        }
        if !isGameOver {
            for b in currentBlocks {
                let absoluteX = currentOffset.x + b.x
                let absoluteY = currentOffset.y + b.y
                if absoluteX == c && absoluteY == r {
                    return currentShape.color
                }
            }
        }
        return Color.gray.opacity(0.15)
    }
    
    // Игровой тик падения
    private func gameTick() {
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x, y: currentOffset.y + 1)) {
            currentOffset.y += 1
        } else {
            lockPiece()
            clearLines()
            spawnNewPiece()
        }
    }
    
    // Движение влево
    private func moveLeft() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x - 1, y: currentOffset.y)) {
            currentOffset.x -= 1
        }
    }
    
    // Движение вправо
    private func moveRight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x + 1, y: currentOffset.y)) {
            currentOffset.x += 1
        }
    }
    
    // Поворот фигуры с проверкой сдвига от стен (Wall Kick)
    private func rotate() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let rotated = currentBlocks.map { BlockPosition(x: -$0.y, y: $0.x) }
        
        // Пробуем повернуть на текущей позиции, а если мешает стена — со сдвигом на 1 клетку влево/вправо
        let kickOffsets = [
            BlockPosition(x: 0, y: 0),
            BlockPosition(x: -1, y: 0),
            BlockPosition(x: 1, y: 0),
            BlockPosition(x: -2, y: 0),
            BlockPosition(x: 2, y: 0)
        ]
        
        for offset in kickOffsets {
            let testOffset = BlockPosition(x: currentOffset.x + offset.x, y: currentOffset.y + offset.y)
            if canMove(blocks: rotated, offset: testOffset) {
                currentBlocks = rotated
                currentOffset = testOffset
                break
            }
        }
    }
    
    // Быстрое сбрасывание вниз
    private func dropDown() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var newY = currentOffset.y
        while canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x, y: newY + 1)) {
            newY += 1
        }
        currentOffset.y = newY
        gameTick()
    }
    
    // Проверка коллизий со стенами и зафиксированными блоками
    private func canMove(blocks: [BlockPosition], offset: BlockPosition) -> Bool {
        for b in blocks {
            let x = offset.x + b.x
            let y = offset.y + b.y
            
            if x < 0 || x >= cols || y >= rows {
                return false
            }
            if y >= 0 && grid[y][x] != nil {
                return false
            }
        }
        return true
    }
    
    // Фиксация фигуры на сетке
    private func lockPiece() {
        for b in currentBlocks {
            let x = currentOffset.x + b.x
            let y = currentOffset.y + b.y
            if y >= 0 && y < rows && x >= 0 && x < cols {
                grid[y][x] = currentShape.color
            }
        }
    }
    
    // Проверка и удаление заполненных рядов
    private func clearLines() {
        var linesCleared = 0
        for r in 0..<rows {
            if grid[r].allSatisfy({ $0 != nil }) {
                grid.remove(at: r)
                grid.insert(Array(repeating: nil, count: cols), at: 0)
                linesCleared += 1
            }
        }
        
        if linesCleared > 0 {
            score += linesCleared * 100
            
            // Динамическое ускорение: каждые 300 очков ускоряем падение (мин. 0.15 сек)
            dropInterval = max(0.15, 0.6 - Double(score / 300) * 0.05)
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            if let word = currentWord {
                TextToSpeechManager.shared.speak(word.english)
                if word.isMistake {
                    word.isMistake = false
                }
            }
            
            pickRandomWord()
        }
    }
    
    // Создание новой детали вверху
    private func spawnNewPiece() {
        guard let newShape = TetrominoShape.allCases.randomElement() else { return }
        currentShape = newShape
        currentBlocks = newShape.relativeBlocks
        currentOffset = BlockPosition(x: cols / 2 - 1, y: 0)
        
        if !canMove(blocks: currentBlocks, offset: currentOffset) {
            isGameOver = true
            
            // 👈 Запоминаем слово как ошибку при проигрыше
            if let word = currentWord {
                word.isMistake = true
            }
            
            handleGameOver()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            pickRandomWord()
        }
    }
    
    private func pickRandomWord() {
        // 1. Ищем слова, в которых ранее были ошибки
        let mistakeWords = allWords.filter { $0.isMistake }
        
        if !mistakeWords.isEmpty {
            // Если есть ошибки — берем случайное из них
            currentWord = mistakeWords.randomElement()
        } else if !allWords.isEmpty {
            // Если ошибок нет — берем любое слово из базы
            currentWord = allWords.randomElement()
        }
    }
    
    private func restartGame() {
        grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        score = 0
        dropInterval = 0.6
        lastTickTime = Date()
        isGameOver = false
        spawnNewPiece()
    }
    
    // Сохранение рекорда при завершении игры
    private func handleGameOver() {
        if let profile = userProfile {
            if score > profile.tetrisHighScore {
                profile.tetrisHighScore = score
            }
        }
    }
}
