import SwiftUI
import SwiftData
import Combine

struct TetrisView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var allWords: [Word] = []
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []
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
    @State private var currentOptions: [String] = []
    @State private var selectedAnswer: String? = nil
    @State private var speedBoostUntil: Date? = nil
    
    // Динамическая скорость
    @State private var dropInterval: Double = 0.6
    @State private var lastTickTime = Date()
    
    @State private var isSoftDropping: Bool = false
    @State private var lastHorizontalStep: Int = 0
    
    // Высокочастотный таймер для плавного учета переменной скорости
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
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
                    
                    Button(action: { isPaused.toggle() }) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.indigo)
                    }

                    HelpButton(topic: .tetris) { isPaused = true }
                    
                    Spacer()
                    
                    Text("Счет: \(score)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.indigo)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                if let word = currentWord {
                    VStack(spacing: 8) {
                        HStack {
                            Text(word.english)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.brandDark)
                            
                            Spacer()
                            
                            Button(action: {
                                TextToSpeechManager.shared.speak(word.english)
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.indigo)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            ForEach(currentOptions, id: \.self) { option in
                                Button(action: { selectAnswer(option) }) {
                                    Text(option)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(optionBackground(option, word: word))
                                        .foregroundColor(optionForeground(option, word: word))
                                        .cornerRadius(10)
                                }
                                .disabled(selectedAnswer != nil)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
                
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
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            let smallThreshold: CGFloat = 10
                            let horizontalStepSize: CGFloat = 45 // пикселей на одну клетку сдвига
                            
                            if abs(dx) > abs(dy) && abs(dx) > smallThreshold {
                                // Горизонтальное удержание — двигаем фигуру по шагам, пока ведут палец дальше
                                isSoftDropping = false
                                let currentStep = Int(dx / horizontalStepSize)
                                if currentStep != lastHorizontalStep {
                                    let diff = currentStep - lastHorizontalStep
                                    if diff > 0 {
                                        for _ in 0..<diff { moveRight() }
                                    } else {
                                        for _ in 0..<(-diff) { moveLeft() }
                                    }
                                    lastHorizontalStep = currentStep
                                }
                            } else if dy > smallThreshold {
                                // Небольшое/долгое движение вниз — ускоренное падение, пока палец удерживают
                                isSoftDropping = true
                            } else {
                                isSoftDropping = false
                            }
                        }
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            let smallThreshold: CGFloat = 10
                            
                            isSoftDropping = false
                            lastHorizontalStep = 0
                            
                            if abs(dx) < smallThreshold && abs(dy) < smallThreshold {
                                // Почти нет сдвига — переворот фигуры
                                rotate()
                            }
                            // Горизонтальное перемещение и ускорение вниз уже отработали в onChanged —
                            // на отпускание пальца больше ничего делать не нужно
                        }
                )
                Spacer()
            }
            .background(Color.brandBackground.ignoresSafeArea())
            
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
        // Палец ведёт фигуру — свайп от края не должен выкидывать из игры
        .swipeBackDisabled()
        .onAppear {
            loadWords()
            restartGame()
        }
        .onReceive(timer) { _ in
            if !isGameOver && !isPaused {
                var effectiveInterval = isSoftDropping ? max(0.05, dropInterval / 4) : dropInterval
                if let boostUntil = speedBoostUntil, Date() < boostUntil {
                    effectiveInterval *= 2
                }
                if Date().timeIntervalSince(lastTickTime) >= effectiveInterval {
                    gameTick()
                    lastTickTime = Date()
                }
            }
        }
    }
    
    private func cellColor(r: Int, c: Int) -> Color {
        if let staticColor = grid[r][c] {
            return staticColor
        }
        if !isGameOver {
            // Падающая фигура — в приоритете
            for b in currentBlocks {
                let absoluteX = currentOffset.x + b.x
                let absoluteY = currentOffset.y + b.y
                if absoluteX == c && absoluteY == r {
                    return currentShape.color
                }
            }
            // Тень фигуры на месте приземления
            let ghost = ghostOffset
            for b in currentBlocks {
                let absoluteX = ghost.x + b.x
                let absoluteY = ghost.y + b.y
                if absoluteX == c && absoluteY == r {
                    return currentShape.color.opacity(0.25)
                }
            }
        }
        return Color.gray.opacity(0.15)
    }
    
    // Позиция, куда фигура упадёт, если сбросить её сейчас
    private var ghostOffset: BlockPosition {
        var testY = currentOffset.y
        while canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x, y: testY + 1)) {
            testY += 1
        }
        return BlockPosition(x: currentOffset.x, y: testY)
    }
    
    private func gameTick() {
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x, y: currentOffset.y + 1)) {
            currentOffset.y += 1
        } else {
            lockPiece()
            clearLines()
            spawnNewPiece()
        }
    }
    
    private func moveLeft() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x - 1, y: currentOffset.y)) {
            currentOffset.x -= 1
        }
    }
    
    private func moveRight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x + 1, y: currentOffset.y)) {
            currentOffset.x += 1
        }
    }
    
    private func rotate() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let rotated = currentBlocks.map { BlockPosition(x: -$0.y, y: $0.x) }
        
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
    
    private func dropDown() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var newY = currentOffset.y
        while canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x, y: newY + 1)) {
            newY += 1
        }
        currentOffset.y = newY
        gameTick()
    }
    
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
    
    private func lockPiece() {
        for b in currentBlocks {
            let x = currentOffset.x + b.x
            let y = currentOffset.y + b.y
            if y >= 0 && y < rows && x >= 0 && x < cols {
                grid[y][x] = currentShape.color
            }
        }
    }
    
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
    
    private func spawnNewPiece() {
        guard let newShape = TetrominoShape.allCases.randomElement() else { return }
        currentShape = newShape
        currentBlocks = newShape.relativeBlocks
        currentOffset = BlockPosition(x: cols / 2 - 1, y: 0)
        
        if !canMove(blocks: currentBlocks, offset: currentOffset) {
            isGameOver = true
            
            if let word = currentWord {
                word.isMistake = true
            }
            
            handleGameOver()
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } else {
            pickRandomWord()
        }
    }
    
    private func loadWords() {
        allWords = modelContext.fetchAllWords()
        studyWords = allWords.filter { studyScope.includes($0) }
    }

    private func pickRandomWord() {
        // Если в настройках не выбрано ни одного слова, играем по всему словарю
        let pool = studyWords.isEmpty ? allWords : studyWords
        let mistakeWords = pool.filter { $0.isMistake }
        
        if !mistakeWords.isEmpty {
            currentWord = mistakeWords.randomElement()
        } else if !pool.isEmpty {
            currentWord = pool.randomElement()
        }
        
        selectedAnswer = nil
        if let word = currentWord {
            generateOptions(for: word)
        }
    }
    private func generateOptions(for word: Word) {
        let correctAnswer = word.russian
        let wrongAnswers = allWords.randomWrongAnswers(2, excluding: correctAnswer) { $0.russian }
        currentOptions = ([correctAnswer] + wrongAnswers).shuffled()
    }

    private func selectAnswer(_ answer: String) {
        guard let word = currentWord, selectedAnswer == nil else { return }
        selectedAnswer = answer
        
        let isCorrect = answer.lowercased() == word.russian.lowercased()
        
        if isCorrect {
            word.isMistake = false
            speedBoostUntil = Date().addingTimeInterval(5)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            word.isMistake = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            // Если слово уже сменилось (например, из-за очистки линии), выбор не сбрасываем повторно
            if currentWord?.id == word.id {
                withAnimation {
                    selectedAnswer = nil
                }
            }
        }
    }

    private func optionBackground(_ option: String, word: Word) -> Color {
        guard let selected = selectedAnswer else {
            return Color(.systemGray5)
        }
        if option.lowercased() == word.russian.lowercased() {
            return Color.green.opacity(0.25)
        }
        if option == selected {
            return Color.red.opacity(0.25)
        }
        return Color(.systemGray5)
    }

    private func optionForeground(_ option: String, word: Word) -> Color {
        guard let selected = selectedAnswer else {
            return .brandDark
        }
        if option.lowercased() == word.russian.lowercased() {
            return .green
        }
        if option == selected {
            return .red
        }
        return .gray
    }
    
    private func restartGame() {
        grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        score = 0
        dropInterval = 0.6
        lastTickTime = Date()
        isGameOver = false
        spawnNewPiece()
    }
    
    private func handleGameOver() {
        if let profile = userProfile {
            if score > profile.tetrisHighScore {
                profile.tetrisHighScore = score
            }
        }
    }
}
