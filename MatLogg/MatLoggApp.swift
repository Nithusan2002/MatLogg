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
    @StateObject private var productViewModel: ProductViewModel
    @StateObject private var healthProfileViewModel: HealthProfileViewModel
    @StateObject private var dailyGoalsViewModel: DailyGoalsViewModel
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var preferencesViewModel: PreferencesViewModel
    @StateObject private var userDataExportService: UserDataExportService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let databaseService = DatabaseService()
        _appState = StateObject(wrappedValue: AppState(databaseService: databaseService))
        _logViewModel = StateObject(wrappedValue: LogViewModel(repository: databaseService))
        _mealReuseViewModel = StateObject(wrappedValue: MealReuseViewModel(repository: databaseService))
        _productViewModel = StateObject(wrappedValue: ProductViewModel(repository: databaseService))
        let healthProfile = HealthProfileViewModel(repository: databaseService)
        _healthProfileViewModel = StateObject(wrappedValue: healthProfile)
        _dailyGoalsViewModel = StateObject(wrappedValue: DailyGoalsViewModel(
            repository: databaseService, onSaved: healthProfile.acceptSavedGoal
        ))
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _preferencesViewModel = StateObject(wrappedValue: PreferencesViewModel())
        _userDataExportService = StateObject(wrappedValue: UserDataExportService(logRepository: databaseService))
    }
    
    var body: some Scene {
        WindowGroup {
            configuredContent
            .onChange(of: authViewModel.currentUser?.id) { _, userId in
                mealReuseViewModel.reset()
                if let userId {
                    Task {
                        guard authViewModel.currentUser?.id == userId else { return }
                        await mealReuseViewModel.load(userId: userId)
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
                Task { await appState.triggerSync(reason: .appLaunch) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await appState.triggerSync(reason: .foreground) }
                }
            }
            .task(id: authViewModel.currentUser?.id) { await loadHealthProfile() }
        }
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
