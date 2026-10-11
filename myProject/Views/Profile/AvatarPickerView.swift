import SwiftUI

/// Готовые аватарки: животные-эмодзи, иконки, инициалы — на цветном градиенте.
/// Выбранная рисуется в картинку и сохраняется как обычное фото профиля (avatarData) — видна везде, где фото
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    /// Для «Инициалов» — первая буква имени
    let name: String
    let onPick: (Data) -> Void

    private enum Kind: String, CaseIterable, Identifiable {
        case animals, icons, initials
        var id: String { rawValue }
        var title: String {
            switch self {
            case .animals: return "Животные"
            case .icons: return "Иконки"
            case .initials: return "Инициалы"
            }
        }
    }

    @State private var kind = Kind.animals

    private static let animals = ["🦊", "🐼", "🦉", "🐱", "🐨", "🦁", "🐸", "🐙", "🐶", "🐯", "🐻", "🐰",
                                  "🦄", "🐧", "🐵", "🦋", "🐢", "🐳", "🦜", "🐝", "🦔", "🐺", "🐮", "🐹"]
    private static let icons = ["book.fill", "graduationcap.fill", "bolt.fill", "star.fill", "crown.fill", "flame.fill",
                                "leaf.fill", "moon.stars.fill", "sun.max.fill", "globe.europe.africa.fill", "airplane",
                                "music.note", "paintbrush.fill", "gamecontroller.fill", "heart.fill", "sparkles",
                                "brain.head.profile", "paperplane.fill"]

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased().ifEmpty("?")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Набор", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 16)], spacing: 16) {
                        ForEach(Array(arts.enumerated()), id: \.offset) { _, art in
                            Button {
                                pick(art)
                            } label: {
                                art.frame(width: 72, height: 72)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .padding(.top, 8)
            .background(Color.brandBackground.ignoresSafeArea())
            .navigationTitle("Аватарка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private var arts: [AvatarArt] {
        switch kind {
        case .animals:
            return Self.animals.enumerated().map { AvatarArt(content: .emoji($1), palette: $0) }
        case .icons:
            return Self.icons.enumerated().map { AvatarArt(content: .symbol($1), palette: $0 + 3) }
        case .initials:
            return AvatarArt.palettes.indices.map { AvatarArt(content: .letter(initial), palette: $0) }
        }
    }

    /// Рисуем аватарку в картинку 512 × 512 и отдаём как фото профиля
    private func pick(_ art: AvatarArt) {
        let renderer = ImageRenderer(content: art.frame(width: 256, height: 256))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { return }
        Haptics.tap()
        onPick(data)
        dismiss()
    }
}

/// Круглая аватарка: эмодзи, символ или буква на мягком градиенте
struct AvatarArt: View {
    enum Content {
        case emoji(String)
        case symbol(String)
        case letter(String)
    }

    let content: Content
    let palette: Int

    static let palettes: [(Color, Color)] = [
        (Color(red: 1.00, green: 0.80, blue: 0.55), Color(red: 1.00, green: 0.55, blue: 0.40)),
        (Color(red: 0.62, green: 0.85, blue: 0.75), Color(red: 0.30, green: 0.66, blue: 0.58)),
        (Color(red: 0.70, green: 0.80, blue: 1.00), Color(red: 0.42, green: 0.52, blue: 0.95)),
        (Color(red: 1.00, green: 0.72, blue: 0.80), Color(red: 0.92, green: 0.42, blue: 0.60)),
        (Color(red: 0.85, green: 0.75, blue: 1.00), Color(red: 0.58, green: 0.42, blue: 0.90)),
        (Color(red: 1.00, green: 0.90, blue: 0.55), Color(red: 0.98, green: 0.70, blue: 0.25)),
        (Color(red: 0.60, green: 0.88, blue: 0.95), Color(red: 0.20, green: 0.62, blue: 0.80)),
        (Color(red: 0.80, green: 0.90, blue: 0.62), Color(red: 0.50, green: 0.72, blue: 0.35)),
        (Color(red: 0.95, green: 0.78, blue: 0.68), Color(red: 0.76, green: 0.50, blue: 0.40)),
        (Color(red: 0.78, green: 0.80, blue: 0.86), Color(red: 0.45, green: 0.50, blue: 0.62)),
        (Color(red: 1.00, green: 0.66, blue: 0.62), Color(red: 0.88, green: 0.33, blue: 0.38)),
        (Color(red: 0.66, green: 0.92, blue: 0.86), Color(red: 0.26, green: 0.70, blue: 0.70)),
    ]

    var body: some View {
        let colors = Self.palettes[palette % Self.palettes.count]
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing))
                switch content {
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.system(size: side * 0.56))
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.system(size: side * 0.42, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.12), radius: side * 0.02, y: side * 0.01)
                case .letter(let letter):
                    Text(letter)
                        .font(.system(size: side * 0.48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.12), radius: side * 0.02, y: side * 0.01)
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
