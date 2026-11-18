import SwiftUI

/// «Аккаунт»: вход по почте и паролю; регистрация и сброс пароля — через код из письма
struct AccountView: View {
    private enum Step {
        case signIn
        /// Регистрация или сброс: почта → код → новый пароль
        case email, code, password
    }

    @State private var account = Account.shared
    @State private var step = Step.signIn
    @State private var isReset = false
    @State private var email = ""
    @State private var code = ""
    @State private var ticket = ""
    @State private var password = ""
    @State private var repeated = ""
    @State private var oldPassword = ""
    @State private var isChangingPassword = false
    @State private var isBusy = false
    @State private var message: String?
    @State private var notice: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .scaledFont(size: 34, weight: .semibold, design: .serif)
                    .foregroundColor(.brandDark)
                Text(subtitle)
                    .scaledFont(size: 14)
                    .foregroundColor(.brandMuted)
                    .padding(.bottom, 4)
                if account.isSignedIn {
                    signedIn
                } else {
                    if step == .signIn || (step == .email && !isReset) { modeTabs }
                    switch step {
                    case .signIn: signInStep
                    case .email: emailStep
                    case .code: codeStep
                    case .password: passwordStep
                    }
                    if let message {
                        Text(message).scaledFont(size: 13).foregroundColor(.brandDark)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brandAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.brandBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        if account.isSignedIn { return "Аккаунт" }
        switch step {
        case .signIn: return "Вход"
        case .email: return isReset ? "Сброс пароля" : "Регистрация"
        case .code: return "Код из письма"
        case .password: return isReset ? "Новый пароль" : "Придумайте пароль"
        }
    }

    private var subtitle: String {
        if account.isSignedIn { return "Синхронизация включена. Выход действует только на этом устройстве: слова и книги остаются." }
        switch step {
        case .code: return "Код отправлен на \(cleanEmail). Письмо идёт до минуты, загляните в «Спам». Код действует 10 минут."
        case .password: return "Почта подтверждена. Пароль хранится на сервере только в зашифрованном виде."
        default: return "Аккаунт нужен только для синхронизации между устройствами. Читать можно и без него."
        }
    }

    // MARK: - Элементы по дизайну

    private var modeTabs: some View {
        HStack(spacing: 2) {
            tab("Вход", on: step == .signIn) { if step != .signIn { back() } }
            tab("Регистрация", on: step == .email) { if step != .email { begin(reset: false) } }
        }
        .padding(3)
        .background(Color.brandInputBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 14, weight: on ? .semibold : .medium)
                .foregroundColor(on ? .brandTint : .brandMuted)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background {
                    if on { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.cardBackground) }
                }
        }
        .buttonStyle(.plain)
    }

    private func field<Content: View>(_ icon: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).scaledFont(size: 16).foregroundColor(.brandMuted).frame(width: 22)
            content().scaledFont(size: 15).foregroundColor(.brandDark)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandBorder, lineWidth: 1))
    }

    private func primary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).scaledFont(size: 15, weight: .semibold)
                if isBusy { ProgressView().tint(.brandOnTint) }
            }
            .foregroundColor(.brandOnTint)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.brandButton.opacity(enabled ? 1 : 0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isBusy)
    }

    private func secondary(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).scaledFont(size: 15, weight: .semibold)
                .foregroundColor(.brandDark.opacity(enabled ? 1 : 0.5))
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).scaledFont(size: 14, weight: .medium).foregroundColor(.brandTint)
                .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    /// «или» и вход через Apple — заглушка: входа через Apple пока нет
    private var appleStub: some View {
        VStack(spacing: 12) {
            Text("или").scaledFont(size: 13).foregroundColor(.brandMuted).frame(maxWidth: .infinity)
            secondary("Продолжить с Apple · скоро", enabled: false) {}
        }
    }

    // MARK: - Вход

    private var signInStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            emailField
            field("lock") {
                SecureField("Пароль", text: $password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit(signIn)
            }
            link("Забыли пароль?") { begin(reset: true) }
                .padding(.top, -8)
            primary("Войти", enabled: email.contains("@") && !password.isEmpty, action: signIn)
            appleStub
            link("Пока без аккаунта") { dismiss() }
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Регистрация и сброс

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            emailField
            primary("Получить код", enabled: email.contains("@"), action: sendCode)
            Text("Пришлём на почту код из 6 цифр, чтобы убедиться, что адрес ваш.")
                .scaledFont(size: 12).foregroundColor(.brandMuted)
            if isReset { link("Назад ко входу") { back() } } else { appleStub }
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("number") {
                TextField("Код из письма", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: code) { _, value in
                        code = String(value.filter(\.isNumber).prefix(6))
                        if code.count == 6 { verify() }
                    }
            }
            primary("Продолжить", enabled: code.count == 6, action: verify)
            link("Другая почта или выслать код ещё раз") {
                step = .email
                code = ""
                message = nil
            }
            .disabled(isBusy)
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("lock") {
                SecureField("Пароль · не короче \(Account.minPassword) символов", text: $password)
                    .textContentType(.newPassword)
            }
            field("lock") {
                SecureField("Повторите пароль", text: $repeated)
                    .textContentType(.newPassword)
                    .submitLabel(.done)
                    .onSubmit(savePassword)
            }
            primary(isReset ? "Сменить пароль и войти" : "Создать аккаунт",
                    enabled: password.count >= Account.minPassword && !repeated.isEmpty, action: savePassword)
        }
    }

    // MARK: - Вы вошли

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            field("envelope") { Text(account.email ?? "") }
            if isChangingPassword {
                field("lock") { SecureField("Старый пароль", text: $oldPassword).textContentType(.password) }
                field("lock") {
                    SecureField("Новый пароль · не короче \(Account.minPassword) символов", text: $password)
                        .textContentType(.newPassword)
                }
                primary("Сохранить пароль", enabled: !oldPassword.isEmpty && password.count >= Account.minPassword, action: changePassword)
                link("Отмена") { isChangingPassword = false; clearPasswords() }
                Text("На других устройствах после смены пароля придётся войти заново.")
                    .scaledFont(size: 12).foregroundColor(.brandMuted)
            } else {
                secondary("Сменить пароль") { isChangingPassword = true; notice = nil; message = nil }
            }
            if let notice {
                Text(notice).scaledFont(size: 13).foregroundColor(.brandTint)
            }
            if let message {
                Text(message).scaledFont(size: 13).foregroundColor(.brandDark)
            }
            Button {
                Task { await account.signOut() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Выйти").scaledFont(size: 15, weight: .semibold)
                }
                .foregroundColor(.brandDark)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.brandBorder, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Общее

    private var emailField: some View {
        field("envelope") {
            TextField("Электронная почта", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var cleanEmail: String { email.trimmingCharacters(in: .whitespaces).lowercased() }

    private func footer(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
            if let message { Text(message).foregroundColor(.red) }
        }
        .textSelection(.enabled)
    }

    private func busyLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            if isBusy { Spacer(); ProgressView() }
        }
    }

    private func clearPasswords() {
        password = ""
        repeated = ""
        oldPassword = ""
    }

    private func begin(reset: Bool) {
        isReset = reset
        message = nil
        clearPasswords()
        step = .email
    }

    private func back() {
        message = nil
        clearPasswords()
        step = .signIn
    }

    // MARK: - Действия

    private func run(_ work: @escaping () async throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        Task {
            defer { isBusy = false }
            do { try await work() } catch { message = text(for: error) }
        }
    }

    private func signIn() {
        guard email.contains("@"), !password.isEmpty else { return }
        run {
            try await account.signIn(email: cleanEmail, password: password)
            clearPasswords()
        }
    }

    private func sendCode() {
        run {
            try await account.requestCode(email: cleanEmail)
            code = ""
            step = .code
        }
    }

    private func verify() {
        guard code.count == 6 else { return }
        run {
            ticket = try await account.verify(email: cleanEmail, code: code)
            code = ""
            step = .password
        }
    }

    private func savePassword() {
        guard password.count >= Account.minPassword, !repeated.isEmpty else { return }
        guard password == repeated else {
            message = "Пароли не совпадают."
            return
        }
        run {
            try await account.setPassword(email: cleanEmail, ticket: ticket, password: password)
            ticket = ""
            clearPasswords()
            step = .signIn
        }
    }

    private func changePassword() {
        run {
            try await account.changePassword(old: oldPassword, new: password)
            clearPasswords()
            isChangingPassword = false
            notice = "Пароль изменён."
        }
    }

    private func text(for error: Error) -> String {
        switch error as? Account.Failure {
        case .badEmail: "Проверьте адрес почты."
        case .wait(let seconds): "Подождите \(seconds) с и попробуйте снова."
        case .tooMany: "Слишком много попыток. Попробуйте позже."
        case .wrongCode: "Код не подходит."
        case .expired:
            step == .password ? "Время вышло. Начните сначала." : "Код устарел. Запросите новый."
        case .weakPassword: "Пароль должен быть не короче \(Account.minPassword) символов."
        case .wrongPassword: "Неверная почта или пароль."
        case .locked(let seconds): "Слишком много неверных паролей. Подождите \(max(seconds / 60, 1)) мин."
        case .mail: "Не удалось отправить письмо. Попробуйте позже."
        case .network, .none: "Нет связи с сервером. Проверьте интернет."
        }
    }
}
