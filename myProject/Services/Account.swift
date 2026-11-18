import Foundation
import Security

/// Аккаунт WordLearner: почта и пароль (сервер wordlearner-account). Почту при регистрации и сбросе пароля подтверждает код из письма.
/// Ключ входа лежит в связке ключей, почта — в настройках для показа. Вход не обязателен: без него приложение работает как раньше
@Observable
final class Account {
    static let shared = Account()

    nonisolated private static let baseURL = URL(string: "https://wordlearner-account.abalmazspartak.workers.dev")!
    private static let emailKey = "account_email"
    nonisolated private static let keychainService = "com.personalteam.lexistream.account"

    private(set) var email: String?

    enum Failure: Error {
        case badEmail
        /// Подождать столько секунд до нового письма
        case wait(Int)
        case tooMany
        case wrongCode
        case expired
        case weakPassword
        case wrongPassword
        /// Вход закрыт после неверных попыток; столько секунд ждать
        case locked(Int)
        /// Почтовый сервис не отправил письмо
        case mail
        case network
    }

    static let minPassword = 8

    var isSignedIn: Bool { email != nil && Self.token != nil }

    private init() {
        email = Self.token == nil ? nil : UserDefaults.standard.string(forKey: Self.emailKey)
    }

    // MARK: - Регистрация и сброс пароля

    /// Просит сервер отправить код на почту: так подтверждается адрес при регистрации и сбросе пароля
    func requestCode(email: String) async throws {
        let (status, body) = try await Self.post("auth/request", ["email": email])
        switch status {
        case 200: return
        case 400: throw Failure.badEmail
        case 429: throw body["error"] as? String == "wait" ? Failure.wait(body["wait"] as? Int ?? 30) : Failure.tooMany
        case 502, 503: throw Failure.mail
        default: throw Failure.network
        }
    }

    /// Проверяет код; возвращает разрешение задать пароль
    func verify(email: String, code: String) async throws -> String {
        let (status, body) = try await Self.post("auth/verify", ["email": email, "code": code])
        switch status {
        case 200:
            guard let ticket = body["ticket"] as? String else { throw Failure.network }
            return ticket
        case 400: throw Failure.wrongCode
        case 401:
            switch body["error"] as? String {
            case "expired": throw Failure.expired
            case "too_many": throw Failure.tooMany
            default: throw Failure.wrongCode
            }
        case 429: throw Failure.tooMany
        default: throw Failure.network
        }
    }

    /// Задаёт пароль по разрешению и входит
    func setPassword(email: String, ticket: String, password: String) async throws {
        let (status, body) = try await Self.post("auth/password", ["email": email, "ticket": ticket, "password": password])
        switch status {
        case 200: try accept(body, fallback: email)
        case 400: throw Failure.weakPassword
        case 401: throw Failure.expired
        case 429: throw Failure.tooMany
        default: throw Failure.network
        }
    }

    // MARK: - Вход

    func signIn(email: String, password: String) async throws {
        let (status, body) = try await Self.post("auth/login", ["email": email, "password": password])
        switch status {
        case 200: try accept(body, fallback: email)
        case 400, 401: throw Failure.wrongPassword
        case 429:
            if body["error"] as? String == "locked" { throw Failure.locked(body["wait"] as? Int ?? 900) }
            throw Failure.tooMany
        default: throw Failure.network
        }
    }

    /// Смена пароля: другие устройства войдут заново
    func changePassword(old: String, new: String) async throws {
        guard let token = Self.token else { throw Failure.network }
        let (status, body) = try await Self.post("me/password", ["old": old, "password": new], token: token)
        switch status {
        case 200: return
        case 400: throw Failure.weakPassword
        case 401:
            // Ключ устарел (пароль сменили на другом устройстве) — нужен новый вход
            if body["error"] as? String == "unauthorized" { await signOut() }
            throw Failure.wrongPassword
        case 429:
            if body["error"] as? String == "locked" { throw Failure.locked(body["wait"] as? Int ?? 900) }
            throw Failure.tooMany
        default: throw Failure.network
        }
    }

    private func accept(_ body: [String: Any], fallback: String) throws {
        guard let token = body["token"] as? String else { throw Failure.network }
        Self.token = token
        let confirmed = body["email"] as? String ?? fallback
        UserDefaults.standard.set(confirmed, forKey: Self.emailKey)
        email = confirmed
    }

    /// Выход на этом устройстве: ключ стирается здесь и закрывается на сервере (если есть сеть)
    func signOut() async {
        if let token = Self.token {
            var request = URLRequest(url: Self.baseURL.appending(path: "auth/logout"), timeoutInterval: 10)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        Self.token = nil
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        email = nil
    }

    /// Ключ входа для будущих запросов синхронизации
    nonisolated static var authorization: String? { token.map { "Bearer \($0)" } }

    // MARK: - Сеть

    nonisolated private static func post(_ path: String, _ fields: [String: String], token: String? = nil) async throws -> (Int, [String: Any]) {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 15)
        request.httpMethod = "POST"
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(fields)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else { throw Failure.network }
        return (status, (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:])
    }

    // MARK: - Связка ключей

    nonisolated private static var token: String? {
        get {
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
                                        kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var result: AnyObject?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService]
            SecItemDelete(base as CFDictionary)
            guard let newValue, let data = newValue.data(using: .utf8) else { return }
            var item = base
            item[kSecValueData as String] = data
            // Доступен после первой разблокировки и не переезжает на другое устройство вместе с копией
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
