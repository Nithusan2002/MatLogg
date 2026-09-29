import SwiftUI

struct OnboardingView: View {
    var body: some View {
        MatLoggOnboardingFlowView()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(HealthProfileViewModel(repository: DatabaseService()))
        .environmentObject(AuthViewModel())
        .environmentObject(PreferencesViewModel())
        .environmentObject(OnboardingViewModel(goalRepository: DatabaseService()))
}
