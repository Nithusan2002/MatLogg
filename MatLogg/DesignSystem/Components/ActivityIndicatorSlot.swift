import SwiftUI

/// A permanent footprint prevents activity changes from moving adjacent content.
struct ActivityIndicatorSlot: View {
    let isActive: Bool
    let label: String

    var body: some View {
        ZStack {
            if isActive {
                ProgressView().controlSize(.small).tint(AppColors.action)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHidden(!isActive)
    }
}
