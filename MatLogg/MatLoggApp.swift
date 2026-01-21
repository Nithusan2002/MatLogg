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
                if appState.currentUser != nil {
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
            }
        }
    }
}
