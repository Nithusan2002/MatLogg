import Foundation

nonisolated struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
}

protocol AuthAPIClient {
    func loginEmail(email: String, password: String) async throws -> (User, AuthTokens)
    func signupEmail(email: String, password: String, firstName: String, lastName: String) async throws -> (User, AuthTokens)
    func revokeRefreshToken(_ refreshToken: String) async throws
    func deleteAccount() async throws -> AccountDeletionReceipt
}

extension APIService: AuthAPIClient {}

protocol AuthSessionStore {
    func storeUser(_ user: User)
    func getStoredUser() -> User?
    @discardableResult func storeToken(_ token: String) -> Bool
    func getStoredToken() -> String?
    @discardableResult func storeTokens(_ tokens: AuthTokens) -> Bool
    func getStoredRefreshToken() -> String?
    @discardableResult func clearStoredCredentials() -> Bool
}

extension AuthService: AuthSessionStore {}

extension Notification.Name {
    static let authSessionExpired = Notification.Name("matlogg.authSessionExpired")
}

struct AccountDeletionReceipt: Codable, Equatable {
    let code: String
    let message: String
    let permanentDeletionAt: Date
}

protocol LocalDataResetting {
    func resetAllLocalData() async throws
}

extension DatabaseService: LocalDataResetting {}
