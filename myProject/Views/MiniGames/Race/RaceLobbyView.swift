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
    /// Гонка через интернет — комната по коду или случайный соперник
    @StateObject private var online = OnlineRaceManager()
    @State private var isEnteringCode = false
    @State private var joinCode = ""
    /// Случайного соперника не нашлось за `searchTimeout` — предлагаем бота
    @State private var isSearchTimedOut = false
    @State private var searchTimer: Task<Void, Never>?
    private static let searchTimeout: Duration = .seconds(45)
    @AppStorage(RaceBotLevel.storageKey) private var botLevel = RaceBotLevel.medium
    @AppStorage(RaceAnswerMode.storageKey) private var answerMode = RaceAnswerMode.choice
    /// Рекорд есть в выбранном режиме — можно гоняться с призраком
    @State private var hasGhost = RaceGhost.best(for: .choice) != nil
    @State private var mode: LobbyMode = .choosing
    @State private var showEmptyPoolAlert = false
    
    enum LobbyMode {
        case choosing, hosting, browsing, online
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
            case .online:
                onlineView
            }
        }
        .padding()
        .onAppear {
            loadWords()
            manager.setPlayerName(profiles.first?.name ?? "Игрок")
            solo.setPlayerName(profiles.first?.name ?? "")
            online.setPlayerName(profiles.first?.name ?? "Игрок")
        }
        // Ушли из лобби свайпом «назад» — закрываем соединение, как кнопкой «Закрыть»
        .onDisappear {
            if !manager.raceStarted { manager.stop() }
            if !online.raceStarted { online.stop() }
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
                    online.stop()
                    searchTimer?.cancel()
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
        .fullScreenCover(isPresented: $online.raceStarted, onDismiss: {
            online.stop()
            mode = .choosing
        }) {
            RaceGameView(manager: online, isHost: online.isHost)
        }
        // Случайный соперник вошёл в комнату — создатель начинает сам, без кнопки
        .onChange(of: online.roster) { _, roster in
            if online.isMatchmade, online.isHost, roster.count >= 2, !online.raceStarted {
                startOnlineRace()
            }
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
                onlineSection
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

    // MARK: - Онлайн

    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Онлайн".uppercased())
                .scaledFont(size: 15, weight: .bold)
                .foregroundColor(.brandDark)
            Text("Через интернет — с другом по коду комнаты или со случайным соперником")
                .scaledFont(size: 14)
                .foregroundColor(.gray)

            Button(action: findOpponent) {
                Label("Найти соперника", systemImage: "globe")
                    .scaledFont(size: 17, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            HStack(spacing: 12) {
                Button {
                    mode = .online
                    Task { await online.createRoom() }
                } label: {
                    Text("Создать комнату")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandFill)
                        .foregroundColor(.brandDark)
                        .cornerRadius(14)
                }
                Button {
                    withAnimation { isEnteringCode.toggle() }
                } label: {
                    Text("Войти по коду")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandFill)
                        .foregroundColor(.brandDark)
                        .cornerRadius(14)
                }
            }

            if isEnteringCode {
                HStack(spacing: 10) {
                    TextField("Код, например K7F2", text: $joinCode)
                        .scaledFont(size: 20, weight: .bold, design: .monospaced)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.brandFill))
                        .onChange(of: joinCode) { _, code in
                            joinCode = String(code.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(4))
                        }
                    Button("Войти") {
                        mode = .online
                        online.joinRoom(code: joinCode)
                    }
                    .scaledFont(size: 17, weight: .bold)
                    .disabled(joinCode.count != 4)
                }
            }
        }
    }

    private func findOpponent() {
        mode = .online
        isSearchTimedOut = false
        online.findOpponent()
        searchTimer?.cancel()
        searchTimer = Task {
            try? await Task.sleep(for: Self.searchTimeout)
            guard !Task.isCancelled, online.phase == .searching else { return }
            isSearchTimedOut = true
        }
    }

    private func leaveOnline() {
        searchTimer?.cancel()
        online.stop()
        isSearchTimedOut = false
        mode = .choosing
    }

    private func startOnlineRace() {
        let generated = RaceWordGenerator.generate(from: studyWords)
        guard !generated.isEmpty else {
            showEmptyPoolAlert = true
            return
        }
        online.startRaceAsHost(with: generated, mode: answerMode)
    }

    @ViewBuilder
    private var onlineView: some View {
        VStack(spacing: 18) {
            switch online.phase {
            case .idle, .connecting:
                ProgressView("Подключаемся…")
            case .searching:
                if isSearchTimedOut {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundColor(.gray)
                    Text("Никого нет онлайн")
                        .scaledFont(size: 20, weight: .semibold)
                    Text("Можно сыграть с ботом или подождать ещё")
                        .foregroundColor(.gray)
                    onlineButton("Сыграть с ботом", color: .indigo) {
                        leaveOnline()
                        startSolo(.bot(botLevel))
                    }
                    onlineButton("Искать ещё", color: .teal, action: findOpponent)
                } else {
                    ProgressView()
                    Text("Ищем соперника…")
                        .scaledFont(size: 18, weight: .semibold)
                    Text("Как только кто-то тоже нажмёт «Найти соперника», гонка начнётся сама")
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            case .inRoom(let code):
                roomView(code: code)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(message)
                    .scaledFont(size: 17, weight: .semibold)
                    .multilineTextAlignment(.center)
            }

            Button("Назад", action: leaveOnline)
                .scaledFont(size: 17, weight: .semibold)
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    @ViewBuilder
    private func roomView(code: String) -> some View {
        let others = online.roster.filter { $0 != online.myName }
        if online.isMatchmade {
            ProgressView()
            Text(others.isEmpty ? "Соперник найден, подключаемся…" : "Соперник: \(others.joined(separator: ", "))")
                .scaledFont(size: 18, weight: .semibold)
        } else {
            Text("Код комнаты")
                .scaledFont(size: 15)
                .foregroundColor(.gray)
            Text(code)
                .scaledFont(size: 48, weight: .bold, design: .monospaced)
                .foregroundColor(.brandDark)
                .textSelection(.enabled)
            if online.isHost {
                ShareLink(item: "Гонка слов: заходи в комнату \(code) — «Гонка слов» → «Войти по коду»") {
                    Label("Отправить код другу", systemImage: "square.and.arrow.up")
                        .scaledFont(size: 16, weight: .semibold)
                }
            }

            Text(others.isEmpty ? "Пока никого — ждём соперников" : "В комнате: \(others.joined(separator: ", "))")
                .foregroundColor(others.isEmpty ? .gray : .green)
                .multilineTextAlignment(.center)

            if online.isHost {
                onlineButton("Начать гонку", color: others.isEmpty ? .gray.opacity(0.4) : .green, action: startOnlineRace)
                    .disabled(others.isEmpty)
            } else {
                Text("Ждём, когда создатель начнёт гонку…")
                    .foregroundColor(.gray)
            }
        }
    }

    private func onlineButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 17, weight: .bold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
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
