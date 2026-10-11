import SwiftUI
import SwiftData

/// Экран гонки — с игроками рядом или в одиночку с ботом/призраком: соперники приходят из `manager`
struct RaceGameView<Manager: RaceTransport>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: Manager

    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage(RaceWordSource.storageKey) private var wordSource = "study"

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []

    @State private var players: [RacePlayer] = []
    @State private var currentIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var isLocked: Bool = false
    @State private var wrongOption: String? = nil
    @State private var raceEnded = false
    @State private var startTime = Date()
    /// Когда гонка остановилась — для «Продолжить»: время на экране итога в забег не идёт
    @State private var endedAt: Date?
    /// Свайп от левого края: экран едет за пальцем; в идущей гонке — сначала вопрос
    @State private var swipeOffset: CGFloat = 0
    @State private var isConfirmingExit = false
    /// Набор: что напечатано; совпало с ответом — слово засчитывается само
    @State private var typed = ""
    @State private var isTypedCorrect = false
    @FocusState private var isTypingFocused: Bool
    /// Онлайн: отсчёт 3-2-1 перед стартом; nil — гонка идёт
    @State private var countdown: Int?
    @State private var countdownTask: Task<Void, Never>?
    /// Онлайн: связь оборвалась посреди гонки
    @State private var isDisconnected = false
    
    private var words: [RaceWordPayload] { manager.raceWords }
    let isHost: Bool
    
    private var currentWord: RaceWordPayload? {
        guard currentIndex < words.count else { return nil }
        return words[currentIndex]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(players) { player in
                trackRow(for: player)
            }
            
            if isDisconnected {
                Label("Связь потеряна — соперники больше не видны", systemImage: "wifi.exclamationmark")
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundColor(.orange)
            }

            Spacer()
            
            if let countdown, !raceEnded {
                Text("\(countdown)")
                    .scaledFont(size: 96, weight: .bold, design: .rounded)
                    .foregroundColor(.indigo)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: countdown)
                Spacer()
            } else if let word = currentWord, !raceEnded, manager.answerMode.isTyping {
                typingArea(word)
            } else if let word = currentWord, !raceEnded {
                VStack(spacing: 16) {
                    Text(word.english)
                        .scaledFont(size: 32, weight: .semibold, design: .serif)
                    
                    VStack(spacing: 10) {
                        ForEach(word.options, id: \.self) { option in
                            Button(action: { selectAnswer(option, word: word) }) {
                                Text(option)
                                    .scaledFont(size: 16, weight: .bold)
                                    .foregroundColor(optionTextColor(option))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(optionBackground(option))
                                    .cornerRadius(12)
                            }
                            .disabled(selectedAnswer != nil || isLocked)
                        }
                    }
                }
                .padding()
            } else if raceEnded {
                finishedView
            }
        }
        .padding()
        .background(Color.brandBackground.ignoresSafeArea())
        .offset(x: swipeOffset)
        .overlay(alignment: .leading) { exitSwipeEdge }
        .alert("Выйти из гонки?", isPresented: $isConfirmingExit) {
            Button("Остаться", role: .cancel) {}
            Button("Выйти", role: .destructive) { dismiss() }
        } message: {
            Text("Забег не засчитается.")
        }
        .onAppear(perform: setupPlayers)
        .onChange(of: manager.lastMessage) { _, message in
            handleIncoming(message)
        }
        .onChange(of: manager.raceWords) { _, _ in
            resetRoundState()
        }
    }
    
    // MARK: - Набор

    private func typingArea(_ word: RaceWordPayload) -> some View {
        let mode = manager.answerMode
        return VStack(spacing: 14) {
            Text(mode.prompt(for: word))
                .scaledFont(size: 32, weight: .semibold, design: .serif)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(mode == .typeEnglish ? "Наберите по-английски" : "Наберите перевод")
                .scaledFont(size: 14)
                .foregroundColor(.gray)

            TextField(mode == .typeEnglish ? "по-английски" : "перевод", text: $typed)
                .scaledFont(size: 22, weight: .semibold)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(mode == .typeEnglish ? .asciiCapable : .default)
                .submitLabel(.next)
                .focused($isTypingFocused)
                .disabled(isLocked)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.brandFill))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isTypedCorrect ? Color.green : (isLocked ? Color.red : .clear), lineWidth: 2))
                .onChange(of: typed) { _, text in
                    // Совпало — засчитываем сразу, без «Готово»: это гонка на скорость
                    guard !isLocked, !isTypedCorrect, mode.matches(text, word: word) else { return }
                    isTypedCorrect = true
                    countCorrectAnswer()
                }

            if isLocked {
                // После пропуска — правильный ответ, пока стоим
                Text(mode == .typeEnglish ? word.english : word.correctAnswer)
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundColor(.red)
            } else {
                Button("Пропустить ›", action: skipWord)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .onAppear { isTypingFocused = true }
    }

    /// Онлайн — 3, 2, 1: слова показываются всем разом, время забега — с конца отсчёта
    private func startCountdownIfNeeded() {
        countdownTask?.cancel()
        guard manager.startsWithCountdown else {
            countdown = nil
            return
        }
        countdown = 3
        countdownTask = Task {
            for value in [2, 1] {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdown = value
            }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            countdown = nil
            startTime = Date()
            isTypingFocused = true
        }
    }

    /// Слово не засчитано: 2 секунды стоим (видно ответ), затем следующее
    private func skipWord() {
        guard !isLocked, !raceEnded else { return }
        isLocked = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            isLocked = false
            typed = ""
            if currentIndex + 1 >= words.count {
                finishRace()
            } else {
                currentIndex += 1
            }
            isTypingFocused = true
        }
    }

    /// Полоска у левого края ловит свайп «назад» — гонка открыта поверх лобби, системного свайпа здесь нет
    private var exitSwipeEdge: some View {
        Color.clear
            .frame(width: 24)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        swipeOffset = max(0, value.translation.width)
                    }
                    .onEnded { value in
                        let isExit = value.translation.width > 100 || value.predictedEndTranslation.width > 220
                        // После финиша — выходим сразу, экран уезжает с того места, где его отпустили
                        if isExit, raceEnded {
                            dismiss()
                            return
                        }
                        withAnimation(.snappy(duration: 0.25)) { swipeOffset = 0 }
                        if isExit { isConfirmingExit = true }
                    }
            )
            .ignoresSafeArea()
    }

    private func trackRow(for player: RacePlayer) -> some View {
        GeometryReader { geo in
            let progress = words.isEmpty ? 0 : CGFloat(player.correctCount) / CGFloat(words.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.brandFill).frame(height: 24)
                Image(systemName: "car.fill")
                    .foregroundColor(player.isMe ? .indigo : .gray)
                    .opacity(player.isGhost ? 0.35 : 1)
                    .offset(x: progress * (geo.size.width - 24))
            }
        }
        .frame(height: 24)
        .overlay(alignment: .trailing) {
            Text(player.hasLeft ? "\(player.name) · вышел" : player.name)
                .scaledFont(size: 11).foregroundColor(.gray).padding(.trailing, 4)
        }
        .opacity(player.hasLeft ? 0.5 : 1)
    }
    
    private var finishedView: some View {
        VStack(spacing: 16) {
            Text("Гонка окончена!")
                .scaledFont(size: 22, weight: .bold)

            if let note = manager.resultNote {
                Text(note)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.indigo)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 8) {
                ForEach(Array(rankedPlayers.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Text("\(index + 1).")
                            .scaledFont(size: 16, weight: .bold)
                        Text(player.name)
                        Spacer()
                        Text("\(player.correctCount)/\(words.count)" + (player.finishTime.map { " · " + Self.seconds($0) } ?? ""))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                }
            }
            
            if canContinue {
                Button(action: continueRace) {
                    Text("Продолжить — доработать слова")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Выйти")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandFill)
                        .foregroundColor(.brandDark)
                        .cornerRadius(14)
                }
                
                Button(action: playAgain) {
                    Text(isHost ? "Играть ещё" : "Ждём хоста...")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isHost ? Color.green : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .disabled(!isHost)
            }
            .padding(.horizontal)
        }
    }

    /// Соперник доехал первым, а слова ещё остались — можно доработать их и узнать своё время
    private var canContinue: Bool {
        manager.canContinueAfterFinish && currentWord != nil
            && players.first(where: { $0.isMe })?.finishTime == nil
    }

    private func continueRace() {
        if let endedAt { startTime += Date().timeIntervalSince(endedAt) }
        endedAt = nil
        manager.continueAfterFinish()
        raceEnded = false
    }

    /// 24,3 с
    private static func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "ru_RU"))) + " с"
    }

    private var rankedPlayers: [RacePlayer] {
        players.sorted {
            if $0.correctCount != $1.correctCount {
                return $0.correctCount > $1.correctCount
            }
            return ($0.finishTime ?? .infinity) < ($1.finishTime ?? .infinity)
        }
    }
    
    /// Слова из словаря, выбранного для гонки (RaceWordSource)
    private func loadWords() {
        studyWords = RaceWordSource(storedValue: wordSource).words(scope: studyScope, in: modelContext)
    }

    private func setupPlayers() {
        loadWords()
        players = [RacePlayer(id: manager.myName, name: manager.myName, isMe: true)] + manager.opponents
        startTime = Date()
        startCountdownIfNeeded()
    }
    
    private func resetRoundState() {
        currentIndex = 0
        selectedAnswer = nil
        wrongOption = nil
        isLocked = false
        raceEnded = false
        endedAt = nil
        typed = ""
        isTypedCorrect = false
        startTime = Date()
        startCountdownIfNeeded()
        for idx in players.indices {
            players[idx].correctCount = 0
            players[idx].finishTime = nil
        }
    }

    private func playAgain() {
        let generated = RaceWordGenerator.generate(from: studyWords)
        guard !generated.isEmpty else { return }
        manager.startRaceAsHost(with: generated, mode: manager.answerMode)
    }
    
    private func selectAnswer(_ answer: String, word: RaceWordPayload) {
        guard !raceEnded, !isLocked, selectedAnswer == nil else { return }
        
        let isCorrectTap = answer == word.correctAnswer
        
        if isCorrectTap {
            selectedAnswer = answer
            countCorrectAnswer()
        } else {
            wrongOption = answer
            isLocked = true
            
            Task {
                try? await Task.sleep(for: .seconds(1))
                wrongOption = nil
                isLocked = false
            }
        }
    }

    /// Верный ответ (нажатием или набором): +1, сообщение соперникам и через миг — следующее слово
    private func countCorrectAnswer() {
        if let idx = players.firstIndex(where: { $0.isMe }) {
            players[idx].correctCount += 1
            manager.send(RaceMessage(type: "progress", playerName: manager.myName, correctCount: players[idx].correctCount))
        }

        Task {
            try? await Task.sleep(for: .seconds(manager.answerMode.isTyping ? 0.25 : 0.4))
            selectedAnswer = nil
            typed = ""
            isTypedCorrect = false
            // Слово засчитано — дальше следующее, даже если соперник успел финишировать:
            // после «Продолжить» не должно вернуться уже отвеченное слово
            if currentIndex + 1 >= words.count {
                finishRace()
            } else {
                currentIndex += 1
            }
        }
    }
    
    private func optionBackground(_ option: String) -> Color {
        if option == wrongOption { return Color.red.opacity(0.2) }
        if option == selectedAnswer { return Color.green.opacity(0.25) }
        return Color.brandFill
    }

    private func optionTextColor(_ option: String) -> Color {
        if option == wrongOption { return .red }
        if option == selectedAnswer { return .green }
        return .primary
    }
    
    private func finishRace() {
        if let idx = players.firstIndex(where: { $0.isMe }) {
            let time = Date().timeIntervalSince(startTime)
            players[idx].finishTime = time
            manager.send(RaceMessage(type: "finished", playerName: manager.myName, finishTime: time))
        }
        raceEnded = true
    }
    
    private func handleIncoming(_ message: RaceMessage?) {
        guard let message else { return }
        switch message.type {
        case "progress":
            if let name = message.playerName, let count = message.correctCount,
               let idx = players.firstIndex(where: { $0.name == name }) {
                players[idx].correctCount = count
            }
        case "finished":
            if let name = message.playerName,
               let idx = players.firstIndex(where: { $0.name == name }) {
                // Бот и призрак присылают последний ответ вместе с финишем
                if let count = message.correctCount {
                    players[idx].correctCount = count
                }
                if let time = message.finishTime {
                    players[idx].finishTime = time
                }
                // Как только кто-то первым закончил все вопросы — гонка останавливается для всех
                raceEnded = true
                endedAt = Date()
            }
        case "left":
            if let name = message.playerName, let idx = players.firstIndex(where: { $0.name == name }) {
                players[idx].hasLeft = true
            }
        case "disconnected":
            isDisconnected = true
        default:
            break
        }
    }
}
