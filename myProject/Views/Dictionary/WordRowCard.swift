import SwiftUI

struct WordRowCard: View {
    let word: Word
    var onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.english)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.brandDark)
                    
                    if !word.transcription.isEmpty {
                        Text(word.cefrLevel)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.indigo)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                
                Text(word.russian)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)
                
                if !word.example.isEmpty {
                    Text(word.example)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            Button(action: {
                TextToSpeechManager.shared.speak(word.english)
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            
            Button(action: onEdit) {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}
