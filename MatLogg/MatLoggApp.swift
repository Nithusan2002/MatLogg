//
//  MatLoggApp.swift
//  MatLogg
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import SwiftUI

@main
struct MatLoggApp: App {
    @StateObject private var appState: AppState
    @StateObject private var logViewModel: LogViewModel
    @StateObject private var mealReuseViewModel: MealReuseViewModel
    @StateObject private var savedMealsViewModel: SavedMealsViewModel
    @StateObject private var productViewModel: ProductViewModel
    @StateObject private var healthProfileViewModel: HealthProfileViewModel
    @StateObject private var dailyGoalsViewModel: DailyGoalsViewModel
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var preferencesViewModel: PreferencesViewModel
    @StateObject private var userDataExportService: UserDataExportService
    @StateObject private var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    private let databaseStartupFailed: Bool

    init() {
        let databaseService = DatabaseService()
        let authService = AuthService()
        let refreshCoordinator = TokenRefreshCoordinator()
        let apiService = APIService(
            authSessionStore: authService,
            refreshCoordinator: refreshCoordinator
        )
        let syncEngine = SyncEngine(
            databaseService: databaseService,
            apiService: apiService,
            syncEnabled: { FeatureFlags.backendSyncEnabled }
        )
        databaseStartupFailed = !databaseService.isAvailable
        _appState = StateObject(wrappedValue: AppState(
            databaseService: databaseService,
            syncEngine: syncEngine
        ))
        _logViewModel = StateObject(wrappedValue: LogViewModel(repository: databaseService))
        _mealReuseViewModel = StateObject(wrappedValue: MealReuseViewModel(repository: databaseService))
        _savedMealsViewModel = StateObject(wrappedValue: SavedMealsViewModel(
            savedMealRepository: databaseService,
            foodLogRepository: databaseService
        ))
        _productViewModel = StateObject(wrappedValue: ProductViewModel(repository: databaseService))
        let healthProfile = HealthProfileViewModel(repository: databaseService)
        _healthProfileViewModel = StateObject(wrappedValue: healthProfile)
        _dailyGoalsViewModel = StateObject(wrappedValue: DailyGoalsViewModel(
            repository: databaseService, onSaved: healthProfile.acceptSavedGoal
        ))
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            apiClient: apiService,
            sessionStore: authService,
            localDataResetter: databaseService
        ))
        _preferencesViewModel = StateObject(wrappedValue: PreferencesViewModel())
        _userDataExportService = StateObject(wrappedValue: UserDataExportService(
            logRepository: databaseService,
            savedMealRepository: databaseService
        ))
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor())
    }
    
    var body: some Scene {
        WindowGroup {
            rootContent
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if databaseStartupFailed {
            ContentUnavailableView {
                Label("Kan ikke åpne MatLogg", systemImage: "externaldrive.badge.xmark")
            } description: {
                Text("Den lokale databasen kunne ikke åpnes. Dataene er ikke slettet. Avslutt appen og prøv igjen.")
            }
        } else {
            operationalContent
        }
    }

    private var operationalContent: some View {
        configuredContent
            .onChange(of: authViewModel.currentUser?.id) { _, userId in
                appState.updateAuthenticatedUser(userId)
                mealReuseViewModel.reset()
                savedMealsViewModel.reset()
                if let userId {
                    Task {
                        guard authViewModel.currentUser?.id == userId else { return }
                        await mealReuseViewModel.load(userId: userId)
                        await savedMealsViewModel.load(userId: userId)
                    }
                }
            }
            .alert(item: $appState.activeError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK")) { appState.activeError = nil }
                )
            }
            .onAppear {
                if skipAuthForDev {
                    authViewModel.enableDebugSession()
                }
                appState.updateAuthenticatedUser(authViewModel.currentUser?.id)
                appState.updateNetworkAvailability(isConnected: networkMonitor.isConnected)
                Task { await appState.triggerSync(reason: .appLaunch) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await appState.triggerSync(reason: .foreground) }
                }
            }
            .onChange(of: networkMonitor.restorationCount) { oldValue, newValue in
                guard newValue > oldValue else { return }
                Task { await appState.triggerSync(reason: .networkRestored) }
            }
            .onChange(of: networkMonitor.isConnected) { _, isConnected in
                appState.updateNetworkAvailability(isConnected: isConnected)
            }
            .onReceive(NotificationCenter.default.publisher(for: .authSessionExpired)) { _ in
                authViewModel.handleSessionExpired()
            }
            .task(id: authViewModel.currentUser?.id) { await loadHealthProfile() }
    }

    private func loadHealthProfile() async {
        if let userId = authViewModel.currentUser?.id {
            await healthProfileViewModel.loadGoal(userId: userId)
            #if DEBUG
            if authViewModel.currentUser?.authProvider == "debug" {
                healthProfileViewModel.useDevelopmentGoalIfMissing(
                    userId: userId,
                    safeModeEnabled: preferencesViewModel.safeModeEnabled
                )
            }
            #endif
        } else {
            healthProfileViewModel.resetUserState()
        }
    }

    private var configuredContent: some View {
        Group {
            if skipAuthForDev {
                HomeView()
            } else if authViewModel.currentUser != nil {
                if authViewModel.isOnboarding {
                    OnboardingView()
                } else {
                    HomeView()
                }
            } else {
                LoginView()
            }
        }
        .environmentObject(appState)
        .environmentObject(logViewModel)
        .environmentObject(mealReuseViewModel)
        .environmentObject(savedMealsViewModel)
        .environmentObject(productViewModel)
        .environmentObject(healthProfileViewModel)
        .environmentObject(dailyGoalsViewModel)
        .environmentObject(authViewModel)
        .environmentObject(preferencesViewModel)
        .environmentObject(userDataExportService)
    }

    private var skipAuthForDev: Bool {
        #if DEBUG
        // Debug builds bypass authentication while the app is under active
        // development. Use --show-auth to exercise the real auth flow.
        return !ProcessInfo.processInfo.arguments.contains("--show-auth")
        #else
        return false
        #endif
    }
}
