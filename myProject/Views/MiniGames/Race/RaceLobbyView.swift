import SwiftUI
import SwiftData
import MultipeerConnectivity

struct RaceLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var allWords: [Word] = []
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []
    @Query private var profiles: [UserProfile]

    @StateObject private var manager = MultipeerRaceManager()
    @State private var mode: LobbyMode = .choosing
    @State private var showEmptyPoolAlert = false
    
    enum LobbyMode {
        case choosing, hosting, browsing
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch mode {
                case .choosing:
                    chooserView
                case .hosting:
                    hostView
                case .browsing:
                    browserView
                }
            }
            .padding()
            .onAppear {
                loadWords()
                manager.setPlayerName(profiles.first?.name ?? "Игрок")
            }
            .navigationTitle("Гонка слов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        manager.stop()
                        dismiss()
                    }
                }
            }
            .fullScreenCover(isPresented: $manager.raceStarted, onDismiss: {
                manager.stop()
                mode = .choosing
            }) {
                RaceGameView(manager: manager, isHost: manager.isHost)
            }
        }
    }
    
    private var chooserView: some View {
        VStack(spacing: 16) {
            Text("Нужно минимум 2 игрока на одном Wi-Fi")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Button(action: {
                mode = .hosting
                manager.startHosting()
            }) {
                Text("Создать комнату")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            
            Button(action: {
                mode = .browsing
                manager.startBrowsing()
            }) {
                Text("Найти комнату")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.brandDark)
                    .cornerRadius(14)
            }
        }
    }
    
    private var hostView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Комната создана: \(manager.myName)")
                .font(.system(size: 16, weight: .semibold))
            
            Text("Подключились: \(manager.connectedPeers.count)")
                .foregroundColor(.gray)
            
            ForEach(manager.connectedPeers, id: \.self) { peer in
                Text(peer.displayName)
            }
            
            Button(action: startRaceAsHost) {
                Text("Начать гонку")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manager.connectedPeers.isEmpty ? Color.gray.opacity(0.3) : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .alert("Недостаточно слов", isPresented: $showEmptyPoolAlert) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text("В словаре меньше 4 слов. Проверьте раздел разработчика — возможно, нужно перезагрузить словарь из JSON.")
            }
            .disabled(manager.connectedPeers.isEmpty)
        }
    }
    
    private var browserView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Поиск комнат поблизости...")
                .foregroundColor(.gray)
            
            ForEach(manager.discoveredPeers, id: \.self) { peer in
                Button(action: { manager.invite(peer: peer) }) {
                    HStack {
                        Text(peer.displayName)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            
            if !manager.connectedPeers.isEmpty {
                Text("Ждём начала гонки от хоста...")
                    .foregroundColor(.green)
            }
        }
    }
    
    private func loadWords() {
        allWords = modelContext.fetchAllWords()
        studyWords = allWords.filter { studyScope.includes($0) }
    }

    private func startRaceAsHost() {
        let generated = RaceWordGenerator.generate(from: studyWords.count >= 4 ? studyWords : allWords)
        guard !generated.isEmpty else {
            showEmptyPoolAlert = true
            return
        }
        manager.startRaceAsHost(with: generated)
    }
}
