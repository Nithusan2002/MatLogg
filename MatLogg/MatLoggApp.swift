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
