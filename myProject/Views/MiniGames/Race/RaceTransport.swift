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
    /// Строка под итогом гонки: «Быстрее рекорда на 2,4 с»; nil — нечего сказать
    var resultNote: String? { get }
    func send(_ message: RaceMessage)
    func startRaceAsHost(with words: [RaceWordPayload])
}

extension MultipeerRaceManager: RaceTransport {
    var opponents: [RacePlayer] {
        connectedPeers.map { RacePlayer(id: $0.displayName, name: $0.displayName) }
    }

    var resultNote: String? { nil }
}
