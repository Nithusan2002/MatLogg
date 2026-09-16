import Foundation

protocol AuthAPIClient {
    func loginEmail(email: String, password: String) async throws -> (User, String)
    func signupEmail(email: String, password: String, firstName: String, lastName: String) async throws -> (User, String)
    func deleteAccount() async throws -> AccountDeletionReceipt
}

extension APIService: AuthAPIClient {}

protocol AuthSessionStore {
    func storeUser(_ user: User)
    func getStoredUser() -> User?
    func storeToken(_ token: String)
    func getStoredToken() -> String?
    func clearStoredCredentials()
}

extension AuthService: AuthSessionStore {}

struct AccountDeletionReceipt: Codable, Equatable {
    let code: String
    let message: String
    let permanentDeletionAt: Date
}

protocol LocalDataResetting {
    func resetAllLocalData() async throws
}

extension DatabaseService: LocalDataResetting {}
