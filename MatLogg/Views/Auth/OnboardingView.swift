import SwiftUI

/// First use reuses the ordinary search, amount selection and local save flow.
struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var flow = FirstLoggingFlowViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showScanner = false
    let onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch flow.step {
                case .introduction:
                    introduction
                case .logging:
                    FoodSearchView(
                        focusOnAppear: true,
                        isFirstLog: true,
                        onScan: { showScanner = true },
                        onLogComplete: onLogComplete
                    )
                }
            }
            .navigationTitle("MatLogg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if flow.step == .logging {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Hjem") { auth.finishOnboarding() }
                            .accessibilityLabel("Gå til Hjem")
                            .accessibilityIdentifier("first-log-skip")
                    }
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

    private var introduction: some View {
        TabView(selection: Binding(
            get: { flow.introPage },
            set: { flow.selectPage($0) }
        )) {
            ForEach(FirstLoggingFlowViewModel.IntroPage.allCases, id: \.rawValue) { page in
                introductionPage(page)
                    .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(FirstLoggingFlowViewModel.IntroPage.allCases, id: \.rawValue) { page in
                        Button { changePage(page) } label: {
                            Capsule()
                                .fill(flow.introPage == page ? AppColors.action : AppColors.separator)
                                .frame(width: flow.introPage == page ? 28 : 8, height: 8)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Introside \(page.rawValue + 1) av 2: \(page.title)")
                        .accessibilityAddTraits(flow.introPage == page ? .isSelected : [])
                    }
                }
                PrimaryButton(title: flow.introPage == .logging ? "Neste" : "Logg din første matvare") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
                        flow.advanceIntroduction()
                    }
                }
                .accessibilityIdentifier(flow.introPage == .logging ? "onboarding-next" : "onboarding-start-logging")
                Button("Hopp over intro") { flow.startLogging() }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(AppColors.actionText)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("onboarding-skip-intro")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .background(AppColors.background)
        }
    }

    private func introductionPage(_ page: FirstLoggingFlowViewModel.IntroPage) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                OnboardingIllustration(page: page)
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(AppTypography.hero)
                        .foregroundStyle(AppColors.deepInk)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                Text("Uten konto. Lagres på denne iPhonen.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private func changePage(_ page: FirstLoggingFlowViewModel.IntroPage) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
            flow.selectPage(page)
        }
    }
}
