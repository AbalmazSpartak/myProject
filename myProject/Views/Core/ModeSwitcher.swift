import SwiftUI

/// Переключатель «Чтение | Обучение» наверху корневых экранов (дизайн LexiStream).
/// Читалка как отдельное приложение — то же самое без переключателя
struct ModeSwitcher: View {
    @AppStorage(AppMode.storageKey) private var mode = AppMode.learning
    @AppStorage(AppMode.readerOnlyKey) private var readerOnly = false
    @AppStorage(AppMode.learningOnlyKey) private var learningOnly = false
    @AppStorage(AppDesign.storageKey) private var design = AppDesign.classic.rawValue

    private var isSketch: Bool { design == AppDesign.sketch.rawValue }

    var body: some View {
        // «Только читалка» или «Только обучение» — переключателя нет
        if !readerOnly && !learningOnly { switcher }
    }

    private var switcher: some View {
        HStack(spacing: 0) {
            segment(.reading, title: "Чтение")
            segment(.learning, title: "Обучение")
        }
        .padding(isSketch ? 4 : 3)
        .background {
            if isSketch {
                RoughRoundedRect(radius: 23, seed: 6).fill(Color.cardBackground)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandInputBg)
            }
        }
        .sketchFrame(isSketch, radius: 23)
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
                .foregroundColor(isSketch ? (isOn ? NewStyle.onYellow : .brandMuted) : (isOn ? .brandTint : .brandMuted))
                .frame(maxWidth: .infinity, minHeight: isSketch ? 38 : 36)
                .background {
                    if isOn && isSketch {
                        RoughRoundedRect(radius: 19, seed: 8).fill(NewStyle.yellow)
                            .overlay(RoughRoundedRect(radius: 19, seed: 8).stroke(NewStyle.outline, style: NewStyle.stroke))
                    } else if isOn {
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
