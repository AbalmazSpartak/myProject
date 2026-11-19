import SwiftUI

// Общие части дизайна «Словарь» (холст агента-дизайнера): чипы, строки слов, карточки-группы, поля, кнопки, значки состояний.
// Цвета — из палитры приложения, поэтому светлая и тёмная тема и выбор цветов в Настройках работают сами.

// MARK: - Состояние слова

/// Состояние слова: Новое — ни разу не оценивали, Учу — на заучивании (в том числе забытое), Знаю — в обычных повторениях
enum WordStatus: CaseIterable, Identifiable {
    case new, learning, known

    var id: Self { self }

    var title: String {
        switch self {
        case .new: "Новое"
        case .learning: "Учу"
        case .known: "Знаю"
        }
    }

    /// Значки разной формы: пустой круг, круг наполовину, круг с галочкой — состояние понятно и без цвета
    var symbol: String {
        switch self {
        case .new: "circle"
        case .learning: "circle.righthalf.filled"
        case .known: "checkmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .new: .statusNew
        case .learning: .statusLearning
        case .known: .statusKnown
        }
    }
}

extension Word {
    /// Так же считает статистика профиля: «изучено» — слова в обычных повторениях FSRS
    var studyStatus: WordStatus {
        if reps == 0 { return .new }
        return state == .review ? .known : .learning
    }
}

struct StatusIcon: View {
    let status: WordStatus
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: status.symbol)
            .scaledFont(size: size)
            .foregroundStyle(status.color)
            .accessibilityLabel(status.title)
    }
}

// MARK: - Чипы и значки

struct LXChipLabel: View {
    let title: String
    /// Число или пояснение после названия: длинное название сокращается, а оно остаётся
    var detail: String?
    var systemImage: String?
    var status: WordStatus?
    var isOn = false
    var chevron = false

    var body: some View {
        HStack(spacing: 6) {
            if let status {
                Image(systemName: status.symbol).scaledFont(size: 14).foregroundStyle(status.color)
            } else if let systemImage {
                Image(systemName: systemImage).scaledFont(size: 14)
            }
            Text(title).lineLimit(1)
            if let detail {
                Text(detail).lineLimit(1).fixedSize()
            }
            if chevron {
                Image(systemName: "chevron.down").scaledFont(size: 11, weight: .semibold)
            }
        }
        .scaledFont(size: 13, weight: isOn ? .semibold : .medium)
        .foregroundStyle(isOn ? Color.brandOnSoft : Color.brandDark)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Capsule().fill(isOn ? Color.brandAccent : Color.cardBackground))
        .overlay(Capsule().stroke(isOn ? Color.clear : Color.brandBorder, lineWidth: 1))
    }
}

struct LXChip: View {
    let title: String
    var systemImage: String?
    var status: WordStatus?
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            LXChipLabel(title: title, systemImage: systemImage, status: status, isOn: isOn)
        }
        .buttonStyle(.plain)
        // Сам чип 36 pt, нажимать удобнее по 44
        .padding(.vertical, 4)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct LevelBadge: View {
    let level: String

    var body: some View {
        Text(level)
            .scaledFont(size: 11, weight: .semibold)
            .foregroundStyle(Color.brandMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.brandFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Тонкая подпись раздела прописными буквами
struct LXSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .tracking(0.6)
            .scaledFont(size: 12, weight: .semibold)
            .foregroundStyle(Color.brandMuted)
    }
}

/// Круглая кнопка-значок 44 pt; «мягкая» — на акцентной подложке. Только вид — нажатие задаёт Button или Menu
struct LXIconLabel: View {
    let systemImage: String
    let label: String
    var isSoft = false

    var body: some View {
        Image(systemName: systemImage)
            .scaledFont(size: 19)
            .foregroundStyle(isSoft ? Color.brandOnSoft : Color.brandDark)
            .frame(width: 44, height: 44)
            .background(Circle().fill(isSoft ? Color.brandAccent : Color.clear))
            .contentShape(Circle())
            .accessibilityLabel(label)
    }
}

/// Квадратная плашка со значком — в строках «Папок»
struct LXSquareIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .scaledFont(size: 19)
            .foregroundStyle(Color.brandOnSoft)
            .frame(width: 44, height: 44)
            .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Строки слов

/// Строка списка: слово, перевод, уровень и состояние
struct LXWordRow: View {
    let word: Word

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.english)
                    .scaledFont(size: 21, weight: .medium, design: .serif)
                    .foregroundStyle(Color.brandDark)
                    .lineLimit(1)
                Text(word.russian)
                    .scaledFont(size: 14)
                    .foregroundStyle(Color.brandMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            LevelBadge(level: word.cefrLevel)
            StatusIcon(status: word.studyStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) { LXDivider() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Строка таблицы: слово | перевод | уровень | состояние
struct LXTableRow: View {
    let word: Word

    var body: some View {
        HStack(spacing: 10) {
            Text(word.english)
                .scaledFont(size: 17, weight: .medium, design: .serif)
                .foregroundStyle(Color.brandDark)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(word.russian)
                .scaledFont(size: 13)
                .foregroundStyle(Color.brandMuted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(word.cefrLevel)
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(Color.brandMuted)
                .frame(width: 30, alignment: .leading)
            StatusIcon(status: word.studyStatus, size: 18)
                .frame(width: 24)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) { LXDivider() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct LXTableHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Слово").frame(maxWidth: .infinity, alignment: .leading)
            Text("Перевод").frame(maxWidth: .infinity, alignment: .leading)
            Text("Ур.").frame(width: 30, alignment: .leading)
            Text("Ст.").frame(width: 24)
        }
        .scaledFont(size: 12, weight: .semibold)
        .foregroundStyle(Color.brandMuted)
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .background(Color.brandFill)
    }
}

struct LXDivider: View {
    var body: some View {
        Rectangle().fill(Color.brandBorder).frame(height: 1)
    }
}

// MARK: - Группы, поля, кнопки

/// Карточка-группа со строками, между строками — тонкие линии
struct LXGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                    subview
                    if index < subviews.count - 1 { LXDivider() }
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }
}

/// Карточка с произвольным содержимым
struct LXCard<Content: View>: View {
    var radius: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }
}

/// Поле формы: подпись мелко сверху, значение под ней
struct LXField<Content: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .tracking(0.5)
                .scaledFont(size: 11, weight: .semibold)
                .foregroundStyle(Color.brandMuted)
            content
            if let hint {
                Text(hint).scaledFont(size: 12).foregroundStyle(Color.brandMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }
}

enum LXButtonStyle {
    case primary, soft, outline, text
}

/// Кнопка во всю ширину: главная — цвет кнопок из Настроек, «мягкая», с рамкой, текстовая
struct LXButton: View {
    let title: String
    var systemImage: String?
    var style: LXButtonStyle = .primary
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).scaledFont(size: 17) }
                Text(title).scaledFont(size: style == .text ? 15 : 16, weight: style == .text ? .medium : .semibold)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: style == .text ? 44 : 52)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if style == .outline {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brandBorder, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var foreground: Color {
        switch style {
        case .primary: .brandOnButton
        case .soft: .brandOnSoft
        case .outline: .brandDark
        case .text: .brandMuted
        }
    }

    private var background: Color {
        switch style {
        case .primary: .brandButton
        case .soft: .brandAccent
        case .outline, .text: .clear
        }
    }
}

/// Верхняя строка экрана-листа: слева, по центру заголовок, справа
struct LXNavBar<Leading: View, Trailing: View>: View {
    var title: String?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .scaledFont(size: 17, weight: .semibold)
                    .foregroundStyle(Color.brandDark)
                    .lineLimit(1)
                    .padding(.horizontal, 90)
            }
            HStack {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 52)
    }
}

/// Текстовая кнопка в верхней строке: «Готово», «Отмена»
struct LXTextButton: View {
    let title: String
    var isMuted = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 16, weight: isMuted ? .medium : .semibold)
                .foregroundStyle(isMuted ? Color.brandMuted : Color.brandTint)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Круглая кнопка «назад» и подобные: значок на прозрачном фоне
struct LXBackButton: View {
    var systemImage = "chevron.left"
    var label = "Назад"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LXIconLabel(systemImage: systemImage, label: label)
        }
        .buttonStyle(.plain)
    }
}
