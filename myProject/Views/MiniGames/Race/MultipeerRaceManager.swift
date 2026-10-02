import Foundation
import Combine
@preconcurrency import MultipeerConnectivity

@MainActor
final class MultipeerRaceManager: NSObject, ObservableObject {
    private let serviceType = "wl-race"
    private var myPeerID: MCPeerID

    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    @Published var isHost: Bool = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var lastMessage: RaceMessage?
    @Published var raceWords: [RaceWordPayload] = []
    @Published var raceStarted: Bool = false
    
    var myName: String { myPeerID.displayName }
    
    init(playerName: String = "Игрок") {
        myPeerID = MCPeerID(displayName: Self.uniqueDisplayName(for: playerName))
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        super.init()
        session.delegate = self
    }

    // Игроки различаются по displayName, поэтому к имени из профиля добавляется
    // короткий суффикс: иначе два "Студента" (или два "iPhone") путают прогресс
    func setPlayerName(_ name: String) {
        guard advertiser == nil, browser == nil else { return }
        session.disconnect()
        myPeerID = MCPeerID(displayName: Self.uniqueDisplayName(for: name))
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self
    }

    private static func uniqueDisplayName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Лимит MCPeerID — 63 байта UTF-8, кириллица занимает по 2 байта на символ
        let base = trimmed.isEmpty ? "Игрок" : String(trimmed.prefix(20))
        return "\(base) #\(UUID().uuidString.prefix(4))"
    }
    
    // MARK: - Хост
    func startHosting() {
        isHost = true
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }
    
    // MARK: - Присоединение
    func startBrowsing() {
        isHost = false
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    func invite(peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }
    
    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
    }
    
    // MARK: - Отправка сообщений
    func send(_ message: RaceMessage) {
        sendOnce(message)
        // Повторная отправка — защита от случаев, когда канал ещё не готов
        // сразу после подключения пира и первая посылка молча теряется
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.3))
            self?.sendOnce(message)
            try? await Task.sleep(for: .seconds(0.5))
            self?.sendOnce(message)
        }
    }
    
    func startRaceAsHost(with words: [RaceWordPayload]) {
        raceWords = words
        raceStarted = true
        send(RaceMessage(type: "start", words: words))
    }

    private func sendOnce(_ message: RaceMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension MultipeerRaceManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
            case .notConnected:
                self.connectedPeers.removeAll { $0 == peerID }
            default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            guard let message = try? JSONDecoder().decode(RaceMessage.self, from: data) else { return }
            self.lastMessage = message
            if message.type == "start", let words = message.words {
                self.raceWords = words
                self.raceStarted = true
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerRaceManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // MultipeerConnectivity разрешает вызвать обработчик из любого потока, но не помечает его Sendable
        nonisolated(unsafe) let accept = invitationHandler
        Task { @MainActor in
            accept(true, self.session)
        }
    }
}

extension MultipeerRaceManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
}
