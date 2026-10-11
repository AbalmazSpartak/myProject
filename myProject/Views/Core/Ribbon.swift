import SwiftUI

// MARK: - Лента

/// Заголовок прописными и горизонтальная лента карточек
struct Ribbon<Content: View>: View {
    let title: String
    var onTitleTap: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let onTitleTap {
                    Button {
                        Haptics.tap()
                        onTitleTap()
                    } label: {
                        HStack(spacing: 4) {
                            titleText
                            Image(systemName: "chevron.right")
                                .scaledFont(size: 14, weight: .bold)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    titleText
                }
            }
            .foregroundColor(.brandDark)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var titleText: some View {
        Text(title.uppercased())
            .scaledFont(size: 17, weight: .bold)
    }
}

/// Карточка раздела или жанра: цветная плашка с иконкой и подпись
struct TileCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(color.opacity(0.18))
                    .frame(width: PadLayout.tileSize.width, height: PadLayout.tileSize.height)
                    .overlay {
                        Image(systemName: icon)
                            .scaledFont(size: PadLayout.isPad ? 40 : 30, weight: .semibold)
                            .foregroundColor(color)
                    }
                Text(title)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: PadLayout.tileSize.width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Подборка: обложка — картинка одного из её слов, если уже загружена; иначе градиент
struct CollectionCard: View {
    let name: String
    let words: [Word]
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                cover
                    .frame(width: PadLayout.tileSize.width, height: PadLayout.tileSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(name)
                    .scaledFont(size: 15, weight: .medium)
                    .foregroundColor(.brandDark)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: PadLayout.tileSize.width, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cover: some View {
        // Смотрим только первые слова — картинки хранятся отдельно, всю подборку не перебираем
        if let data = words.prefix(12).lazy.compactMap(\.imageData).first, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            let color = MenuPalette.colors[Self.stableIndex(of: name, count: MenuPalette.colors.count)].color
            LinearGradient(colors: [color.opacity(0.75), color.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Image(systemName: "text.book.closed.fill")
                        .scaledFont(size: 26)
                        .foregroundColor(.white.opacity(0.9))
                }
        }
    }

    /// Один и тот же цвет для подборки при каждом запуске (hashValue меняется между запусками)
    private static func stableIndex(of name: String, count: Int) -> Int {
        Int(name.unicodeScalars.reduce(UInt32(0)) { $0 &* 31 &+ $1.value } % UInt32(count))
    }
}

// MARK: - Заглушка

/// Раздел, который ещё не сделан
struct StubView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    var backTitle = "Обзор"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(backTitle)
                    }
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundColor(.brandDark)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(title)
                    .scaledFont(size: 26, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text(message)
                    .scaledFont(size: 17)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color.brandBackground.ignoresSafeArea())
    }
}
