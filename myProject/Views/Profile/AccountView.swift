import SwiftUI

/// «Аккаунт»: вход по почте — адрес, затем код из письма. Без пароля
struct AccountView: View {
    @State private var account = Account.shared
    @State private var email = ""
    @State private var code = ""
    @State private var codeSentTo: String?
    @State private var isBusy = false
    @State private var message: String?
    @FocusState private var focused: Bool

    var body: some View {
        List {
            if account.isSignedIn {
                signedIn
            } else if let codeSentTo {
                codeStep(codeSentTo)
            } else {
                emailStep
            }
        }
        .brandListBackground()
        .navigationTitle("Аккаунт")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Шаги

    private var emailStep: some View {
        Section {
            TextField("Почта", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(sendCode)
            Button(action: sendCode) { busyLabel("Получить код") }
                .disabled(isBusy || !email.contains("@"))
        } header: {
            Text("Вход")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Пришлём на почту код из 6 цифр. Пароль не нужен. Вход нужен, чтобы данные были на всех ваших устройствах; без него приложение работает как раньше.")
                if let message { Text(message).foregroundColor(.red) }
            }
            .textSelection(.enabled)
        }
        .listRowBackground(Color.cardBackground)
    }

    private func codeStep(_ address: String) -> some View {
        Section {
            TextField("Код из письма", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .onChange(of: code) { _, value in
                    code = String(value.filter(\.isNumber).prefix(6))
                    if code.count == 6 { verify(address) }
                }
            Button { verify(address) } label: { busyLabel("Войти") }
                .disabled(isBusy || code.count != 6)
            Button("Другая почта или выслать код ещё раз") {
                codeSentTo = nil
                code = ""
                message = nil
            }
            .disabled(isBusy)
        } header: {
            Text("Код отправлен на \(address)")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Письмо идёт до минуты; загляните в «Спам». Код действует 10 минут.")
                if let message { Text(message).foregroundColor(.red) }
            }
            .textSelection(.enabled)
        }
        .listRowBackground(Color.cardBackground)
    }

    private var signedIn: some View {
        Section {
            HStack {
                Text("Почта")
                Spacer()
                Text(account.email ?? "").foregroundColor(.gray)
            }
            Button("Выйти", role: .destructive) {
                Task { await account.signOut() }
            }
        } footer: {
            Text("Выход затрагивает только это устройство: слова и книги на нём остаются.")
                .textSelection(.enabled)
        }
        .listRowBackground(Color.cardBackground)
    }

    private func busyLabel(_ title: String) -> some View {
        HStack {
            Text(title)
            if isBusy { Spacer(); ProgressView() }
        }
    }

    // MARK: - Действия

    private func sendCode() {
        let address = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !isBusy, address.contains("@") else { return }
        isBusy = true
        message = nil
        Task {
            defer { isBusy = false }
            do {
                try await account.requestCode(email: address)
                codeSentTo = address
                code = ""
                focused = true
            } catch {
                message = text(for: error)
            }
        }
    }

    private func verify(_ address: String) {
        guard !isBusy, code.count == 6 else { return }
        isBusy = true
        message = nil
        Task {
            defer { isBusy = false }
            do {
                try await account.verify(email: address, code: code)
                codeSentTo = nil
                code = ""
            } catch {
                message = text(for: error)
                code = ""
            }
        }
    }

    private func text(for error: Error) -> String {
        switch error as? Account.Failure {
        case .badEmail: "Проверьте адрес почты."
        case .wait(let seconds): "Подождите \(seconds) с и попробуйте снова."
        case .tooMany: "Слишком много попыток. Попробуйте позже."
        case .wrongCode: "Код не подходит."
        case .expired: "Код устарел. Запросите новый."
        case .mail: "Не удалось отправить письмо. Попробуйте позже."
        case .network, .none: "Нет связи с сервером. Проверьте интернет."
        }
    }
}
