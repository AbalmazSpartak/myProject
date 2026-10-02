import SwiftUI

/// Конец подхода (Настройки → «Слов за подход»): итог и выбор — ещё подход или в меню
struct ApproachDoneCard: View {
    /// Например, «Верно 16 из 20»
    let summary: String
    let tint: Color
    let onContinue: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundColor(tint)

            VStack(spacing: 6) {
                Text("Подход завершён")
                    .scaledFont(size: 24, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text(summary)
                    .scaledFont(size: 16, weight: .medium, design: .rounded)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("Ещё подход")
                        .scaledFont(size: 16, weight: .bold, design: .rounded)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(tint)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                Button(action: onExit) {
                    Text("Закончить")
                        .scaledFont(size: 16, weight: .semibold, design: .rounded)
                        .foregroundColor(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
