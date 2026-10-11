import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Открыт с «Обзора» (нажатие на шапку) — нужна кнопка «‹ Обзор»
    var showsBackButton = false
    
    @Query private var profiles: [UserProfile]
    
    @State private var showSettings = false
    @State private var levelProgress: [LevelProgress] = []
    @State private var vocabularyStatus = VocabularyStatus()
    /// Вкладка под серией дней — запоминается
    @AppStorage("profile_tab") private var tab = ProfileTab.stats
    @State private var studyDays: [DailyStudy.Day] = []
    @State private var studyTotals: [FSRSRating: Int] = [:]
    @State private var introducedToday = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var streakWeek: [(date: Date, isDone: Bool)] = []
    @AppStorage(DailyNewWords.limitKey) private var newWordsPerDay = DailyNewWords.defaultLimit
    
    /// Профиль создаётся при запуске приложения; если его всё же нет — тот же единственный, а не новый
    private var profile: UserProfile {
        profiles.first ?? UserProfile.ensureSingle(in: modelContext)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Шапка: кнопки по краям, заголовок поверх — по центру экрана, сколько бы места ни заняла «‹ Обзор»
                HStack {
                    if showsBackButton {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Обзор")
                            }
                            .scaledFont(size: 17, weight: .semibold)
                            .foregroundColor(.brandDark)
                            .fixedSize()
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 14) {
                        HelpButton(topic: .profile)
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .scaledFont(size: 22)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(minHeight: 30)
                .overlay {
                    Text("Профиль")
                        .scaledFont(size: 20, weight: .bold)
                        .foregroundColor(.brandDark)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Аватар и имя
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.teal.opacity(0.15))
                            .frame(width: 90, height: 90)
                        
                        if let data = profile.avatarData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.teal)
                        }
                    }
                    
                    Text(profile.name)
                        .scaledFont(size: 24, weight: .semibold, design: .serif)
                        .foregroundColor(.brandDark)
                }
                
                DailyStreakCard(current: streak, best: bestStreak, week: streakWeek)
                    .padding(.horizontal, 20)
                
                Picker("Раздел", selection: $tab) {
                    ForEach(ProfileTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                switch tab {
                case .stats:
                    DailyGoalCard(introduced: introducedToday, compact: true)
                        .padding(.horizontal, 20)
                    VocabularyStatusCard(status: vocabularyStatus)
                        .padding(.horizontal, 20)
                    DailyStudyCard(days: studyDays, totals: studyTotals)
                        .padding(.horizontal, 20)
                case .games:
                    GameRecordsCard(tetrisHighScore: profile.tetrisHighScore)
                        .padding(.horizontal, 20)
                case .levels:
                    LevelProgressCard(progress: levelProgress)
                        .padding(.horizontal, 20)
                }
                
                Spacer().frame(height: 20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        // Тренировки идут на другой вкладке — при переходе сюда прогресс пересчитывается
        .onAppear(perform: reloadProgress)
        // Норму уменьшили ниже пройденного — сегодняшний день сразу идёт в серию
        .onChange(of: newWordsPerDay) { _, _ in reloadProgress() }
        .sheet(isPresented: $showSettings) {
            SettingsView(profile: profile)
                .appThemedColorScheme()
        }
    }
    
    private func reloadProgress() {
        (levelProgress, vocabularyStatus) = LevelProgress.countedWithStatus(in: modelContext)
        studyDays = DailyStudy.recent()
        studyTotals = DailyStudy.totals()
        introducedToday = DailyNewWords.introducedToday
        DailyStreak.update()
        streak = DailyStreak.current()
        bestStreak = DailyStreak.best
        streakWeek = DailyStreak.week()
    }
}

/// Вкладки «Профиля» под серией дней
enum ProfileTab: String, CaseIterable, Identifiable {
    case stats, games, levels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stats: return "Статистика"
        case .games: return "Игры"
        case .levels: return "Уровни"
        }
    }
}

/// «Рекорды в мини-играх»: Тетрис (очки), Гонка слов (лучшее время по режимам), Полиглот (баллы и освоенные уроки)
struct GameRecordsCard: View {
    @AppStorage(PolyglotProgress.storageKey) private var polyglot = PolyglotProgress()
    let tetrisHighScore: Int

    /// Уроков в «Полиглоте» (PolyglotView)
    private static let polyglotLessons = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Рекорды в мини-играх")
                .scaledFont(size: 20, weight: .semibold, design: .serif)
                .foregroundColor(.brandDark)

            row(icon: "gamecontroller.fill", color: .indigo, title: "Тетрис слов", subtitle: "лучший результат",
                values: tetrisHighScore > 0 ? ["\(tetrisHighScore.formatted()) \(Self.noun(tetrisHighScore, "очко", "очка", "очков"))"] : [])

            row(icon: "car.fill", color: .green, title: "Гонка слов", subtitle: "лучшее время", values: raceRecords)

            row(icon: "character.bubble.fill", color: .red, title: "Полиглот", subtitle: polyglotSubtitle,
                values: polyglot.totalPoints > 0 ? ["\(polyglot.totalPoints) \(PolyglotProgress.pointsNoun(polyglot.totalPoints))"] : [])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    /// Рекорд — у каждого режима ответа свой
    private var raceRecords: [String] {
        RaceAnswerMode.allCases.compactMap { mode in
            guard let time = RaceGhost.best(for: mode)?.last else { return nil }
            let name = mode == .choice ? "Выбор" : "Набор \(mode.title)"
            return "\(name): \(time.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "ru_RU")))) с"
        }
    }

    private var polyglotSubtitle: String {
        let mastered = (1...Self.polyglotLessons).filter { polyglot.lesson($0).level == .mastered }.count
        return "освоено уроков: \(mastered) из \(Self.polyglotLessons)"
    }

    /// Нет рекорда — «ещё не играли»
    private func row(icon: String, color: Color, title: String, subtitle: String, values: [String]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .scaledFont(size: 18)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                Text(subtitle)
                    .scaledFont(size: 13)
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if values.isEmpty {
                    Text("ещё не играли")
                        .scaledFont(size: 14)
                        .foregroundColor(.gray)
                }
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .scaledFont(size: values.count > 1 ? 14 : 16, weight: .bold, design: .rounded)
                        .foregroundColor(color)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    /// 1 очко, 2 очка, 5 очков
    private static func noun(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
        let lastTwo = count % 100, last = count % 10
        if (11...14).contains(lastTwo) { return many }
        switch last {
        case 1: return one
        case 2...4: return few
        default: return many
        }
    }
}
