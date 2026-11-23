import SwiftUI

/// «Меню чтения» по холсту (экран 8): лист снизу с поиском, оглавлением, размером текста, днём и ночью
/// и кнопками закладок. Всё, что открывает другой экран, выполняется после закрытия листа (onSelect → pending в читалке)
struct ReaderMenuSheet: View {
    let bookTitle: String
    /// Названия глав с номерами, как в оглавлении
    let chapterTitles: [String]
    let currentChapter: Int
    let isNight: Bool
    let hasBookmark: Bool
    /// Нужно перерисовать страницу: размер текста изменился
    let onStyleChange: () -> Void
    let onSearch: (String) -> Void
    let onChapter: (Int) -> Void
    let onAllChapters: () -> Void
    let onToggleDayNight: () -> Void
    let onBookmark: () -> Void
    let onBookmarks: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(ReaderSettings.fontSizeKey) private var fontSize = ReaderSettings.defaultFontSize
    @State private var query = ""

    /// Несколько глав вокруг текущей: полный список — по кнопке «Все главы»
    private var visibleChapters: [Int] {
        guard !chapterTitles.isEmpty else { return [] }
        let start = min(max(currentChapter - 1, 0), max(chapterTitles.count - 3, 0))
        return Array(start..<min(start + 3, chapterTitles.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(bookTitle)
                    .scaledFont(size: 22, weight: .semibold, design: .serif)
                    .foregroundStyle(Color.brandDark)
                    .lineLimit(1)
                Spacer()
                Button { dismiss() } label: {
                    LXIconLabel(systemImage: "xmark", label: "Закрыть")
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            searchField

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LXSectionLabel(text: "Оглавление")
                    Spacer()
                    if chapterTitles.count > visibleChapters.count {
                        Button("Все главы (\(chapterTitles.count))") { onAllChapters() }
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundStyle(Color.brandTint)
                            .frame(minHeight: 36)
                    }
                }
                LXGroup {
                    ForEach(visibleChapters, id: \.self) { index in
                        Button { onChapter(index) } label: {
                            HStack {
                                Text(chapterTitles[index])
                                    .scaledFont(size: 16, design: .serif)
                                    .foregroundStyle(index == currentChapter && !AppDesign.isSketch ? Color.brandTint : Color.brandDark)
                                    .fontWeight(index == currentChapter ? .semibold : .regular)
                                    .lineLimit(1)
                                Spacer()
                                if index == currentChapter {
                                    Image(systemName: "bookmark.fill").scaledFont(size: 13).foregroundStyle(Color.brandTint)
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LXSectionLabel(text: "Текст")
                HStack(spacing: 10) {
                    sizeButton("Мельче", size: 14, delta: -1)
                    sizeButton("Крупнее", size: 21, delta: 1)
                    dayNightControl
                }
            }

            HStack(spacing: 10) {
                LXButton(title: hasBookmark ? "Убрать закладку" : "Закладка здесь",
                         systemImage: hasBookmark ? "bookmark.slash" : "bookmark", action: onBookmark)
                LXButton(title: "Закладки", style: .outline, action: onBookmarks)
            }
            .padding(.top, 2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Color.brandBackground.ignoresSafeArea())
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Части

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").scaledFont(size: 17)
            TextField("Найти слово или фразу", text: $query)
                .scaledFont(size: 15)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    let text = query.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    onSearch(text)
                }
        }
        .foregroundStyle(Color.brandMuted)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppDesign.isSketch ? Color.clear : Color.brandBorder, lineWidth: 1))
        .sketchFrame(AppDesign.isSketch, radius: 12, shadow: NewStyle.blue, offset: 3)
    }

    /// «A» мельче и крупнее: шаг на один пункт, в тех же пределах, что и в «Оформлении»
    private func sizeButton(_ label: String, size: CGFloat, delta: Double) -> some View {
        Button {
            Haptics.tap()
            fontSize = min(max(fontSize + delta, ReaderSettings.fontSizeRange.lowerBound), ReaderSettings.fontSizeRange.upperBound)
            onStyleChange()
        } label: {
            Text("A")
                .scaledFont(size: size, weight: .semibold, design: .serif)
                .foregroundStyle(Color.brandDark)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppDesign.isSketch ? Color.clear : Color.brandBorder, lineWidth: 1.5))
                .sketchFrame(AppDesign.isSketch, radius: 12, shadow: NewStyle.blue, offset: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dayNightControl: some View {
        HStack(spacing: 2) {
            segment("Светлая", isOn: !isNight)
            segment("Тёмная", isOn: isNight)
        }
        .padding(3)
        .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func segment(_ title: String, isOn: Bool) -> some View {
        Button {
            if !isOn { onToggleDayNight() }
        } label: {
            Text(title)
                .scaledFont(size: 13, weight: isOn ? .semibold : .medium)
                .foregroundStyle(isOn ? (AppDesign.isSketch ? NewStyle.onYellow : Color.brandTint) : Color.brandMuted)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(isOn && AppDesign.isSketch ? NewStyle.yellow : isOn ? Color.cardBackground : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
