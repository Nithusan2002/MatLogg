import Foundation

enum AccountRegistrationResult {
    case authenticated(User)
    case pendingEmailVerification(email: String)
}

protocol AccountAuthRepository {
    func restoreSession() async -> User?
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> AccountRegistrationResult
    func resendEmailVerification(to email: String) async throws
    func signInWithApple(identityToken: String, nonce: String) async throws -> User
    func handleAuthCallback(_ url: URL) async throws -> User
    func signOut() async throws
    func deleteAccount() async throws -> AccountDeletionReceipt
}

nonisolated struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
}

protocol AuthAPIClient {
    func loginEmail(email: String, password: String) async throws -> (User, AuthTokens)
    func signupEmail(email: String, password: String) async throws -> (User, AuthTokens)
    func loginApple(identityToken: String, authorizationCode: String?, nonce: String) async throws -> (User, AuthTokens)
    func revokeRefreshToken(_ refreshToken: String) async throws
    func deleteAccount() async throws -> AccountDeletionReceipt
}

extension APIService: AuthAPIClient {}

final class LegacyAccountAuthRepository: AccountAuthRepository {
    private let apiClient: any AuthAPIClient
    private let sessionStore: any AuthSessionStore

    init(apiClient: any AuthAPIClient, sessionStore: any AuthSessionStore) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
    }

    func restoreSession() async -> User? {
        guard sessionStore.getStoredToken() != nil else { return nil }
        return sessionStore.getStoredUser()
    }

    func signIn(email: String, password: String) async throws -> User {
        try persist(try await apiClient.loginEmail(email: email, password: password))
    }

    func signUp(email: String, password: String) async throws -> AccountRegistrationResult {
        .authenticated(try persist(try await apiClient.signupEmail(email: email, password: password)))
    }

    func resendEmailVerification(to email: String) async throws {
        throw AccountAuthError.unsupportedOperation
    }

    func signInWithApple(identityToken: String, nonce: String) async throws -> User {
        try persist(try await apiClient.loginApple(identityToken: identityToken, authorizationCode: nil, nonce: nonce))
    }

    func handleAuthCallback(_ url: URL) async throws -> User {
        throw AccountAuthError.unsupportedOperation
    }

    func signOut() async throws {
        if let refreshToken = sessionStore.getStoredRefreshToken() {
            try? await apiClient.revokeRefreshToken(refreshToken)
        }
    }

    func deleteAccount() async throws -> AccountDeletionReceipt {
        try await apiClient.deleteAccount()
    }

    private func persist(_ response: (User, AuthTokens)) throws -> User {
        guard sessionStore.storeTokens(response.1) else {
            _ = sessionStore.clearStoredCredentials()
            throw AccountAuthError.credentialPersistenceFailed
        }
        sessionStore.storeUser(response.0)
        return response.0
    }
}

enum AccountAuthError: LocalizedError {
    case configurationMissing
    case credentialPersistenceFailed
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Kontotjenesten er ikke konfigurert. Du kan fortsatt bruke MatLogg lokalt."
        case .credentialPersistenceFailed:
            "Innloggingen kunne ikke lagres sikkert på enheten. Prøv igjen."
        case .unsupportedOperation:
            "Denne kontohandlingen er ikke tilgjengelig i den valgte konfigurasjonen."
        }
    }
}

nonisolated struct PendingProfileDeletion: Codable, Equatable, Sendable {
    let ownerId: UUID
    let isLocalProfile: Bool
    var serverConfirmed: Bool
}

protocol AuthSessionStore {
    func pendingProfileDeletion() -> PendingProfileDeletion?
    func setPendingProfileDeletion(_ deletion: PendingProfileDeletion?)
    func removeOnboardingCompletion(userId: UUID)
    func storeUser(_ user: User)
    func getStoredUser() -> User?
    @discardableResult func storeToken(_ token: String) -> Bool
    func getStoredToken() -> String?
    @discardableResult func storeTokens(_ tokens: AuthTokens) -> Bool
    func getStoredRefreshToken() -> String?
    @discardableResult func clearStoredCredentials() -> Bool
    func activateLocalProfile() -> User
    func getActiveLocalProfile() -> User?
    func consumeLocalProfile()
    func deactivateLocalMode()
    func hasCompletedOnboarding(userId: UUID) -> Bool
    func onboardingCompletion(userId: UUID) -> Bool?
    func setOnboardingCompleted(_ completed: Bool, userId: UUID)
}

extension AuthService: AuthSessionStore {}

extension Notification.Name {
    static let authSessionExpired = Notification.Name("matlogg.authSessionExpired")
}

nonisolated struct AccountDeletionReceipt: Codable, Equatable, Sendable {
    let code: String
    let message: String
    let permanentDeletionAt: Date
}

protocol LocalProfileManaging {
    func localDataSummary(ownerId: UUID) async -> LocalDataSummary
    func claimLocalData(from localOwnerId: UUID, to accountOwnerId: UUID) async throws
    func deleteLocalData(ownerId: UUID) async throws
}

extension DatabaseService: LocalProfileManaging {}
