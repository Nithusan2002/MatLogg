import SwiftUI

struct OnboardingView: View {
    var body: some View {
        GoalOnboardingFlowView(mode: .onboarding)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(HealthProfileViewModel(repository: DatabaseService()))
        .environmentObject(AuthViewModel())
        .environmentObject(PreferencesViewModel())
}
