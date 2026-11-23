import SwiftUI

// Меню в стиле «Скетч»: вместо системного выпадающего меню — карточка по центру с контуром «от руки».
// В классическом виде — обычные `Menu` и `.contextMenu`, ничего не меняется.
// Внутри — обычные `Button` (в том числе с role и Label), `Picker`, `Section`, `Divider`, `Text`.

/// Выбор одного из вариантов внутри меню: в классике — обычный `Picker`, в «Скетче» — пункты с галочкой у выбранного
struct LXMenuPicker<Value: Hashable, Option: View>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    @ViewBuilder let option: (Value) -> Option

    var body: some View {
        if AppDesign.isSketch {
            ForEach(options, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    HStack {
                        option(value)
                        Spacer(minLength: 8)
                        if value == selection { Image(systemName: "checkmark") }
                    }
                }
            }
        } else {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option($0).tag($0) }
            }
        }
    }
}

/// Замена `Menu { … } label: { … }`
struct LXMenu<Label: View, Content: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let label: Label
    @State private var isShown = false

    var body: some View {
        if AppDesign.isSketch {
            Button {
                isShown = true
            } label: {
                label
            }
            .buttonStyle(.plain)
            .sketchMenuCover(isPresented: $isShown) { content }
        } else {
            Menu { content } label: { label }
        }
    }
}

extension View {
    /// Замена `.contextMenu { … }`: в «Скетче» — долгое нажатие открывает карточку с теми же пунктами
    @ViewBuilder
    func lxContextMenu<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if AppDesign.isSketch {
            modifier(SketchContextMenu(items: content()))
        } else {
            contextMenu { content() }
        }
    }

    fileprivate func sketchMenuCover<Items: View>(isPresented: Binding<Bool>, @ViewBuilder items: @escaping () -> Items) -> some View {
        fullScreenCover(isPresented: isPresented) {
            SketchMenuCard(isPresented: isPresented, items: items())
                .presentationBackground(.clear)
        }
        // Меню появляется сразу, без выезда снизу
        .transaction(value: isPresented.wrappedValue) { $0.disablesAnimations = true }
    }
}

private struct SketchContextMenu<Items: View>: ViewModifier {
    let items: Items
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                Haptics.tap()
                isShown = true
            })
            .sketchMenuCover(isPresented: $isShown) { items }
    }
}

private struct SketchMenuCard<Items: View>: View {
    @Binding var isPresented: Bool
    let items: Items
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Group(sections: items) { sections in
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .padding(10)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .buttonStyle(SketchMenuRowStyle(dismiss: { isPresented = false }))
            .labelsHidden()
            .tint(NewStyle.outline)
            .scaledFont(size: 16)
            .foregroundStyle(Color.brandDark)
            .frame(maxWidth: 360)
            .frame(height: contentHeight > 0 ? min(contentHeight, 520) : nil)
            .lxPlate(radius: 18)
            .padding(.horizontal, 28)
        }
    }

    private func sectionView(_ section: SectionConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group(subviews: section.header) { header in
                if !header.isEmpty {
                    header[0]
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundStyle(Color.brandMuted)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                }
            }
            Group(subviews: section.content) { rows in
                ForEach(rows.indices, id: \.self) { index in
                    rows[index]
                }
            }
        }
    }
}

/// Пункт меню: строка с надписью слева; после нажатия меню закрывается, и только потом выполняется действие
/// (иначе окно, которое действие открывает, упрётся в ещё не закрытое меню)
private struct SketchMenuRowStyle: PrimitiveButtonStyle {
    let dismiss: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        Button {
            Haptics.tap()
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                configuration.trigger()
            }
        } label: {
            configuration.label
                .scaledFont(size: 16, weight: .medium)
                .foregroundStyle(configuration.role == .destructive ? Color.red : Color.brandDark)
                .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                .padding(.horizontal, 12)
                .background(Color.brandBackground.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
