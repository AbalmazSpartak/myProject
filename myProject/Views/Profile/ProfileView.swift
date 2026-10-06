import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var profiles: [UserProfile]
    
    @State private var showSettings = false
    @State private var levelProgress: [LevelProgress] = []
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
                // Шапка
                HStack {
                    // Профиль — вкладка внизу, «назад» не нужен; пустое место держит заголовок по центру
                    Color.clear.frame(width: 70, height: 1)
                    
                    Spacer()
                    
                    Text("Профиль")
                        .scaledFont(size: 20, weight: .bold)
                        .foregroundColor(.brandDark)
                    
                    Spacer()
                    
                    HStack(spacing: 14) {
                        HelpButton(topic: .profile)
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .scaledFont(size: 22)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 70, alignment: .trailing)
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
                
                // Рекорд Тетриса
                tetrisSectionCard(
                    title: "Тетрис слов",
                    icon: "gamecontroller.fill",
                    color: .indigo,
                    highScore: profile.tetrisHighScore
                )
                .padding(.horizontal, 20)
                
                DailyGoalCard(introduced: introducedToday)
                    .padding(.horizontal, 20)
                
                DailyStudyCard(days: studyDays, totals: studyTotals)
                    .padding(.horizontal, 20)
                
                LevelProgressCard(progress: levelProgress)
                    .padding(.horizontal, 20)
                
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
    
    // Блок рекорда Тетриса
    private func tetrisSectionCard(title: String, icon: String, color: Color, highScore: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .scaledFont(size: 18)
            }
            
            Text(title)
                .scaledFont(size: 18, weight: .bold, design: .rounded)
                .foregroundColor(.brandDark)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Рекорд")
                    .scaledFont(size: 11, weight: .medium)
                    .foregroundColor(.gray)
                Text("\(highScore) очков")
                    .scaledFont(size: 16, weight: .bold, design: .rounded)
                    .foregroundColor(.indigo)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private func reloadProgress() {
        levelProgress = LevelProgress.all(from: modelContext.fetchAllWords())
        studyDays = DailyStudy.recent()
        studyTotals = DailyStudy.totals()
        introducedToday = DailyNewWords.introducedToday
        DailyStreak.update()
        streak = DailyStreak.current()
        bestStreak = DailyStreak.best
        streakWeek = DailyStreak.week()
    }
}
