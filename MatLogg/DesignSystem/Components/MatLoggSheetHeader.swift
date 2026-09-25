import SwiftUI

struct MatLoggSheetHeader: View {
    let title: String
    var isCloseDisabled = false
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.deepInk)
                    .frame(width: 44, height: 44)
                    .background(AppColors.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isCloseDisabled)
            .accessibilityLabel("Avbryt")

            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.deepInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }
}
