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
    @StateObject private var productViewModel: ProductViewModel
    @StateObject private var healthProfileViewModel: HealthProfileViewModel
    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var preferencesViewModel: PreferencesViewModel
    @StateObject private var userDataExportService: UserDataExportService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let databaseService = DatabaseService()
        _appState = StateObject(wrappedValue: AppState(databaseService: databaseService))
        _logViewModel = StateObject(wrappedValue: LogViewModel(repository: databaseService))
        _productViewModel = StateObject(wrappedValue: ProductViewModel(repository: databaseService))
        _healthProfileViewModel = StateObject(wrappedValue: HealthProfileViewModel(repository: databaseService))
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
        _preferencesViewModel = StateObject(wrappedValue: PreferencesViewModel())
        _userDataExportService = StateObject(wrappedValue: UserDataExportService(logRepository: databaseService))
    }
    
    var body: some Scene {
        WindowGroup {
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
            .environmentObject(productViewModel)
            .environmentObject(healthProfileViewModel)
            .environmentObject(authViewModel)
            .environmentObject(preferencesViewModel)
            .environmentObject(userDataExportService)
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
            .task(id: authViewModel.currentUser?.id) {
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
        }
    }
    
    private var skipAuthForDev: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
