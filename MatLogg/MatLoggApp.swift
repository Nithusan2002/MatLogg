//
//  MatLoggApp.swift
//  MatLogg
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import SwiftUI

struct MatLoggContent: View {
    @StateObject private var appState: AppState
    @StateObject private var logViewModel: LogViewModel
    @StateObject private var mealReuseViewModel: MealReuseViewModel
    @StateObject private var waterViewModel: WaterViewModel
    @StateObject private var savedMealsViewModel: SavedMealsViewModel
    @StateObject private var productViewModel: ProductViewModel
    @StateObject private var healthProfileViewModel: HealthProfileViewModel
    @StateObject private var profileFavoritesViewModel: ProfileFavoritesViewModel
    @StateObject private var personalDetailsViewModel: PersonalDetailsViewModel
    @StateObject private var dailyGoalsViewModel: DailyGoalsViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var preferencesViewModel: PreferencesViewModel
    @StateObject private var profileExportViewModel: ProfileExportViewModel
    @StateObject private var networkMonitor: NetworkMonitor
    @Environment(\.scenePhase) private var scenePhase
    private let foodSearchRepository: any FoodSearchRepository
    private let databaseStartupFailed: Bool
    private let databaseStartupDetail: String?

    private let isDemo: Bool

    init(databaseService: DatabaseService = DatabaseService(), defaults: UserDefaults = .standard, isDemo: Bool = false) {
        self.isDemo = isDemo
        foodSearchRepository = DefaultFoodSearchRepository(
            products: databaseService, catalog: MatvaretabellenService(), remote: APIService()
        )
        let localAuthStore = AuthService(defaults: defaults)
        let authRepository: any AccountAuthRepository
        let syncAPIClient: any SyncAPIClient
        if !isDemo, let configuration = try? SupabaseConfiguration.load() {
            let supabaseService = SupabaseService(configuration: configuration)
            authRepository = supabaseService
            syncAPIClient = supabaseService
        } else {
            authRepository = UnavailableAccountAuthRepository()
            syncAPIClient = UnavailableSyncAPIClient()
        }
        let syncEngine = SyncEngine(
            databaseService: databaseService,
            apiService: syncAPIClient,
            syncEnabled: { !isDemo && FeatureFlags.backendSyncEnabled }
        )
        databaseStartupFailed = !databaseService.isAvailable
        if let error = databaseService.startupError,
           case LocalStoreError.unsupportedSchema(let version) = error {
            databaseStartupDetail = "Databasen har versjon \(version). Denne appen støtter versjon \(LocalStore.latestSchemaVersion). Bruk en appversjon som støtter databasen."
        } else {
            databaseStartupDetail = nil
        }
        _appState = StateObject(wrappedValue: AppState(
            databaseService: databaseService,
            syncEngine: syncEngine
        ))
        _waterViewModel = StateObject(wrappedValue: WaterViewModel(repository: databaseService))
        _logViewModel = StateObject(wrappedValue: LogViewModel(repository: databaseService))
        _mealReuseViewModel = StateObject(wrappedValue: MealReuseViewModel(repository: databaseService))
        _savedMealsViewModel = StateObject(wrappedValue: SavedMealsViewModel(
            savedMealRepository: databaseService,
            foodLogRepository: databaseService,
            photoRepository: LocalMealPhotoRepository()
        ))
        let productAPI = APIService()
        let barcodeRepository = DefaultBarcodeLookupRepository(products: databaseService, remote: productAPI)
        _productViewModel = StateObject(wrappedValue: ProductViewModel(
            repository: databaseService, catalogService: MatvaretabellenService(),
            barcodeService: productAPI, nameSearchService: productAPI,
            barcodeRepository: barcodeRepository
        ))
        _profileFavoritesViewModel = StateObject(wrappedValue: ProfileFavoritesViewModel(repository: databaseService))
        let healthProfile = HealthProfileViewModel(repository: databaseService, personalDetailsStore: UserDefaultsPersonalDetailsStore(defaults: defaults))
        _healthProfileViewModel = StateObject(wrappedValue: healthProfile)
        _personalDetailsViewModel = StateObject(wrappedValue: PersonalDetailsViewModel(
            store: UserDefaultsPersonalDetailsStore(defaults: defaults), onSaved: healthProfile.acceptSavedPersonalDetails
        ))
        _dailyGoalsViewModel = StateObject(wrappedValue: DailyGoalsViewModel(
            repository: databaseService, onSaved: healthProfile.acceptSavedGoal
        ))
        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(
            goalRepository: databaseService, personalDetailsStore: UserDefaultsPersonalDetailsStore(defaults: defaults)
        ))
        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            authRepository: authRepository,
            localStore: localAuthStore,
            localProfileManager: databaseService
        ))
        _preferencesViewModel = StateObject(wrappedValue: PreferencesViewModel(defaults: defaults))
        _profileExportViewModel = StateObject(wrappedValue: ProfileExportViewModel(exporter: UserDataExportService(
            logRepository: databaseService,
            savedMealRepository: databaseService,
            waterRepository: databaseService,
            healthRepository: databaseService,
            productRepository: databaseService,
            personalDetailsStore: UserDefaultsPersonalDetailsStore(defaults: defaults)
        )))
        _networkMonitor = StateObject(wrappedValue: NetworkMonitor())
    }
    
    var body: some View { rootContent }

    @ViewBuilder
    private var rootContent: some View {
        if databaseStartupFailed {
            ContentUnavailableView {
                Label("Kan ikke åpne MatLogg", systemImage: "externaldrive.badge.xmark")
            } description: {
                if let databaseStartupDetail {
                    Text("Den lokale databasen kunne ikke åpnes. Dataene er ikke slettet. \(databaseStartupDetail)")
                } else {
                    Text("Den lokale databasen kunne ikke åpnes. Dataene er ikke slettet. Avslutt appen og prøv igjen.")
                }
            }
        } else {
            operationalContent
        }
    }

    private var operationalContent: some View {
        configuredContent
            .onChange(of: waterViewModel.mutationRevision) { _, _ in
                Task { await appState.refreshSyncStatus() }
            }
            .onDisappear { appState.updateAuthenticatedUser(nil) }
            .onChange(of: authViewModel.currentUser?.id) { _, userId in
                profileExportViewModel.reset()
                personalDetailsViewModel.begin(details: .empty, userId: nil)
                appState.updateAuthenticatedUser(authViewModel.authenticatedUser?.id)
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
                if isDemo {
                    authViewModel.continueLocally()
                } else if skipAuthForDev {
                    authViewModel.enableDebugSession()
                }
                appState.updateAuthenticatedUser(authViewModel.authenticatedUser?.id)
                appState.updateNetworkAvailability(isConnected: networkMonitor.isConnected)
                Task { await appState.triggerSync(reason: .appLaunch) }
            }
            .task {
                guard !isDemo && !skipAuthForDev else { return }
                await authViewModel.restoreSession()
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
            .onOpenURL { url in
                Task { await authViewModel.handleAuthCallback(url) }
            }
            .task(id: authViewModel.currentUser?.id) { await loadHealthProfile() }
    }

    private func loadHealthProfile() async {
        if let userId = authViewModel.currentUser?.id {
            await healthProfileViewModel.loadGoal(userId: userId)
            #if DEBUG
            if authViewModel.currentUser?.authProvider == "debug" {
                healthProfileViewModel.useDevelopmentGoalIfMissing(userId: userId)
            }
            #endif
        } else {
            healthProfileViewModel.resetUserState()
        }
    }

    private let productImageRepository = CachedProductImageRepository()

    private var configuredContent: some View {
        Group {
            if isDemo || skipAuthForDev {
                HomeView()
            } else if authViewModel.isRestoringSession {
                ProgressView("Åpner MatLogg …")
            } else if authViewModel.currentUser != nil {
                if authViewModel.isOnboarding {
                    OnboardingView()
                } else {
                    HomeView()
                }
            } else {
                WelcomeView()
            }
        }
        .environmentObject(appState)
        .environmentObject(logViewModel)
        .environmentObject(mealReuseViewModel)
        .environmentObject(savedMealsViewModel)
        .environmentObject(waterViewModel)
        .environmentObject(productViewModel)
        .environment(\.productImageRepository, productImageRepository)
        .environment(\.foodSearchRepository, foodSearchRepository)
        .environmentObject(healthProfileViewModel)
        .environmentObject(dailyGoalsViewModel)
        .environmentObject(personalDetailsViewModel)
        .environmentObject(profileFavoritesViewModel)
        .environmentObject(onboardingViewModel)
        .environmentObject(authViewModel)
        .environmentObject(preferencesViewModel)
        .environmentObject(profileExportViewModel)
    }

    private var skipAuthForDev: Bool {
        #if DEBUG
        // Keep the real authentication flow as the Debug default. Feature and
        // UI tests can opt into a deterministic local developer session.
        return ProcessInfo.processInfo.arguments.contains("--skip-auth")
        #else
        return false
        #endif
    }
}
