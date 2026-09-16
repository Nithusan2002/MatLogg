import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    private static let debugUserId = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    @Published private(set) var authState: AuthState = .notAuthenticated
    @Published private(set) var currentUser: User?
    @Published private(set) var isOnboarding = false
    @Published private(set) var isLoading = false
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var errorMessage: String?

    private let apiClient: any AuthAPIClient
    private let sessionStore: any AuthSessionStore
    private let localDataResetter: any LocalDataResetting

    convenience init() {
        let sessionStore = AuthService()
        self.init(
            apiClient: APIService(accessTokenProvider: { sessionStore.getStoredToken() }),
            sessionStore: sessionStore,
            localDataResetter: DatabaseService.shared
        )
    }

    convenience init(
        apiClient: any AuthAPIClient,
        sessionStore: any AuthSessionStore
    ) {
        self.init(apiClient: apiClient, sessionStore: sessionStore, localDataResetter: DatabaseService.shared)
    }

    init(
        apiClient: any AuthAPIClient,
        sessionStore: any AuthSessionStore,
        localDataResetter: any LocalDataResetting
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
        self.localDataResetter = localDataResetter
        restoreSession()
    }

    func restoreSession() {
        guard let user = sessionStore.getStoredUser(),
              sessionStore.getStoredToken() != nil else {
            currentUser = nil
            authState = .notAuthenticated
            return
        }
        currentUser = user
        authState = .authenticated(user: user)
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (user, token) = try await apiClient.loginEmail(email: email, password: password)
            sessionStore.storeUser(user)
            sessionStore.storeToken(token)
            currentUser = user
            authState = .authenticated(user: user)
            isOnboarding = false
        } catch {
            errorMessage = error.localizedDescription
            authState = .error(error.localizedDescription)
        }
    }

    func signUp(email: String, password: String, firstName: String, lastName: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (user, token) = try await apiClient.signupEmail(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            sessionStore.storeUser(user)
            sessionStore.storeToken(token)
            currentUser = user
            authState = .onboarding(user: user)
            isOnboarding = true
        } catch {
            errorMessage = error.localizedDescription
            authState = .error(error.localizedDescription)
        }
    }

    func finishOnboarding() {
        guard let currentUser else { return }
        isOnboarding = false
        authState = .authenticated(user: currentUser)
    }

    func logout() {
        sessionStore.clearStoredCredentials()
        currentUser = nil
        isOnboarding = false
        authState = .notAuthenticated
        errorMessage = nil
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        guard !isDeletingAccount else { return false }
        isDeletingAccount = true
        errorMessage = nil
        defer { isDeletingAccount = false }
        do {
            _ = try await apiClient.deleteAccount()
            try await localDataResetter.resetAllLocalData()
            logout()
            return true
        } catch {
            errorMessage = "Kontoen kunne ikke slettes. Ingen lokale data ble fjernet. \(error.localizedDescription)"
            return false
        }
    }

    func enableDebugSession() {
        guard currentUser == nil else { return }
        let user = User(
            id: Self.debugUserId,
            email: "dev@matlogg.app",
            firstName: "Dev",
            lastName: "User",
            authProvider: "debug",
            createdAt: Date()
        )
        currentUser = user
        isOnboarding = false
        authState = .authenticated(user: user)
    }
}
