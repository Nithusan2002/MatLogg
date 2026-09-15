import Foundation

protocol AuthAPIClient {
    func loginEmail(email: String, password: String) async throws -> (User, String)
    func signupEmail(email: String, password: String, firstName: String, lastName: String) async throws -> (User, String)
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
