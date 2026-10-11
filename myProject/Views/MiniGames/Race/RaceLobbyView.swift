import SwiftUI
import SwiftData
import MultipeerConnectivity

struct RaceLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StudyScope.storageKey) private var studyScope = StudyScope()
    @AppStorage(RaceWordSource.storageKey) private var wordSource = "study"
    @State private var isChoosingWords = false

    /// Слова из словарей, выбранных в настройках
    @State private var studyWords: [Word] = []
    @Query private var profiles: [UserProfile]

    @StateObject private var manager = MultipeerRaceManager()
    /// Гонка в одиночку — с ботом или призраком
    @StateObject private var solo = SoloRaceManager()
    @AppStorage(RaceBotLevel.storageKey) private var botLevel = RaceBotLevel.medium
    @AppStorage(RaceAnswerMode.storageKey) private var answerMode = RaceAnswerMode.choice
    /// Рекорд есть в выбранном режиме — можно гоняться с призраком
    @State private var hasGhost = RaceGhost.best(for: .choice) != nil
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
            hasGhost = RaceGhost.best(for: answerMode) != nil
        }) {
            RaceGameView(manager: solo, isHost: true)
        }
    }
    
    private var chooserView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                wordSourceRow
                answerModeRow
                soloSection
                nearbySection
            }
        }
    }

    // MARK: - Слова

    /// «Слова: …» — из какого словаря гонка, и в одиночку, и в комнате
    private var wordSourceRow: some View {
        Button { isChoosingWords = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .foregroundColor(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Слова для гонки")
                        .scaledFont(size: 13)
                        .foregroundColor(.gray)
                    Text(RaceWordSource(storedValue: wordSource).title(in: modelContext))
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundColor(.brandDark)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(14)
            .background(Color.brandFill)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isChoosingWords) {
            RaceWordSourcePicker(selection: $wordSource)
                .appThemedColorScheme()
        }
        .onChange(of: wordSource) { _, _ in loadWords() }
    }

    // MARK: - Как отвечать

    /// «Выбор» или «Набор» и, для набора, направление. В комнате режим задаёт её создатель
    private var answerModeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ответ".uppercased())
                .scaledFont(size: 15, weight: .bold)
                .foregroundColor(.brandDark)
            Picker("Ответ", selection: Binding(
                get: { answerMode.isTyping },
                set: { answerMode = $0 ? (answerMode.isTyping ? answerMode : .typeEnglish) : .choice }
            )) {
                Text("Выбор").tag(false)
                Text("Набор").tag(true)
            }
            .pickerStyle(.segmented)
            if answerMode.isTyping {
                Picker("Направление", selection: $answerMode) {
                    Text(RaceAnswerMode.typeEnglish.title).tag(RaceAnswerMode.typeEnglish)
                    Text(RaceAnswerMode.typeRussian.title).tag(RaceAnswerMode.typeRussian)
                }
                .pickerStyle(.segmented)
            }
            Text(answerMode.isTyping
                 ? "Наберите слово — засчитывается, как только совпало. Регистр и ё/е не важны."
                 : "Нажмите на правильный перевод из трёх.")
                .scaledFont(size: 13)
                .foregroundColor(.gray)
        }
        .onChange(of: answerMode) { _, mode in hasGhost = RaceGhost.best(for: mode) != nil }
        .onAppear { hasGhost = RaceGhost.best(for: answerMode) != nil }
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
                 ? "Призрак едет точно как вы в лучшей гонке этого режима. Обгоните — и он станет новым рекордом."
                 : "Сначала пройдите гонку в этом режиме до конца — например, с ботом. Тогда появится призрак вашего рекорда.")
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
        solo.start(against: opponent, words: generated, mode: answerMode)
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
    
    /// Слова из словаря, выбранного для гонки (RaceWordSource)
    private func loadWords() {
        studyWords = RaceWordSource(storedValue: wordSource).words(scope: studyScope, in: modelContext)
    }

    private func startRaceAsHost() {
        let generated = RaceWordGenerator.generate(from: studyWords)
        guard !generated.isEmpty else {
            showEmptyPoolAlert = true
            return
        }
        manager.startRaceAsHost(with: generated, mode: answerMode)
    }
}
