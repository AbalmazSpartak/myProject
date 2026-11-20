import SwiftUI

/// Переключатель «Чтение | Обучение» наверху корневых экранов (дизайн LexiStream).
/// Читалка как отдельное приложение — то же самое без переключателя
struct ModeSwitcher: View {
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false
    @AppStorage(AppMode.learningOnlyKey) private var learningOnly = false

    var body: some View {
        // «Только читалка» или «Только обучение» — переключателя нет
        if !readerOnly && !learningOnly { switcher }
    }

    private var switcher: some View {
        HStack(spacing: 0) {
            segment(.reading, title: "Чтение")
            segment(.learning, title: "Обучение")
        }
        .padding(3)
        .background(Color.brandInputBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Color.brandBackground)
    }

    private func segment(_ value: AppMode, title: String) -> some View {
        let isOn = mode == value
        return Button {
            guard !isOn else { return }
            Haptics.tap()
            mode = value
        } label: {
            Text(title)
                .scaledFont(size: 14, weight: isOn ? .semibold : .medium)
                .foregroundColor(isOn ? .brandTint : .brandMuted)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cardBackground)
                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension View {
    /// Переключатель режимов сверху корневого экрана вкладки (на вложенные экраны не действует)
    func modeSwitcherInset() -> some View {
        safeAreaInset(edge: .top, spacing: 0) { ModeSwitcher() }
    }
}
