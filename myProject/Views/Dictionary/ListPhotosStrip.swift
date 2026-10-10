import SwiftUI
import SwiftData

/// Фото, с которых сканом набран словарь: лента над словами, нажатие — на весь экран, долгое нажатие — удалить
struct ListPhotosStrip: View {
    let list: WordList

    @Environment(\.modelContext) private var modelContext
    @State private var images: [UIImage] = []
    @State private var openedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(images.count == 1 ? "Фото скана" : "Фото скана · \(images.count)")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(images.indices, id: \.self) { index in
                        Button {
                            openedIndex = index
                        } label: {
                            Image(uiImage: images[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Удалить фото", systemImage: "trash", role: .destructive) { delete(at: index) }
                        }
                        .accessibilityLabel("Фото скана \(index + 1)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .task(id: list.photosData) {
            images = list.photos.compactMap(UIImage.init(data:))
        }
        .fullScreenCover(item: Binding(get: { openedIndex.map(PhotoIndex.init) }, set: { openedIndex = $0?.value })) { start in
            ListPhotoViewer(images: images, start: start.value)
        }
    }

    private func delete(at index: Int) {
        var photos = list.photos
        guard photos.indices.contains(index) else { return }
        photos.remove(at: index)
        list.photos = photos
        try? modelContext.save()
    }

    private struct PhotoIndex: Identifiable {
        let value: Int
        var id: Int { value }
    }
}

/// Фото на весь экран; несколько — листаются
private struct ListPhotoViewer: View {
    let images: [UIImage]
    @State var selection: Int

    @Environment(\.dismiss) private var dismiss

    init(images: [UIImage], start: Int) {
        self.images = images
        _selection = State(initialValue: start)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .scaledFont(size: 30)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .padding(16)
            .accessibilityLabel("Закрыть")
        }
    }
}
