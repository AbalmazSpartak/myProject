import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showSettings = false
    @Query private var profiles: [UserProfile]
    @Query private var allWords: [Word]
    
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
                
                // Кнопка настроек
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .frame(width: 70, alignment: .trailing) // Оставляем ширину 70 для баланса
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Аватар и имя
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    // Если фото есть — отображаем его, иначе системную иконку
                    if let data = profile.avatarData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.teal)
                    }
                }
                
                Text(profile.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.brandDark)
            }
            .padding(.top, 20)
            
            // Карточки статистики
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    statCard(title: "Слов в словаре", value: "\(allWords.count)", icon: "book.closed.fill", color: .orange)
                    statCard(title: "Точность", value: "\(winRate)%", icon: "target", color: .green)
                }
                statCard(title: "Пройдено тестов", value: "\(profile.totalAnswers)", icon: "checkmark.seal.fill", color: .purple)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(Color.brandBackground.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView(profile: profile)
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
