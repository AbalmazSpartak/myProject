import SwiftUI

// Загружает картинку к слову и сохраняет её в модель, чтобы не качать повторно
@MainActor
enum WordImageLoader {
    static func loadIfNeeded(_ word: Word) async {
        guard word.imageData == nil, !word.isImageHidden, !word.imageNotFound else { return }
        await load(word)
    }

    static func loadNext(_ word: Word) async {
        word.imageVariant += 1
        await load(word)
    }

    private static func load(_ word: Word) async {
        switch await WordImageService.fetchImage(for: word.english, variant: word.imageVariant) {
        case .found(let data):
            word.imageData = data
            word.imageNotFound = false
        case .notFound:
            word.imageNotFound = true
        case .failed:
            break // нет сети — попробуем при следующем показе
        }
    }
}

struct WordImageView: View {
    let word: Word

    @State private var isRefreshing = false

    var body: some View {
        if word.isImageHidden {
            Button(action: { word.isImageHidden = false }) {
                Label("Показать картинку", systemImage: "photo")
                    .scaledFont(size: 12, weight: .semibold, design: .rounded)
                    .foregroundColor(.gray)
            }
        } else if let data = word.imageData, let image = UIImage(data: data) {
            // Рамка задаёт размер, картинка заполняет её и обрезается: широкая картинка из интернета
            // больше не растягивает карточку за края экрана
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(isRefreshing ? 0.4 : 1)
                .overlay(alignment: .topTrailing) { controls }
                .overlay { if isRefreshing { ProgressView() } }
        } else if !word.imageNotFound {
            ProgressView()
                .frame(height: 160)
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            imageControl(icon: "arrow.clockwise") {
                isRefreshing = true
                Task {
                    await WordImageLoader.loadNext(word)
                    isRefreshing = false
                }
            }
            .disabled(isRefreshing)

            imageControl(icon: "eye.slash") {
                word.isImageHidden = true
            }
        }
        .padding(8)
    }

    private func imageControl(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .scaledFont(size: 13, weight: .bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
    }
}
