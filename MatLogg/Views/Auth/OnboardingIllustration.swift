import SwiftUI

/// Bundled Spor artwork; the ordinary first-log flow is preserved.
struct OnboardingIllustration: View {
    let page: FirstLoggingFlowViewModel.IntroPage
    var body: some View {
        SporCompanionView(context: .introduction, eligible: page == .logging)
            .frame(maxWidth: 260)
            .frame(height: 220)
            .accessibilityHidden(true)
    }
}
