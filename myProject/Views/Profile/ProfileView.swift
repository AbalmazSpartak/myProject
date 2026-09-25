import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var profiles: [UserProfile]
    @Query private var allWords: [Word]
    
    @State private var showSettings = false
    
    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        } else {
            let newProfile = UserProfile()
            modelContext.insert(newProfile)
            return newProfile
        }
    }
    
    private var winRate: Int {
        guard profile.totalAnswers > 0 else { return 0 }
        return Int((Double(profile.correctAnswers) / Double(profile.totalAnswers)) * 100)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Шапка
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Меню") }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.teal)
                    }
                    
                    Spacer()
                    
                    Text("Профиль")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.brandDark)
                    
                    Spacer()
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                }
                
                // Общая сводка
                HStack(spacing: 12) {
                    summaryCard(title: "Слов в словаре", value: "\(allWords.count)", icon: "book.closed.fill", color: .orange)
                    summaryCard(title: "Общая точность", value: "\(winRate)%", icon: "target", color: .green)
                    summaryCard(title: "Всего ответов", value: "\(profile.totalAnswers)", icon: "checkmark.seal.fill", color: .purple)
                }
                .padding(.horizontal, 20)
                
                // Секция 1: Карточки с вводом
                sectionCard(
                    title: "Карточки с вводом",
                    icon: "keyboard.fill",
                    color: .blue,
                    enRuCorrect: profile.flashcardsEnRuCorrect,
                    enRuTotal: profile.flashcardsEnRuTotal,
                    ruEnCorrect: profile.flashcardsRuEnCorrect,
                    ruEnTotal: profile.flashcardsRuEnTotal
                )
                .padding(.horizontal, 20)
                
                // Секция 2: Викторина
                sectionCard(
                    title: "Викторина",
                    icon: "checkmark.seal.fill",
                    color: .purple,
                    enRuCorrect: profile.quizEnRuCorrect,
                    enRuTotal: profile.quizEnRuTotal,
                    ruEnCorrect: profile.quizRuEnCorrect,
                    ruEnTotal: profile.quizRuEnTotal
                )
                .padding(.horizontal, 20)
                
                // Секция 3: Тетрис слов (Рекорд)
                tetrisSectionCard(
                    title: "Тетрис слов",
                    icon: "gamecontroller.fill",
                    color: .indigo,
                    highScore: profile.tetrisHighScore
                )
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 20)
            }
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView(profile: profile)
        }
    }
    
    // Карточка общей краткой статистики
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.brandDark)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    // Блок детализированной статистики раздела
    private func sectionCard(
        title: String,
        icon: String,
        color: Color,
        enRuCorrect: Int,
        enRuTotal: Int,
        ruEnCorrect: Int,
        ruEnTotal: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18))
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.brandDark)
            }
            
            Divider()
            
            detailRow(label: "Английский ➔ Русский", correct: enRuCorrect, total: enRuTotal)
            detailRow(label: "Русский ➔ Английский", correct: ruEnCorrect, total: ruEnTotal)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                    .font(.system(size: 18))
            }
            
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.brandDark)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Рекорд")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Text("\(highScore) очков")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    // Строка отдельного языкового направления
    private func detailRow(label: String, correct: Int, total: Int) -> some View {
        let percent = total > 0 ? Int((Double(correct) / Double(total)) * 100) : 0
        
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.brandDark)
                Text("\(correct) из \(total) ответов")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(percent)%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(total > 0 ? (percent >= 70 ? .green : .orange) : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    (total > 0 ? (percent >= 70 ? Color.green : Color.orange) : Color.gray)
                        .opacity(0.12)
                )
                .cornerRadius(8)
        }
    }
}
