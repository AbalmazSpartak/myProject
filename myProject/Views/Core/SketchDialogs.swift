import SwiftUI

// Окна подтверждения и ввода в стиле «Скетч»: карточка по центру с контуром «от руки» вместо системного alert/confirmationDialog.
// В классическом виде вызывают обычные системные `.alert` и `.confirmationDialog` — ничего не меняется.
// Кнопки внутри окна — обычные `Button` (в том числе с role), поля ввода — обычные `TextField`.

extension View {
    /// Замена `.alert(_:isPresented:actions:message:)`
    @ViewBuilder
    func lxAlert<A: View, M: View>(_ title: String, isPresented: Binding<Bool>,
                                   @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        if AppDesign.isSketch {
            modifier(SketchDialogModifier(title: title, isPresented: isPresented, actions: actions(), message: message()))
        } else {
            alert(title, isPresented: isPresented, actions: actions, message: message)
        }
    }

    /// Замена `.alert(_:isPresented:actions:)`
    @ViewBuilder
    func lxAlert<A: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        if AppDesign.isSketch {
            modifier(SketchDialogModifier(title: title, isPresented: isPresented, actions: actions(), message: EmptyView()))
        } else {
            alert(title, isPresented: isPresented, actions: actions)
        }
    }

    /// Замена `.confirmationDialog(_:isPresented:titleVisibility:actions:message:)`
    @ViewBuilder
    func lxDialog<A: View, M: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                    @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        if AppDesign.isSketch {
            modifier(SketchDialogModifier(title: title, isPresented: isPresented, actions: actions(), message: message()))
        } else {
            confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
        }
    }

    /// Замена `.confirmationDialog(_:isPresented:titleVisibility:actions:)`
    @ViewBuilder
    func lxDialog<A: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                           @ViewBuilder actions: () -> A) -> some View {
        if AppDesign.isSketch {
            modifier(SketchDialogModifier(title: title, isPresented: isPresented, actions: actions(), message: EmptyView()))
        } else {
            confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
        }
    }

    /// Замена `.confirmationDialog(_:isPresented:titleVisibility:presenting:actions:message:)`
    @ViewBuilder
    func lxDialog<T, A: View, M: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic,
                                       presenting data: T?, @ViewBuilder actions: @escaping (T) -> A,
                                       @ViewBuilder message: @escaping (T) -> M) -> some View {
        if AppDesign.isSketch {
            modifier(SketchDialogModifier(title: title, isPresented: isPresented,
                                          actions: Group { if let data { actions(data) } }, message: Group { if let data { message(data) } }))
        } else {
            confirmationDialog(title, isPresented: isPresented, titleVisibility: titleVisibility,
                               presenting: data, actions: actions, message: message)
        }
    }
}

private struct SketchDialogModifier<A: View, M: View>: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    let actions: A
    let message: M

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                SketchDialogCard(title: title, isPresented: $isPresented, actions: actions, message: message)
                    .presentationBackground(.clear)
            }
            // Окно появляется сразу, без выезда снизу: это не экран, а подтверждение
            .transaction(value: isPresented) { $0.disablesAnimations = true }
    }
}

private struct SketchDialogCard<A: View, M: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let actions: A
    let message: M

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            VStack(alignment: .leading, spacing: 12) {
                if !title.isEmpty {
                    Text(title)
                        .scaledFont(size: 24, weight: .medium, design: .rounded)
                        .foregroundStyle(Color.brandDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
                message
                    .scaledFont(size: 15)
                    .foregroundStyle(Color.brandMuted)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    actions
                }
                .buttonStyle(SketchDialogButtonStyle(dismiss: { isPresented = false }))
                .textFieldStyle(SketchDialogFieldStyle())
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .lxPlate(radius: 20)
            .padding(.horizontal, 28)
            .frame(maxWidth: 420)
        }
    }
}

/// Кнопка окна: обычная — жёлтая, «Отмена» — с контуром, «destructive» — персиковая; после нажатия окно закрывается
private struct SketchDialogButtonStyle: PrimitiveButtonStyle {
    let dismiss: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        let role = configuration.role
        let fill: Color = role == .cancel ? Color.cardBackground : role == .destructive ? NewStyle.peach : NewStyle.yellow
        let shadow: Color = role == .cancel ? NewStyle.blue : role == .destructive ? NewStyle.peach : NewStyle.yellowShadow
        let foreground: Color = role == .cancel || role == .destructive ? Color.brandDark : NewStyle.onYellow
        Button {
            Haptics.tap()
            configuration.trigger()
            dismiss()
        } label: {
            configuration.label
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
                .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .sketchFrame(true, radius: 14, shadow: shadow, offset: 3)
        }
        .buttonStyle(.plain)
    }
}

/// Поле ввода внутри окна: плашка с контуром
private struct SketchDialogFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .scaledFont(size: 16)
            .foregroundStyle(Color.brandDark)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.brandBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .sketchFrame(true, radius: 12, shadow: NewStyle.blue, offset: 3)
    }
}
