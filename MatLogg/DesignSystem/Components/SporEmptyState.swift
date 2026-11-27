import SwiftUI

/// A decorative still illustration with one clear next step.
struct SporEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String
    let actionIdentifier: String
    var isPresentedAsSheet = false
    let action: () -> Void

    @Environment(\.matLoggTabBarScrollMargin) private var bottomMargin

    var body: some View {
        GeometryReader { geometry in
            let clearance = isPresentedAsSheet ? 0 : bottomMargin
            ScrollView {
                VStack(spacing: 0) {
                    SporIllustration()
                        .frame(width: 120, height: 120)
                        .padding(.bottom, 16)
                    Text(title)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.top, 8)
                    Button(actionTitle, action: action)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.actionText)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 8)
                        .padding(.top, 16)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(actionIdentifier)
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - clearance))
                .accessibilityElement(children: .contain)
            }
            .matLoggTabBarScrollClearance()
            .environment(\.matLoggTabBarScrollMargin, clearance)
        }
    }
}
