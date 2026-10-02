import SwiftUI
import SwiftData
import MultipeerConnectivity

struct RaceGameView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: MultipeerRaceManager

    @Environment(\.modelContext) private var modelContext
    @State private var allWords: [Word] = []
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []

    @State private var players: [RacePlayer] = []
    @State private var currentIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var isLocked: Bool = false
    @State private var wrongOption: String? = nil
    @State private var raceEnded = false
    @State private var startTime = Date()
    
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
            
            Spacer()
            
            if let word = currentWord, !raceEnded {
                VStack(spacing: 16) {
                    Text(word.english)
                        .scaledFont(size: 32, weight: .bold, design: .rounded)
                    
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
        .onAppear(perform: setupPlayers)
        .onChange(of: manager.lastMessage) { _, message in
            handleIncoming(message)
        }
        .onChange(of: manager.raceWords) { _, _ in
            resetRoundState()
        }
    }
    
    private func trackRow(for player: RacePlayer) -> some View {
        GeometryReader { geo in
            let progress = words.isEmpty ? 0 : CGFloat(player.correctCount) / CGFloat(words.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 24)
                Image(systemName: "car.fill")
                    .foregroundColor(player.isMe ? .indigo : .gray)
                    .offset(x: progress * (geo.size.width - 24))
            }
        }
        .frame(height: 24)
        .overlay(alignment: .trailing) {
            Text(player.name).scaledFont(size: 11).foregroundColor(.gray).padding(.trailing, 4)
        }
    }
    
    private var finishedView: some View {
        VStack(spacing: 16) {
            Text("Гонка окончена!")
                .scaledFont(size: 22, weight: .bold)
            
            VStack(spacing: 8) {
                ForEach(Array(rankedPlayers.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Text("\(index + 1).")
                            .scaledFont(size: 16, weight: .bold)
                        Text(player.name)
                        Spacer()
                        Text("\(player.correctCount)/\(words.count)")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Выйти")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
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

    private var rankedPlayers: [RacePlayer] {
        players.sorted {
            if $0.correctCount != $1.correctCount {
                return $0.correctCount > $1.correctCount
            }
            return ($0.finishTime ?? .infinity) < ($1.finishTime ?? .infinity)
        }
    }
    
    private func loadWords() {
        allWords = modelContext.fetchAllWords()
        studyWords = allWords.filter { studyScope.includes($0) }
    }

    private func setupPlayers() {
        loadWords()
        var initial = [RacePlayer(id: manager.myName, name: manager.myName, isMe: true)]
        for peer in manager.connectedPeers {
            initial.append(RacePlayer(id: peer.displayName, name: peer.displayName))
        }
        players = initial
        startTime = Date()
    }
    
    private func resetRoundState() {
        currentIndex = 0
        selectedAnswer = nil
        wrongOption = nil
        isLocked = false
        raceEnded = false
        startTime = Date()
        for idx in players.indices {
            players[idx].correctCount = 0
            players[idx].finishTime = nil
        }
    }

    private func playAgain() {
        let generated = RaceWordGenerator.generate(from: studyWords.count >= 4 ? studyWords : allWords)
        guard !generated.isEmpty else { return }
        manager.startRaceAsHost(with: generated)
    }
    
    private func selectAnswer(_ answer: String, word: RaceWordPayload) {
        guard !raceEnded, !isLocked, selectedAnswer == nil else { return }
        
        let isCorrectTap = answer == word.correctAnswer
        
        if isCorrectTap {
            selectedAnswer = answer
            if let idx = players.firstIndex(where: { $0.isMe }) {
                players[idx].correctCount += 1
                manager.send(RaceMessage(type: "progress", playerName: manager.myName, correctCount: players[idx].correctCount))
            }
            
            Task {
                try? await Task.sleep(for: .seconds(0.4))
                selectedAnswer = nil
                if currentIndex + 1 >= words.count {
                    finishRace()
                } else if !raceEnded {
                    currentIndex += 1
                }
            }
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
    
    private func optionBackground(_ option: String) -> Color {
        if option == wrongOption { return Color.red.opacity(0.2) }
        if option == selectedAnswer { return Color.green.opacity(0.25) }
        return Color(.systemGray5)
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
                if let time = message.finishTime {
                    players[idx].finishTime = time
                }
                // Как только кто-то первым закончил все вопросы — гонка останавливается для всех
                raceEnded = true
            }
        default:
            break
        }
    }
}
