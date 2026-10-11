import SwiftUI
import SwiftData
import Combine

/// Тетрис слов: поле на весь экран, следующая фигура в шапке. На каждую фигуру — одно слово и один ответ;
/// «Подумать» останавливает фигуру до ответа (раз за фигуру). Обычная пауза меняет слово при возвращении
struct TetrisView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    /// Неправильные варианты ответа — из нескольких сотен случайных слов, а не из всей базы
    @State private var distractors: [Word] = []
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
    @State private var nextShape: TetrominoShape = TetrominoShape.allCases.randomElement() ?? .T
    @State private var currentBlocks: [BlockPosition] = TetrominoShape.I.relativeBlocks
    @State private var currentOffset = BlockPosition(x: 4, y: 0)
    
    // Состояние игры
    @State private var score: Int = 0
    @State private var isGameOver: Bool = false
    @State private var isPaused: Bool = false
    @State private var currentWord: Word?
    @State private var currentOptions: [String] = []
    @State private var selectedAnswer: String? = nil
    /// «Подумать»: фигура стоит, пока не выбран перевод
    @State private var isThinking = false
    /// «Подумать» уже брали для этой фигуры
    @State private var usedThinkThisPiece = false
    /// Замедление после серии верных ответов: до какого времени и во сколько раз
    @State private var speedBoostUntil: Date? = nil
    @State private var speedBoostFactor = 1.0
    /// Верных ответов подряд; каждые `streakForBonus` — бонус
    @State private var answerStreak = 0
    /// Сколько следующих фигур ещё получат ×2 за линии
    @State private var bonusPiecesLeft = 0
    /// У текущей фигуры ×2 за линии
    @State private var pieceHasBonus = false

    private static let streakForBonus = 5
    private static let bonusPieces = 3
    private static let slowdownSeconds: Double = 10
    private static let slowdownFactor = 1.5
    /// 3 верных подряд — лёгкое замедление
    private static let smallStreak = 3
    private static let smallSlowdownSeconds: Double = 5
    private static let smallSlowdownFactor = 1.25
    
    // Динамическая скорость
    @State private var dropInterval: Double = 0.6
    @State private var lastTickTime = Date()
    
    /// Сторона клетки поля: на iPhone 22, на iPad — сколько помещается на экране
    @State private var cellSize: CGFloat = 22

    @State private var isSoftDropping: Bool = false
    @State private var lastHorizontalStep: Int = 0
    
    // Высокочастотный таймер для плавного учета переменной скорости
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                header
                
                if let word = currentWord {
                    VStack(spacing: 8) {
                        HStack {
                            Text(word.english)
                                .scaledFont(size: 18, weight: .bold, design: .rounded)
                                .foregroundColor(.brandDark)
                            
                            Button(action: {
                                TextToSpeechManager.shared.speak(word.english)
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .scaledFont(size: 18)
                                    .foregroundColor(.indigo)
                            }

                            Spacer()

                            thinkButton
                        }
                        
                        HStack(spacing: 8) {
                            ForEach(currentOptions, id: \.self) { option in
                                Button(action: { selectAnswer(option) }) {
                                    Text(option)
                                        .scaledFont(size: 13, weight: .bold, design: .rounded)
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
                                    .frame(width: cellSize, height: cellSize)
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
                .modifier(BoardFit { size in fitCells(to: size) })
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
                        .scaledFont(size: 24, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                    
                    VStack(spacing: 8) {
                        Text("Ваш счет: \(score)")
                            .scaledFont(size: 20, weight: .heavy, design: .rounded)
                            .foregroundColor(.indigo)
                        
                        if let highScore = userProfile?.tetrisHighScore, highScore > 0 {
                            Text("Рекорд: \(highScore)")
                                .scaledFont(size: 14, weight: .semibold, design: .rounded)
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
                                .scaledFont(size: 16, weight: .bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.indigo)
                                .cornerRadius(14)
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("Выйти")
                                .scaledFont(size: 16, weight: .bold)
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
                // Без затемнения: слово всё равно сменится при возвращении в игру
                Button(action: resume) {
                    Label("Продолжить", systemImage: "play.fill")
                        .scaledFont(size: 18, weight: .bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 30)
                        .background(Capsule().fill(Color.indigo))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                }
            }
        }
        // Палец ведёт фигуру — свайп от края не должен выкидывать из игры
        .swipeBackDisabled()
        .statusBarHidden(true)
        // Свернули приложение — обычная пауза
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, !isGameOver { isPaused = true }
        }
        .onAppear {
            loadWords()
            restartGame()
        }
        .onReceive(timer) { _ in
            if !isGameOver && !isPaused && !isThinking {
                var effectiveInterval = isSoftDropping ? max(0.05, dropInterval / 4) : dropInterval
                if let boostUntil = speedBoostUntil, Date() < boostUntil {
                    effectiveInterval *= speedBoostFactor
                }
                if Date().timeIntervalSince(lastTickTime) >= effectiveInterval {
                    gameTick()
                    lastTickTime = Date()
                }
            }
        }
    }
    
    /// Поле 10 × 20 занимает всё место под словом: клетки — от 14 до 48 точек
    private func fitCells(to size: CGSize) {
        let byHeight = (size.height - 12 - CGFloat(rows - 1) * 2 - 8) / CGFloat(rows)
        let byWidth = (size.width - 12 - CGFloat(cols - 1) * 2 - 16) / CGFloat(cols)
        cellSize = max(14, min(48, floor(min(byHeight, byWidth))))
    }

    // MARK: - Шапка, следующая фигура, пауза

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 20, weight: .semibold)
                    .foregroundColor(.indigo)
            }
            .accessibilityLabel("Обзор")

            VStack(alignment: .leading, spacing: 1) {
                Text("Счёт: \(score)")
                    .scaledFont(size: 17, weight: .bold, design: .rounded)
                    .foregroundColor(.indigo)
                bonusStatus
            }

            Spacer()

            HStack(spacing: 6) {
                Text("Далее")
                    .scaledFont(size: 12, weight: .semibold)
                    .foregroundColor(.gray)
                NextPiecePreview(shape: nextShape)
            }

            Button(action: { isPaused ? resume() : pause() }) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .scaledFont(size: 18)
                    .foregroundColor(.indigo)
            }
            .accessibilityLabel(isPaused ? "Продолжить" : "Пауза")

            HelpButton(topic: .tetris) { pause() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    /// Серия верных «🔥 3/5» или действующий бонус «×2 · ещё 3 фигуры»
    @ViewBuilder
    private var bonusStatus: some View {
        let bonusLeft = bonusPiecesLeft + (pieceHasBonus ? 1 : 0)
        if bonusLeft > 0 {
            Text("×2 · ещё \(bonusLeft) \(Self.piecesNoun(bonusLeft))")
                .scaledFont(size: 12, weight: .heavy, design: .rounded)
                .foregroundColor(.orange)
        } else {
            Text("🔥 \(answerStreak % Self.streakForBonus)/\(Self.streakForBonus)")
                .scaledFont(size: 12, weight: .semibold, design: .rounded)
                .foregroundColor(.gray)
        }
    }

    /// 1 фигура, 2 фигуры, 5 фигур
    private static func piecesNoun(_ count: Int) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return "фигур" }
        switch last {
        case 1: return "фигура"
        case 2...4: return "фигуры"
        default: return "фигур"
        }
    }

    /// «Подумать»: раз за фигуру и только пока на слово не ответили
    private var thinkButton: some View {
        let isAvailable = !usedThinkThisPiece && selectedAnswer == nil && !isPaused
        return Button {
            isThinking = true
            usedThinkThisPiece = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label(isThinking ? "Фигура ждёт ответа" : "Подумать", systemImage: isThinking ? "hourglass" : "pause.circle.fill")
                .scaledFont(size: 14, weight: .bold)
                .foregroundColor(isThinking ? .orange : .indigo)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill((isThinking ? Color.orange : Color.indigo).opacity(0.12)))
        }
        .disabled(!isAvailable && !isThinking)
        .opacity(isAvailable || isThinking ? 1 : 0.4)
    }

    private func pause() {
        guard !isGameOver else { return }
        isPaused = true
    }

    /// После обычной паузы — другое слово: пока игра стояла, ответ можно было подсмотреть.
    /// Если на слово уже ответили, оно остаётся — второго ответа за фигуру нет
    private func resume() {
        isPaused = false
        lastTickTime = Date()
        if selectedAnswer == nil {
            pickRandomWord()
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
        // Фигура стоит на паузе и пока ждёт ответа — двигать её тоже нельзя
        guard !isPaused, !isThinking, !isGameOver else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x - 1, y: currentOffset.y)) {
            currentOffset.x -= 1
        }
    }
    
    private func moveRight() {
        // Фигура стоит на паузе и пока ждёт ответа — двигать её тоже нельзя
        guard !isPaused, !isThinking, !isGameOver else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if canMove(blocks: currentBlocks, offset: BlockPosition(x: currentOffset.x + 1, y: currentOffset.y)) {
            currentOffset.x += 1
        }
    }
    
    private func rotate() {
        // Фигура стоит на паузе и пока ждёт ответа — двигать её тоже нельзя
        guard !isPaused, !isThinking, !isGameOver else { return }
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
            // Четыре линии разом («тетрис») или бонус за серию ответов — очки вдвое; вместе не складываются
            score += linesCleared * 100 * (linesCleared == 4 || pieceHasBonus ? 2 : 1)
            
            dropInterval = max(0.15, 0.6 - Double(score / 300) * 0.05)
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            if let word = currentWord, word.isMistake {
                word.isMistake = false
            }
        }
    }
    
    private func spawnNewPiece() {
        let newShape = nextShape
        nextShape = TetrominoShape.allCases.randomElement() ?? .T
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
            // Новая фигура — новое слово, свой ответ и своё «Подумать»
            usedThinkThisPiece = false
            isThinking = false
            pieceHasBonus = bonusPiecesLeft > 0
            if pieceHasBonus { bonusPiecesLeft -= 1 }
            pickRandomWord()
        }
    }
    
    /// Слова для игры запросами к базе, все не читаем (10 000+ — ~2 с на iPhone 12):
    /// все ошибки из выбранных для изучения и несколько сотен случайных. Не выбрано ни одного — играем по всему словарю
    private func loadWords() {
        var scope = StudyWords.scope(studyScope)
        if StudyWords.count(scope, in: modelContext) == 0 { scope = #Predicate<Word> { _ in true } }
        let mistakes = StudyWords.fetch(StudyWords.all(scope, #Predicate<Word> { $0.isMistake }), in: modelContext)
        studyWords = mistakes + StudyWords.random(scope, limit: 400, excluding: Set(mistakes.map(\.persistentModelID)), in: modelContext)
        distractors = StudyWords.random(#Predicate<Word> { _ in true }, limit: 300, in: modelContext)
    }

    private func pickRandomWord() {
        let pool = studyWords
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
        let wrongAnswers = distractors.randomWrongAnswers(2, excluding: correctAnswer) { $0.russian }
        currentOptions = ([correctAnswer] + wrongAnswers).shuffled()
    }

    private func selectAnswer(_ answer: String) {
        guard let word = currentWord, selectedAnswer == nil else { return }
        selectedAnswer = answer
        
        let isCorrect = answer.lowercased() == word.russian.lowercased()
        
        if isCorrect {
            word.isMistake = false
            answerStreak += 1
            // Серия из 5 верных подряд: замедление на 10 с и ×2 за линии следующих 3 фигур (повторная серия — продлевает)
            if answerStreak % Self.streakForBonus == 0 {
                slowDown(by: Self.slowdownFactor, for: Self.slowdownSeconds)
                bonusPiecesLeft += Self.bonusPieces
            } else if answerStreak % Self.streakForBonus == Self.smallStreak {
                // 3 подряд — чуть медленнее на 5 с
                slowDown(by: Self.smallSlowdownFactor, for: Self.smallSlowdownSeconds)
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            answerStreak = 0
            word.isMistake = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        // Ответ дан — фигура, остановленная «Подумать», падает дальше. Подсветка ответа — до следующей фигуры
        if isThinking {
            isThinking = false
            lastTickTime = Date()
        }
    }

    /// Новое замедление не ослабляет действующее более сильное
    private func slowDown(by factor: Double, for seconds: Double) {
        let now = Date()
        if let until = speedBoostUntil, until > now, speedBoostFactor > factor { return }
        speedBoostFactor = factor
        speedBoostUntil = now.addingTimeInterval(seconds)
    }

    private func optionBackground(_ option: String, word: Word) -> Color {
        guard let selected = selectedAnswer else {
            return Color.brandFill
        }
        if option.lowercased() == word.russian.lowercased() {
            return Color.green.opacity(0.25)
        }
        if option == selected {
            return Color.red.opacity(0.25)
        }
        return Color.brandFill
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
        isPaused = false
        nextShape = TetrominoShape.allCases.randomElement() ?? .T
        answerStreak = 0
        bonusPiecesLeft = 0
        pieceHasBonus = false
        speedBoostUntil = nil
        speedBoostFactor = 1
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

/// Поле занимает всё место до низа экрана и узнаёт его размер — по нему считается сторона клетки
private struct BoardFit: ViewModifier {
    let onSize: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                // Не onGeometryChange: его замыкание iOS может вызвать не на главном потоке
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { onSize(proxy.size) }
                        .onChange(of: proxy.size) { _, size in onSize(size) }
                }
            }
    }
}

/// Следующая фигура — маленькая, в рамке 4 × 2
private struct NextPiecePreview: View {
    let shape: TetrominoShape
    private let cell: CGFloat = 8

    var body: some View {
        let blocks = shape.relativeBlocks
        let minX = blocks.map(\.x).min() ?? 0, minY = blocks.map(\.y).min() ?? 0
        let width = (blocks.map(\.x).max() ?? 0) - minX + 1, height = (blocks.map(\.y).max() ?? 0) - minY + 1
        ZStack(alignment: .topLeading) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                RoundedRectangle(cornerRadius: 2)
                    .fill(shape.color)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(block.x - minX) * (cell + 1), y: CGFloat(block.y - minY) * (cell + 1))
            }
        }
        .frame(width: CGFloat(width) * (cell + 1), height: CGFloat(height) * (cell + 1), alignment: .topLeading)
        .frame(width: 4 * (cell + 1), height: 2 * (cell + 1))
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.cardBackground))
        .accessibilityLabel("Следующая фигура")
    }
}
