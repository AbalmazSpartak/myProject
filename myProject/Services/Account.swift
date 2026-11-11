import Foundation
import Security

/// Аккаунт WordLearner: вход по почте с одноразовым кодом (сервер wordlearner-account).
/// Ключ входа лежит в связке ключей, почта — в настройках для показа. Вход не обязателен: без него приложение работает как раньше
@Observable
final class Account {
    static let shared = Account()

    nonisolated private static let baseURL = URL(string: "https://wordlearner-account.abalmazspartak.workers.dev")!
    private static let emailKey = "account_email"
    nonisolated private static let keychainService = "com.personalteam.myProject.account"

    private(set) var email: String?

    enum Failure: Error {
        case badEmail
        /// Подождать столько секунд до нового письма
        case wait(Int)
        case tooMany
        case wrongCode
        case expired
        /// Почтовый сервис не отправил письмо
        case mail
        case network
    }

    var isSignedIn: Bool { email != nil && Self.token != nil }

    private init() {
        email = Self.token == nil ? nil : UserDefaults.standard.string(forKey: Self.emailKey)
    }

    // MARK: - Вход

    /// Просит сервер отправить код на почту
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

    /// Проверяет код; при успехе устройство входит в аккаунт
    func verify(email: String, code: String) async throws {
        let (status, body) = try await Self.post("auth/verify", ["email": email, "code": code])
        switch status {
        case 200:
            guard let token = body["token"] as? String else { throw Failure.network }
            Self.token = token
            let confirmed = body["email"] as? String ?? email
            UserDefaults.standard.set(confirmed, forKey: Self.emailKey)
            self.email = confirmed
        case 400: throw Failure.wrongCode
        case 401:
            switch body["error"] as? String {
            case "expired": throw Failure.expired
            case "too_many": throw Failure.tooMany
            default: throw Failure.wrongCode
            }
        default: throw Failure.network
        }
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

    nonisolated private static func post(_ path: String, _ fields: [String: String]) async throws -> (Int, [String: Any]) {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 15)
        request.httpMethod = "POST"
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
