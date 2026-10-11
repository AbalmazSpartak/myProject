import Foundation
import Combine

/// Гонка через интернет: комната по коду или случайный соперник. Сервер — Cloudflare Worker (server/word-race):
/// он только пересылает те же сообщения start / progress / finished, что и игра рядом, и присылает список игроков
@MainActor
final class OnlineRaceManager: ObservableObject, RaceTransport {
    static let baseURL = URL(string: "https://word-race.abalmazspartak.workers.dev")!

    enum Phase: Equatable {
        case idle
        /// Ищем случайного соперника
        case searching
        case connecting
        case inRoom(code: String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// Все в комнате, и я тоже
    @Published private(set) var roster: [String] = []
    @Published var lastMessage: RaceMessage?
    @Published var raceWords: [RaceWordPayload] = []
    @Published var raceStarted = false
    @Published private(set) var answerMode: RaceAnswerMode = .choice
    @Published private(set) var isHost = false
    /// Комнату подобрал сервер — создатель начинает гонку сам, как только соперник вошёл
    @Published private(set) var isMatchmade = false

    private(set) var myName = "Игрок"
    private var socket: URLSessionWebSocketTask?
    private var matchSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    var opponents: [RacePlayer] {
        roster.filter { $0 != myName }.map { RacePlayer(id: $0, name: $0) }
    }

    var resultNote: String? { nil }
    var canContinueAfterFinish: Bool { false }
    var startsWithCountdown: Bool { true }
    func continueAfterFinish() {}

    /// Как у игры рядом: короткий суффикс, чтобы два «Студента» не путались
    func setPlayerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Игрок" : String(trimmed.prefix(20))
        myName = "\(base) #\(UUID().uuidString.prefix(4))"
    }

    // MARK: - Комната

    func createRoom() async {
        phase = .connecting
        var request = URLRequest(url: Self.baseURL.appending(path: "room"))
        request.httpMethod = "POST"
        struct Created: Decodable { let code: String }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let created = try? JSONDecoder().decode(Created.self, from: data) else {
            phase = .failed("Нет связи с сервером. Проверьте интернет.")
            return
        }
        connect(code: created.code, asHost: true)
    }

    func joinRoom(code: String) {
        let cleaned = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard cleaned.count == 4 else {
            phase = .failed("Код — 4 символа, например K7F2")
            return
        }
        connect(code: cleaned, asHost: false)
    }

    private func connect(code: String, asHost: Bool) {
        closeSockets()
        isHost = asHost
        roster = []
        var components = URLComponents(url: Self.webSocketURL.appending(path: "room/\(code)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "name", value: myName)]
        if asHost { components.queryItems?.append(URLQueryItem(name: "role", value: "host")) }
        let task = URLSession.shared.webSocketTask(with: components.url!)
        socket = task
        task.resume()
        phase = .inRoom(code: code)
        receiveTask = Task { [weak self] in await self?.receive(from: task) }
        // Без сообщений соединение через ~100 с закрывается — пинг каждые 25 с
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                guard !Task.isCancelled else { return }
                self?.socket?.sendPing { _ in }
            }
        }
    }

    // MARK: - Случайный соперник

    func findOpponent() {
        closeSockets()
        isMatchmade = false
        phase = .searching
        var components = URLComponents(url: Self.webSocketURL.appending(path: "match"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "name", value: myName)]
        let task = URLSession.shared.webSocketTask(with: components.url!)
        matchSocket = task
        task.resume()
        receiveTask = Task { [weak self] in
            guard let message = try? await task.receive(), let self else { return }
            guard case .string(let text) = message,
                  let matched = try? JSONDecoder().decode(RaceMessage.self, from: Data(text.utf8)),
                  matched.type == "matched", let code = matched.code else {
                if self.phase == .searching { self.phase = .failed("Нет связи с сервером. Проверьте интернет.") }
                return
            }
            task.cancel(with: .normalClosure, reason: nil)
            self.matchSocket = nil
            self.isMatchmade = true
            self.connect(code: code, asHost: matched.role == "host")
        }
    }

    // MARK: - Ходы

    func send(_ message: RaceMessage) {
        guard let socket, let data = try? JSONEncoder().encode(message) else { return }
        socket.send(.string(String(decoding: data, as: UTF8.self))) { _ in }
    }

    func startRaceAsHost(with words: [RaceWordPayload], mode: RaceAnswerMode) {
        answerMode = mode
        raceWords = words
        raceStarted = true
        send(RaceMessage(type: "start", words: words, mode: mode.rawValue))
    }

    func stop() {
        closeSockets()
        phase = .idle
        roster = []
        isMatchmade = false
        raceStarted = false
    }

    private func closeSockets() {
        receiveTask?.cancel()
        pingTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        matchSocket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        matchSocket = nil
    }

    private func receive(from task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            guard let message = try? await task.receive() else {
                // Соединение оборвалось само (не мы закрыли)
                guard socket === task else { return }
                if raceStarted {
                    lastMessage = RaceMessage(type: "disconnected")
                } else if case .inRoom = phase {
                    phase = .failed("Связь с комнатой потеряна. Проверьте интернет.")
                }
                return
            }
            guard case .string(let text) = message,
                  let decoded = try? JSONDecoder().decode(RaceMessage.self, from: Data(text.utf8)) else { continue }
            handle(decoded)
        }
    }

    private func handle(_ message: RaceMessage) {
        switch message.type {
        case "roster":
            roster = message.players ?? []
        case "start":
            // Режим — до слов: экран гонки перестраивается по приходу слов
            answerMode = message.mode.flatMap(RaceAnswerMode.init(rawValue:)) ?? .choice
            raceWords = message.words ?? []
            raceStarted = true
        case "error", "closed":
            if raceStarted {
                lastMessage = message
            } else {
                closeSockets()
                phase = .failed(message.error ?? "Комната закрыта")
            }
        default:
            lastMessage = message
        }
    }

    private static var webSocketURL: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = "wss"
        return components.url!
    }
}
