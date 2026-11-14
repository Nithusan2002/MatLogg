import SwiftUI

/// Bundled photographs, available without network access.
struct OnboardingIllustration: View {
    let page: FirstLoggingFlowViewModel.IntroPage

    var body: some View {
        Image(page == .logging ? "OnboardingBreakfast" : "OnboardingMeal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .accessibilityHidden(true)
    }
}
