//
//  MatLoggApp.swift
//  MatLogg
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import SwiftUI

@main
struct MatLoggApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            Group {
                if skipAuthForDev {
                    HomeView()
                } else if appState.currentUser != nil {
                    if appState.isOnboarding {
                        OnboardingView()
                    } else {
                        HomeView()
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            .onAppear {
                appState.loadFeedbackSettings()
                if skipAuthForDev {
                    appState.enableDebugSession()
                }
                Task { await appState.triggerSync(reason: .appLaunch) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await appState.triggerSync(reason: .foreground) }
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
