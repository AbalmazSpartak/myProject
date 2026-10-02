import SwiftUI

struct MenuCardButton: View {
    let title: String
    let icon: String
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray5))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .scaledFont(size: 22, weight: .bold)
                        .foregroundColor(themeColor)
                }
                
                Text(title)
                    .scaledFont(size: 19, weight: .bold, design: .default)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                ZStack(alignment: .leading) {
                    Color(.secondarySystemBackground)
                    themeColor.frame(width: 6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
