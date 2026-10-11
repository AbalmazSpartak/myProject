import SwiftUI
import SwiftData
import MultipeerConnectivity

struct RaceLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []
    @Query private var profiles: [UserProfile]

    @StateObject private var manager = MultipeerRaceManager()
    /// Гонка в одиночку — с ботом или призраком
    @StateObject private var solo = SoloRaceManager()
    @AppStorage(RaceBotLevel.storageKey) private var botLevel = RaceBotLevel.medium
    @State private var hasGhost = RaceGhost.best != nil
    @State private var mode: LobbyMode = .choosing
    @State private var showEmptyPoolAlert = false
    
    enum LobbyMode {
        case choosing, hosting, browsing
    }
    
    var body: some View {
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
            solo.setPlayerName(profiles.first?.name ?? "")
        }
        // Ушли из лобби свайпом «назад» — закрываем соединение, как кнопкой «Закрыть»
        .onDisappear {
            if !manager.raceStarted { manager.stop() }
        }
        .navigationTitle("Гонка слов")
        .navigationBarTitleDisplayMode(.inline)
        // Открывается переходом из меню: полоса навигации нужна для заголовка и кнопок
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HelpButton(topic: .race)
            }
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
        .fullScreenCover(isPresented: $solo.raceStarted, onDismiss: {
            solo.stop()
            // Рекорд мог появиться — кнопка призрака станет доступна
            hasGhost = RaceGhost.best != nil
        }) {
            RaceGameView(manager: solo, isHost: true)
        }
    }
    
    private var chooserView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                soloSection
                nearbySection
            }
        }
    }

    // MARK: - Один

    private var soloSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Один".uppercased())
                .scaledFont(size: 15, weight: .bold)
                .foregroundColor(.brandDark)

            Picker("Уровень бота", selection: $botLevel) {
                ForEach(RaceBotLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)

            Button { startSolo(.bot(botLevel)) } label: {
                Label("Гонка с ботом", systemImage: "cpu")
                    .scaledFont(size: 17, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            Button { startSolo(.ghost) } label: {
                Label("Гонка с призраком", systemImage: "car.rear.and.tire.marks")
                    .scaledFont(size: 17, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandFill)
                    .foregroundColor(.brandDark)
                    .cornerRadius(14)
            }
            .disabled(!hasGhost)
            .opacity(hasGhost ? 1 : 0.5)

            Text(hasGhost
                 ? "Призрак едет точно как вы в лучшей гонке. Обгоните — и он станет новым рекордом."
                 : "Сначала пройдите гонку до конца — например, с ботом. Тогда появится призрак вашего рекорда.")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
    }

    private func startSolo(_ opponent: SoloRaceManager.Opponent) {
        let generated = RaceWordGenerator.generate(from: studyWords)
        guard !generated.isEmpty else {
            showEmptyPoolAlert = true
            return
        }
        solo.start(against: opponent, words: generated)
    }

    // MARK: - Рядом

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("С друзьями рядом".uppercased())
                .scaledFont(size: 15, weight: .bold)
                .foregroundColor(.brandDark)
            Text("Нужно минимум 2 игрока на одном Wi-Fi")
                .scaledFont(size: 14)
                .foregroundColor(.gray)
            
            Button(action: {
                mode = .hosting
                manager.startHosting()
            }) {
                Text("Создать комнату")
                    .scaledFont(size: 17, weight: .bold)
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
                    .scaledFont(size: 17, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandFill)
                    .foregroundColor(.brandDark)
                    .cornerRadius(14)
            }
        }
        .alert("Недостаточно слов", isPresented: $showEmptyPoolAlert) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text("В словаре меньше 4 слов — выберите больше слов для изучения в настройках.")
        }
    }
    
    private var hostView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Комната создана: \(manager.myName)")
                .scaledFont(size: 16, weight: .semibold)
            
            Text("Подключились: \(manager.connectedPeers.count)")
                .foregroundColor(.gray)
            
            ForEach(manager.connectedPeers, id: \.self) { peer in
                Text(peer.displayName)
            }
            
            Button(action: startRaceAsHost) {
                Text("Начать гонку")
                    .scaledFont(size: 17, weight: .bold)
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
                    .background(Color.brandFill)
                    .cornerRadius(12)
                }
            }
            
            if !manager.connectedPeers.isEmpty {
                Text("Ждём начала гонки от хоста...")
                    .foregroundColor(.green)
            }
        }
    }
    
    /// Слова для гонки запросом к базе — все не читаем (10 000+ — ~2 с на iPhone 12).
    /// Меньше четырёх выбранных для изучения — берём из всего словаря
    private func loadWords() {
        studyWords = StudyWords.random(StudyWords.scope(studyScope), limit: 200, in: modelContext)
        if studyWords.count < 4 {
            studyWords = StudyWords.random(#Predicate<Word> { _ in true }, limit: 200, in: modelContext)
        }
    }

    private func startRaceAsHost() {
        let generated = RaceWordGenerator.generate(from: studyWords)
        guard !generated.isEmpty else {
            showEmptyPoolAlert = true
            return
        }
        manager.startRaceAsHost(with: generated)
    }
}
