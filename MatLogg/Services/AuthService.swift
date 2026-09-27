import Foundation
import Security

protocol KeychainClient {
    func add(_ attributes: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus
    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, data: Data?)
    func delete(_ query: [String: Any]) -> OSStatus
}

struct SystemKeychainClient: KeychainClient {
    func add(_ attributes: [String: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, data: Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

final class AuthService {
    private static let keychainService = "app.matlogg.auth"
    private static let legacyTokenAccount = "matlogg_auth"

    private let userDefaultsKey = "ml_current_user"
    private let tokenKeychainKey = "ml_auth_token"
    private let defaults: UserDefaults
    private let keychain: any KeychainClient

    init(
        defaults: UserDefaults = .standard,
        keychain: any KeychainClient = SystemKeychainClient()
    ) {
        self.defaults = defaults
        self.keychain = keychain
    }
    
    func storeUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func getStoredUser() -> User? {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }
        return user
    }

    @discardableResult
    func storeToken(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        return storeCredentialData(Data(token.utf8))
    }

    @discardableResult
    func storeTokens(_ tokens: AuthTokens) -> Bool {
        guard !tokens.accessToken.isEmpty,
              tokens.refreshToken?.isEmpty != true,
              let tokenData = try? JSONEncoder().encode(tokens) else {
            return false
        }
        return storeCredentialData(tokenData)
    }

    private func storeCredentialData(_ tokenData: Data) -> Bool {

        let attributes: [String: Any] = [
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = keychain.update(tokenQuery, attributes: attributes)
        if updateStatus == errSecSuccess {
            _ = keychain.delete(legacyTokenQuery)
            return true
        }
        guard updateStatus == errSecItemNotFound else {
            return false
        }

        guard keychain.add(tokenQuery.merging(attributes) { _, new in new }) == errSecSuccess else {
            return false
        }
        _ = keychain.delete(legacyTokenQuery)
        return true
    }
    
    func getStoredToken() -> String? {
        let query = tokenQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        let result = keychain.copyMatching(query)

        if result.status == errSecSuccess,
           let data = result.data,
           let credentials = try? JSONDecoder().decode(AuthTokens.self, from: data) {
            return credentials.accessToken
        }
        if let token = decodedToken(from: result) {
            return token
        }
        guard result.status == errSecItemNotFound else { return nil }

        let legacyResult = keychain.copyMatching(legacyTokenQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new })
        guard let legacyToken = decodedToken(from: legacyResult) else { return nil }
        _ = storeToken(legacyToken)
        return legacyToken
    }

    func getStoredRefreshToken() -> String? {
        let query = tokenQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        let result = keychain.copyMatching(query)
        guard result.status == errSecSuccess,
              let data = result.data,
              let credentials = try? JSONDecoder().decode(AuthTokens.self, from: data) else {
            return nil
        }
        return credentials.refreshToken
    }
    
    @discardableResult
    func clearStoredCredentials() -> Bool {
        defaults.removeObject(forKey: userDefaultsKey)
        let currentStatus = keychain.delete(tokenQuery)
        let legacyStatus = keychain.delete(legacyTokenQuery)
        return isSuccessfulDeletion(currentStatus) && isSuccessfulDeletion(legacyStatus)
    }

    private var tokenQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: tokenKeychainKey
        ]
    }

    private var legacyTokenQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.legacyTokenAccount
        ]
    }

    private func decodedToken(from result: (status: OSStatus, data: Data?)) -> String? {
        guard result.status == errSecSuccess,
              let data = result.data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    private func isSuccessfulDeletion(_ status: OSStatus) -> Bool {
        status == errSecSuccess || status == errSecItemNotFound
    }
}
