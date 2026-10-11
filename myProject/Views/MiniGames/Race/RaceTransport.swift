import Foundation
import Combine
@preconcurrency import MultipeerConnectivity

/// Откуда приходят ходы соперников: телефоны рядом (MultipeerRaceManager) или бот/призрак на этом телефоне
/// (SoloRaceManager). Экран гонки работает с любым — сообщения одинаковые: start, progress, finished
@MainActor
protocol RaceTransport: ObservableObject {
    var myName: String { get }
    var isHost: Bool { get }
    var opponents: [RacePlayer] { get }
    var lastMessage: RaceMessage? { get }
    var raceWords: [RaceWordPayload] { get }
    var answerMode: RaceAnswerMode { get }
    /// Строка под итогом гонки: «Быстрее рекорда на 2,4 с»; nil — нечего сказать
    var resultNote: String? { get }
    /// Соперник финишировал первым — можно доработать оставшиеся слова и узнать своё время (только в одиночку)
    var canContinueAfterFinish: Bool { get }
    func send(_ message: RaceMessage)
    func startRaceAsHost(with words: [RaceWordPayload], mode: RaceAnswerMode)
    /// «Продолжить» после финиша соперника: время на экране итога в забег не идёт
    func continueAfterFinish()
}

extension MultipeerRaceManager: RaceTransport {
    var opponents: [RacePlayer] {
        connectedPeers.map { RacePlayer(id: $0.displayName, name: $0.displayName) }
    }

    var resultNote: String? { nil }
    var canContinueAfterFinish: Bool { false }
    func continueAfterFinish() {}
}
