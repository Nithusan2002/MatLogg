import Foundation
import Combine

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
    case pendingLinkAccountMismatch

    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            "Kontotjenesten er ikke konfigurert. Du kan fortsatt bruke Spor Mat lokalt."
        case .credentialPersistenceFailed:
            "Innloggingen kunne ikke lagres sikkert på enheten. Prøv igjen."
        case .pendingLinkAccountMismatch:
            "Denne profilen venter på kobling til en annen konto. Logg inn på den kontoen eller avbryt koblingen."
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

nonisolated struct PendingLocalDataLink: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable { case awaitingConfirmation, confirmed, canceling }
    let localOwnerId: UUID
    let accountOwnerId: UUID
    let shouldOnboard: Bool
    var phase: Phase = .awaitingConfirmation
}

protocol AuthSessionStore {
    func pendingLocalDataLink() -> PendingLocalDataLink?
    func setPendingLocalDataLink(_ link: PendingLocalDataLink?)
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

#if DEBUG
/// Isolated synthetic context for testing interrupted linking without Apple or a network session.
@MainActor
final class LocalDataLinkQAFixture: ObservableObject {
    struct Context {
        let database: DatabaseService
        let defaults: UserDefaults
        let repository: any AccountAuthRepository
        let mode: DemoMode
    }
    @Published private(set) var context: Context?
    @Published private(set) var errorMessage: String?

    func load() {
        guard context == nil else { return }
        do {
            let directory = URL.applicationSupportDirectory.appendingPathComponent("LocalDataLinkQA", isDirectory: true)
            guard let defaults = UserDefaults(suiteName: "app.matlogg.local-link-qa") else {
                throw AccountAuthError.credentialPersistenceFailed
            }
            if ProcessInfo.processInfo.arguments.contains("--local-link-qa-reset") {
                defaults.removePersistentDomain(forName: "app.matlogg.local-link-qa")
                if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try LocalStore(databaseURL: directory.appendingPathComponent("qa.sqlite"))
            let repository = LocalDataLinkQAAuthRepository(defaults: defaults)
            let auth = AuthService(defaults: defaults)
            if defaults.object(forKey: "seeded") == nil {
                let local = auth.activateLocalProfile()
                auth.setOnboardingCompleted(true, userId: local.id)
                let product = Product(name: "Kontokobling testmat", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
                try store.saveProduct(product, ownerUserId: local.id)
                try store.saveLog(FoodLog(userId: local.id, productId: product.id, mealType: "lunsj", amountG: 100,
                    loggedDate: Date(), calories: 100, proteinG: 1, carbsG: 2, fatG: 3))
                auth.setPendingLocalDataLink(.init(localOwnerId: local.id, accountOwnerId: repository.user.id, shouldOnboard: false))
                defaults.set(try JSONEncoder().encode(PersonalDetails(displayName: "Eldre testnavn", heightCm: 178)), forKey: "personalDetails")
                defaults.set(true, forKey: "session")
                defaults.set(true, forKey: "seeded")
            }
            let database = DatabaseService(store: store, defaults: defaults)
            let mode = DemoMode(selectionDefaults: defaults, demoDefaults: defaults, directory: directory,
                openDatabase: { database })
            context = Context(database: database, defaults: defaults, repository: repository, mode: mode)
        } catch { errorMessage = "Testoppsettet kunne ikke åpnes." }
    }
}

private final class LocalDataLinkQAAuthRepository: AccountAuthRepository {
    let user = User(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 64, 0, 128, 0, 0, 0, 0, 0, 0, 42)),
        email: "local-link@example.invalid", firstName: "", lastName: "", authProvider: "apple", createdAt: Date())
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    func restoreSession() async -> User? { defaults.bool(forKey: "session") ? user : nil }
    func signIn(email: String, password: String) async throws -> User { throw AccountAuthError.unsupportedOperation }
    func signUp(email: String, password: String) async throws -> AccountRegistrationResult { throw AccountAuthError.unsupportedOperation }
    func resendEmailVerification(to email: String) async throws { throw AccountAuthError.unsupportedOperation }
    func signInWithApple(identityToken: String, nonce: String) async throws -> User { throw AccountAuthError.unsupportedOperation }
    func handleAuthCallback(_ url: URL) async throws -> User { throw AccountAuthError.unsupportedOperation }
    func signOut() async throws { defaults.set(false, forKey: "session") }
    func deleteAccount() async throws -> AccountDeletionReceipt { throw AccountAuthError.unsupportedOperation }
}
#endif
