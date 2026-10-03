import SwiftUI

/// First use reuses the ordinary search, amount selection and local save flow.
struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showScanner = false
    let onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        NavigationStack {
            FoodSearchView(
                focusOnAppear: true,
                isFirstLog: true,
                onScan: { showScanner = true },
                onLogComplete: onLogComplete
            )
            .navigationTitle("Første måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Gå til Hjem") { auth.finishOnboarding() }
                        .accessibilityIdentifier("first-log-skip")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Logg inn") { LoginView() }
                        .accessibilityIdentifier("first-log-login")
                }
            }
        }
        .tint(AppColors.action)
        .fullScreenCover(isPresented: $showScanner) {
            CameraView(onLogComplete: onLogComplete)
        }
    }
}
