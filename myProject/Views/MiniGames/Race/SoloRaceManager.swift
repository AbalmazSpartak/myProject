import Foundation
import Combine

/// Уровень бота: средняя пауза на слово и доля ошибок (после ошибки — секунда блокировки, как у игрока)
enum RaceBotLevel: String, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Лёгкий"
        case .medium: return "Средний"
        case .hard: return "Сложный"
        }
    }

    var secondsPerWord: Double {
        switch self {
        case .easy: return 3.5
        case .medium: return 2.5
        case .hard: return 1.6
        }
    }

    /// Набор: средняя «печать» слова из ~6 букв
    var typingSecondsPerWord: Double {
        switch self {
        case .easy: return 7
        case .medium: return 5
        case .hard: return 3.5
        }
    }

    var mistakeRate: Double {
        switch self {
        case .easy: return 0.2
        case .medium: return 0.1
        case .hard: return 0.05
        }
    }

    static let storageKey = "race_bot_level"
}

/// Лучшая своя гонка — моменты верных ответов от старта, в секундах. По ней едет призрак.
/// У каждого режима ответа свой рекорд: набор медленнее выбора, сравнивать их нечестно
enum RaceGhost {
    static let storageKey = "race_ghost_best"

    /// «Выбор» — прежний ключ: рекорды из прошлых версий остаются
    static func key(for mode: RaceAnswerMode) -> String {
        mode == .choice ? storageKey : "\(storageKey).\(mode.rawValue)"
    }

    static var allKeys: [String] { RaceAnswerMode.allCases.map(key(for:)) }

    static func best(for mode: RaceAnswerMode) -> [Double]? {
        guard let data = UserDefaults.standard.data(forKey: key(for: mode)),
              let times = try? JSONDecoder().decode([Double].self, from: data), !times.isEmpty else { return nil }
        return times
    }

    static func save(_ times: [Double], for mode: RaceAnswerMode) {
        guard let data = try? JSONEncoder().encode(times) else { return }
        UserDefaults.standard.set(data, forKey: key(for: mode))
    }
}

/// Гонка в одиночку: соперник — бот или призрак лучшей своей гонки. Ходы соперника приходят теми же
/// сообщениями progress/finished по расписанию, поэтому экран гонки тот же, что и для игры рядом
@MainActor
final class SoloRaceManager: ObservableObject, RaceTransport {
    enum Opponent: Equatable {
        case bot(RaceBotLevel)
        case ghost
    }

    @Published var lastMessage: RaceMessage?
    @Published var raceWords: [RaceWordPayload] = []
    @Published var raceStarted = false
    @Published private(set) var resultNote: String?
    @Published private(set) var answerMode: RaceAnswerMode = .choice

    let isHost = true
    private(set) var myName = "Вы"
    private(set) var opponent: Opponent = .bot(.medium)

    private var opponentTask: Task<Void, Never>?
    private var startDate = Date()
    /// Моменты своих верных ответов в этой гонке
    private var myTimes: [Double] = []
    /// Рекорд на момент старта — с ним сравниваем
    private var bestAtStart: [Double]?
    private var opponentFinished = false
    /// Когда соперник финишировал — с этого момента до «Продолжить» время забега стоит
    private var opponentFinishedAt: Date?

    var canContinueAfterFinish: Bool { true }
    var startsWithCountdown: Bool { false }

    var opponents: [RacePlayer] {
        [RacePlayer(id: opponentName, name: opponentName, isGhost: opponent == .ghost)]
    }

    private var opponentName: String {
        switch opponent {
        case .bot(let level): return "Бот · \(level.title)"
        case .ghost: return "Призрак"
        }
    }

    func setPlayerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        myName = trimmed.isEmpty ? "Вы" : trimmed
    }

    func start(against opponent: Opponent, words: [RaceWordPayload], mode: RaceAnswerMode) {
        self.opponent = opponent
        startRaceAsHost(with: words, mode: mode)
    }

    func startRaceAsHost(with words: [RaceWordPayload], mode: RaceAnswerMode) {
        opponentTask?.cancel()
        answerMode = mode
        raceWords = words
        resultNote = nil
        myTimes = []
        opponentFinished = false
        opponentFinishedAt = nil
        bestAtStart = RaceGhost.best(for: mode)
        startDate = Date()
        raceStarted = true

        let schedule = makeSchedule(for: words)
        let name = opponentName
        opponentTask = Task { [weak self] in
            for (index, time) in schedule.enumerated() {
                guard let self else { return }
                let wait = time - Date().timeIntervalSince(self.startDate)
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                guard !Task.isCancelled else { return }
                if index == schedule.count - 1 {
                    // Последний ответ и финиш — одним сообщением: два подряд экран может не успеть различить
                    self.opponentFinished = true
                    self.opponentFinishedAt = Date()
                    self.lastMessage = RaceMessage(type: "finished", playerName: name, correctCount: index + 1, finishTime: time)
                    self.noteOpponentWon(time)
                } else {
                    self.lastMessage = RaceMessage(type: "progress", playerName: name, correctCount: index + 1)
                }
            }
        }
    }

    /// Свои ходы: запоминаем моменты ответов; финиш — останавливаем соперника и сравниваем с рекордом
    func send(_ message: RaceMessage) {
        guard message.playerName == myName else { return }
        switch message.type {
        case "progress":
            myTimes.append(Date().timeIntervalSince(startDate))
        case "finished":
            opponentTask?.cancel()
            finishMine(message.finishTime ?? Date().timeIntervalSince(startDate))
        default:
            break
        }
    }

    func continueAfterFinish() {
        if let finishedAt = opponentFinishedAt {
            startDate += Date().timeIntervalSince(finishedAt)
            opponentFinishedAt = nil
        }
        resultNote = nil
    }

    func stop() {
        opponentTask?.cancel()
        opponentTask = nil
        raceStarted = false
    }

    // MARK: - Расписание соперника

    private func makeSchedule(for words: [RaceWordPayload]) -> [Double] {
        switch opponent {
        case .ghost:
            // Призрак едет точно как в рекорде; слов в гонке бывает меньше — берём начало
            return Array((bestAtStart ?? []).prefix(words.count))
        case .bot(let level):
            var time = 0.0
            return words.map { word in
                // Пауза каждый раз немного разная, иногда — ошибка: секунда блокировки и подумать ещё.
                // В наборе — дольше, и длинное слово «печатается» дольше короткого
                let base = answerMode.isTyping
                    ? level.typingSecondsPerWord * (0.6 + Double(answerMode.answerLength(for: word)) / 15)
                    : level.secondsPerWord
                time += base * Double.random(in: 0.7...1.3)
                if Double.random(in: 0..<1) < level.mistakeRate {
                    time += 1 + base * 0.5
                }
                return time
            }
        }
    }

    // MARK: - Итог и рекорд

    private func finishMine(_ time: Double) {
        let completed = myTimes.count == raceWords.count && !raceWords.isEmpty
        guard completed else { return }
        let previous = bestAtStart?.last
        // Рекорд — только полная гонка из 10 слов: с короткой сравнивать нечестно
        let isFullRace = raceWords.count >= (bestAtStart?.count ?? raceWords.count)
        if isFullRace, previous.map({ time < $0 }) ?? true {
            RaceGhost.save(myTimes, for: answerMode)
        }
        switch (opponent, previous) {
        case (.ghost, let best?) where opponentFinished:
            resultNote = "Ваше время: \(Self.seconds(time)) — призрак быстрее на \(Self.seconds(time - best))"
        case (.ghost, let best?):
            resultNote = "Быстрее рекорда на \(Self.seconds(best - time)) — теперь призрак едет так"
        case (_, let best?) where time < best:
            resultNote = "Новый рекорд: \(Self.seconds(time)) (был \(Self.seconds(best)))"
        case (_, nil):
            resultNote = "Первый рекорд: \(Self.seconds(time)) — теперь можно гоняться с призраком"
        default:
            resultNote = "Ваше время: \(Self.seconds(time))"
        }
    }

    private func noteOpponentWon(_ time: Double) {
        if opponent == .ghost {
            resultNote = "Призрак быстрее — рекорд \(Self.seconds(time)). Попробуйте ещё раз"
        }
    }

    /// 24,3 с
    private static func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "ru_RU"))) + " с"
    }
}
