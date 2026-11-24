import SwiftUI

/// Свой сегментный переключатель вместо системного `.segmented`: цвета берутся из палитры приложения,
/// поэтому он читается при любой теме окна (системный в шторке над тёмной книгой становился чёрным)
struct ChoiceSegments<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .scaledFont(size: 14, weight: .semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(isSelected ? .white : Color.brandDark)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .padding(.horizontal, 4)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8).fill(Color.brandTint)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.brandInputBg))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandMuted.opacity(0.3), lineWidth: 1))
    }
}

extension ChoiceSegments where Value: CaseIterable & Identifiable, Value.AllCases: RandomAccessCollection {
    /// Все варианты перечисления с их подписями
    init(selection: Binding<Value>, title: @escaping (Value) -> String) {
        _selection = selection
        options = Value.allCases.map { ($0, title($0)) }
    }
}
