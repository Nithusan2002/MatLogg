import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var authState: AuthState = .notAuthenticated
    @Published private(set) var currentUser: User?
    @Published private(set) var isOnboarding = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient: any AuthAPIClient
    private let sessionStore: any AuthSessionStore

    init(
        apiClient: any AuthAPIClient = APIService(),
        sessionStore: any AuthSessionStore = AuthService()
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
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

    func deleteAccount() async {
        // Backend deletion is not implemented yet; preserve the existing local logout behavior.
        logout()
    }

    func enableDebugSession() {
        guard currentUser == nil else { return }
        let user = User(
            id: UUID(),
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
