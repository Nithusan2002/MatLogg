import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    private enum SessionStorageError: LocalizedError {
        case credentialDeletionFailed

        var errorDescription: String? {
            "Innloggingen ble avsluttet, men lagrede kontodata kunne ikke fjernes fra enheten."
        }
    }

    private static let debugUserId = UUID(uuid: (
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00,
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
    ))

    @Published private(set) var authState: AuthState = .notAuthenticated
    @Published private(set) var currentUser: User?
    @Published private(set) var isOnboarding = false
    @Published private(set) var isRestoringSession = true
    @Published private(set) var isLoading = false
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingLocalDataSummary: LocalDataSummary?
    @Published private(set) var pendingVerificationEmail: String?
    @Published private(set) var verificationMessage: String?

    @Published private(set) var pendingDeletion: PendingProfileDeletion?

    private let authRepository: any AccountAuthRepository
    private let localStore: any AuthSessionStore
    private let localProfileManager: any LocalProfileManaging
    private var pendingAccountSession: (user: User, localUser: User, shouldOnboard: Bool)?

    var isLocalMode: Bool { currentUser?.isLocalProfile == true }
    var authenticatedUser: User? {
        guard let currentUser, !currentUser.isLocalProfile else { return nil }
        return currentUser
    }

    convenience init() {
        let localStore = AuthService()
        let repository: any AccountAuthRepository
        if let configuration = try? SupabaseConfiguration.load() {
            repository = SupabaseService(configuration: configuration)
        } else {
            repository = UnavailableAccountAuthRepository()
        }
        self.init(authRepository: repository, localStore: localStore, localProfileManager: DatabaseService.shared)
    }

    convenience init(apiClient: any AuthAPIClient, sessionStore: any AuthSessionStore) {
        self.init(
            authRepository: LegacyAccountAuthRepository(apiClient: apiClient, sessionStore: sessionStore),
            localStore: sessionStore,
            localProfileManager: DatabaseService.shared
        )
    }

    convenience init(
        apiClient: any AuthAPIClient,
        sessionStore: any AuthSessionStore,
        localProfileManager: any LocalProfileManaging
    ) {
        self.init(
            authRepository: LegacyAccountAuthRepository(apiClient: apiClient, sessionStore: sessionStore),
            localStore: sessionStore,
            localProfileManager: localProfileManager
        )
    }

    init(
        authRepository: any AccountAuthRepository,
        localStore: any AuthSessionStore,
        localProfileManager: any LocalProfileManaging
    ) {
        self.authRepository = authRepository
        self.localStore = localStore
        self.localProfileManager = localProfileManager
        self.pendingDeletion = localStore.pendingProfileDeletion()
    }

    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }
        if let pendingDeletion, pendingDeletion.serverConfirmed || pendingDeletion.isLocalProfile {
            _ = await finishPendingLocalDeletion()
            return
        }
        if let restored = await authRepository.restoreSession() {
            let user = restored.preservingAppleNameSuggestion(previous: localStore.getStoredUser())
            localStore.storeUser(user)
            show(user: user, account: true)
        } else if let localUser = localStore.getActiveLocalProfile() {
            show(user: localUser, account: false)
        } else if localStore.getStoredUser() != nil {
            // A failed account restore must not silently replace its owner
            // with a fresh local profile and an apparently empty log.
            currentUser = nil
            isOnboarding = false
            authState = .notAuthenticated
        } else {
            continueLocally()
        }
    }

    func continueLocally() {
        guard pendingDeletion == nil else { return }
        errorMessage = nil
        pendingVerificationEmail = nil
        show(user: localStore.activateLocalProfile(), account: false)
    }

    func login(email: String, password: String) async {
        await authenticate { try await self.authRepository.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        guard canStartAccountOperation() else { return }
        isLoading = true
        errorMessage = nil
        verificationMessage = nil
        defer { isLoading = false }
        do {
            switch try await authRepository.signUp(email: email, password: password) {
            case .authenticated(let user):
                try await prepareAccountSession(user: user, shouldOnboard: true)
            case .pendingEmailVerification(let address):
                pendingVerificationEmail = address
                verificationMessage = "Vi har sendt en bekreftelseslenke til \(address)."
            }
        } catch {
            present(error)
        }
    }

    func resendEmailVerification() async {
        guard let pendingVerificationEmail, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        verificationMessage = nil
        defer { isLoading = false }
        do {
            try await authRepository.resendEmailVerification(to: pendingVerificationEmail)
            verificationMessage = "En ny bekreftelseslenke er sendt."
        } catch {
            errorMessage = UserFacingError.message(error, fallback: "Kontohandlingen kunne ikke fullføres. Prøv igjen.")
        }
    }

    func dismissEmailVerification() {
        pendingVerificationEmail = nil
        verificationMessage = nil
        errorMessage = nil
    }

    func loginWithApple(identityToken: String, authorizationCode: String?, nonce: String, sharedName: String? = nil) async {
        await authenticate {
            let user = try await self.authRepository.signInWithApple(identityToken: identityToken, nonce: nonce)
            return user.preservingAppleNameSuggestion(sharedName: sharedName, previous: self.localStore.getStoredUser())
        }
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == "matlogg", url.host == "auth", canStartAccountOperation() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await authRepository.handleAuthCallback(url)
            let shouldOnboard = pendingVerificationEmail != nil
                || localStore.onboardingCompletion(userId: user.id) == nil
            pendingVerificationEmail = nil
            verificationMessage = nil
            try await prepareAccountSession(user: user, shouldOnboard: shouldOnboard)
        } catch {
            errorMessage = "Bekreftelseslenken kunne ikke åpnes. Be om en ny lenke og prøv igjen."
        }
    }

    func reportAuthenticationError(_ message: String) {
        errorMessage = message
    }

    func confirmLocalDataLink() async {
        guard let pending = pendingAccountSession else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await localProfileManager.claimLocalData(from: pending.localUser.id, to: pending.user.id)
            let completedLocally = localStore.hasCompletedOnboarding(userId: pending.localUser.id)
            if completedLocally { localStore.setOnboardingCompleted(true, userId: pending.user.id) }
            completeAccountSession(
                user: pending.user,
                shouldOnboard: pending.shouldOnboard && !completedLocally
            )
            pendingAccountSession = nil
            pendingLocalDataSummary = nil
        } catch {
            errorMessage = "Kunne ikke knytte lokale data til kontoen. Ingen data ble flyttet."
        }
    }

    func cancelLocalDataLink() {
        guard let pending = pendingAccountSession else { return }
        Task { try? await authRepository.signOut() }
        pendingAccountSession = nil
        pendingLocalDataSummary = nil
        currentUser = pending.localUser
        isOnboarding = !localStore.hasCompletedOnboarding(userId: pending.localUser.id)
        authState = isOnboarding ? .onboarding(user: pending.localUser) : .local(user: pending.localUser)
    }

    func finishOnboarding() {
        guard let currentUser else { return }
        localStore.setOnboardingCompleted(true, userId: currentUser.id)
        isOnboarding = false
        authState = currentUser.isLocalProfile ? .local(user: currentUser) : .authenticated(user: currentUser)
    }

    @discardableResult
    func logout() -> Bool {
        let credentialsCleared = localStore.clearStoredCredentials()
        localStore.deactivateLocalMode()
        currentUser = nil
        isOnboarding = false
        pendingVerificationEmail = nil
        authState = .notAuthenticated
        errorMessage = credentialsCleared ? nil : SessionStorageError.credentialDeletionFailed.localizedDescription
        Task { try? await authRepository.signOut() }
        return credentialsCleared
    }

    func handleSessionExpired() {
        _ = localStore.clearStoredCredentials()
        localStore.deactivateLocalMode()
        currentUser = nil
        isOnboarding = false
        errorMessage = "Økten din er utløpt. Logg inn på nytt. Dataene på denne enheten er beholdt."
        authState = .notAuthenticated
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        guard !isDeletingAccount, !isLoading, let currentUser, !currentUser.isLocalProfile else { return false }
        isDeletingAccount = true
        errorMessage = nil
        defer { isDeletingAccount = false }
        if pendingDeletion?.serverConfirmed != true {
            savePendingDeletion(.init(ownerId: currentUser.id, isLocalProfile: false, serverConfirmed: false))
            do {
                _ = try await authRepository.deleteAccount()
                savePendingDeletion(.init(ownerId: currentUser.id, isLocalProfile: false, serverConfirmed: true))
            } catch {
                errorMessage = "Vi kunne ikke bekrefte kontoslettingen. Dataene på denne iPhonen er beholdt. Prøv igjen, eller kontakt oss hvis kontoen ikke lenger kan brukes."
                return false
            }
        }
        return await performPendingLocalDeletion()
    }

    /// Also available after restart, without a working account session.
    @discardableResult
    func finishPendingLocalDeletion() async -> Bool {
        guard !isDeletingAccount, pendingDeletion != nil else { return false }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        return await performPendingLocalDeletion()
    }

    private func performPendingLocalDeletion() async -> Bool {
        guard let deletion = pendingDeletion else { return false }
        do {
            try await localProfileManager.deleteLocalData(ownerId: deletion.ownerId)
            localStore.removeOnboardingCompletion(userId: deletion.ownerId)
            if deletion.isLocalProfile { localStore.consumeLocalProfile() }
            guard logout() else { return false }
            // The explicit recovery action completes local cleanup only.
            savePendingDeletion(nil)
            if !deletion.serverConfirmed && !deletion.isLocalProfile {
                errorMessage = "Lokale data er fjernet. Serverslettingen er ikke bekreftet. Kontakt oss for å kontrollere kontoslettingen."
            }
            return true
        } catch {
            errorMessage = "Lokale data kunne ikke slettes. Prøv lokal opprydding igjen; du trenger ikke logge inn."
            currentUser = nil
            isOnboarding = false
            authState = .notAuthenticated
            return false
        }
    }

    private func savePendingDeletion(_ deletion: PendingProfileDeletion?) {
        localStore.setPendingProfileDeletion(deletion)
        pendingDeletion = deletion
    }

    @discardableResult
    func removeAccountDataFromDevice() async -> Bool {
        guard !isDeletingAccount, !isLoading, let currentUser else { return false }
        if currentUser.isLocalProfile {
            savePendingDeletion(.init(ownerId: currentUser.id, isLocalProfile: true, serverConfirmed: false))
            return await finishPendingLocalDeletion()
        }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await localProfileManager.deleteLocalData(ownerId: currentUser.id)
            localStore.removeOnboardingCompletion(userId: currentUser.id)
            return logout()
        } catch {
            errorMessage = "Dataene kunne ikke fjernes fra denne iPhonen."
            return false
        }
    }

    func enableDebugSession() {
        guard currentUser == nil else { return }
        isRestoringSession = false
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

    private func canStartAccountOperation() -> Bool {
        guard pendingDeletion == nil, !isDeletingAccount else {
            errorMessage = "Fullfør lokal sletting før du logger inn på en konto."
            return false
        }
        return true
    }

    private func authenticate(operation: () async throws -> User) async {
        guard canStartAccountOperation() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let user = try await operation()
            // Account sign-in is an explicit exit from the optional first-use flow.
            try await prepareAccountSession(user: user, shouldOnboard: false)
        } catch {
            present(error)
        }
    }

    private func prepareAccountSession(user: User, shouldOnboard: Bool) async throws {
        if let localUser = currentUser, localUser.isLocalProfile {
            let summary = await localProfileManager.localDataSummary(ownerId: localUser.id)
            if summary.hasData {
                pendingAccountSession = (user, localUser, shouldOnboard)
                pendingLocalDataSummary = summary
                authState = .awaitingLocalDataLink(localUser: localUser, accountUser: user)
                return
            }
        }
        completeAccountSession(user: user, shouldOnboard: shouldOnboard)
    }

    private func completeAccountSession(user: User, shouldOnboard: Bool) {
        localStore.storeUser(user)
        localStore.consumeLocalProfile()
        currentUser = user
        localStore.setOnboardingCompleted(!shouldOnboard, userId: user.id)
        isOnboarding = shouldOnboard && !localStore.hasCompletedOnboarding(userId: user.id)
        authState = isOnboarding ? .onboarding(user: user) : .authenticated(user: user)
    }

    private func show(user: User, account: Bool) {
        currentUser = user
        if account, localStore.onboardingCompletion(userId: user.id) == nil {
            localStore.setOnboardingCompleted(true, userId: user.id)
        }
        isOnboarding = !(localStore.onboardingCompletion(userId: user.id) ?? false)
        if isOnboarding {
            authState = .onboarding(user: user)
        } else {
            authState = account ? .authenticated(user: user) : .local(user: user)
        }
    }

    private func present(_ error: Error) {
        errorMessage = UserFacingError.message(error, fallback: "Kontohandlingen kunne ikke fullføres. Prøv igjen.")
        if let currentUser {
            authState = currentUser.isLocalProfile ? .local(user: currentUser) : .authenticated(user: currentUser)
        } else {
            authState = .error(errorMessage ?? "Innloggingen kunne ikke fullføres. Prøv igjen.")
        }
    }
}
