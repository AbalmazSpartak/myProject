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

    var body: some View {
        List {
            if account.isSignedIn {
                signedIn
            } else {
                switch step {
                case .signIn: signInStep
                case .email: emailStep
                case .code: codeStep
                case .password: passwordStep
                }
            }
        }
        .brandListBackground()
        .navigationTitle("Аккаунт")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Вход

    private var signInStep: some View {
        Section {
            emailField
            SecureField("Пароль", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit(signIn)
            Button(action: signIn) { busyLabel("Войти") }
                .disabled(isBusy || !email.contains("@") || password.isEmpty)
            Button("Забыли пароль?") { begin(reset: true) }
            Button("Создать аккаунт") { begin(reset: false) }
        } header: {
            Text("Вход")
        } footer: {
            footer("Аккаунт нужен, чтобы данные были на всех ваших устройствах. Без него приложение работает как раньше.")
        }
        .listRowBackground(Color.cardBackground)
    }

    // MARK: - Регистрация и сброс

    private var emailStep: some View {
        Section {
            emailField
            Button(action: sendCode) { busyLabel("Получить код") }
                .disabled(isBusy || !email.contains("@"))
            Button("Назад") { back() }
        } header: {
            Text(isReset ? "Сброс пароля" : "Новый аккаунт")
        } footer: {
            footer("Пришлём на почту код из 6 цифр, чтобы убедиться, что адрес ваш.")
        }
        .listRowBackground(Color.cardBackground)
    }

    private var codeStep: some View {
        Section {
            TextField("Код из письма", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: code) { _, value in
                    code = String(value.filter(\.isNumber).prefix(6))
                    if code.count == 6 { verify() }
                }
            Button(action: verify) { busyLabel("Продолжить") }
                .disabled(isBusy || code.count != 6)
            Button("Другая почта или выслать код ещё раз") {
                step = .email
                code = ""
                message = nil
            }
            .disabled(isBusy)
        } header: {
            Text("Код отправлен на \(cleanEmail)")
        } footer: {
            footer("Письмо идёт до минуты; загляните в «Спам». Код действует 10 минут.")
        }
        .listRowBackground(Color.cardBackground)
    }

    private var passwordStep: some View {
        Section {
            SecureField("Пароль, не короче \(Account.minPassword) символов", text: $password)
                .textContentType(.newPassword)
            SecureField("Повторите пароль", text: $repeated)
                .textContentType(.newPassword)
                .submitLabel(.done)
                .onSubmit(savePassword)
            Button(action: savePassword) { busyLabel(isReset ? "Сменить пароль и войти" : "Создать аккаунт") }
                .disabled(isBusy || password.count < Account.minPassword || repeated.isEmpty)
        } header: {
            Text("Придумайте пароль")
        } footer: {
            footer("Почта подтверждена. Пароль сохранится на сервере только в зашифрованном виде; iPhone предложит запомнить его в «Связке ключей».")
        }
        .listRowBackground(Color.cardBackground)
    }

    // MARK: - Вы вошли

    private var signedIn: some View {
        Group {
            Section {
                HStack {
                    Text("Почта")
                    Spacer()
                    Text(account.email ?? "").foregroundColor(.gray)
                }
                if isChangingPassword {
                    SecureField("Старый пароль", text: $oldPassword)
                        .textContentType(.password)
                    SecureField("Новый пароль, не короче \(Account.minPassword) символов", text: $password)
                        .textContentType(.newPassword)
                    Button(action: changePassword) { busyLabel("Сохранить пароль") }
                        .disabled(isBusy || oldPassword.isEmpty || password.count < Account.minPassword)
                    Button("Отмена") { isChangingPassword = false; clearPasswords() }
                } else {
                    Button("Сменить пароль") { isChangingPassword = true; notice = nil; message = nil }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let notice { Text(notice).foregroundColor(.green) }
                    if let message { Text(message).foregroundColor(.red) }
                    if isChangingPassword { Text("На других устройствах после смены пароля придётся войти заново.") }
                }
                .textSelection(.enabled)
            }
            .listRowBackground(Color.cardBackground)
            Section {
                Button("Выйти", role: .destructive) {
                    Task { await account.signOut() }
                }
            } footer: {
                footer("Выход действует только на этом устройстве: слова и книги остаются.")
            }
            .listRowBackground(Color.cardBackground)
        }
    }

    // MARK: - Общее

    private var emailField: some View {
        TextField("Почта", text: $email)
            .keyboardType(.emailAddress)
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
