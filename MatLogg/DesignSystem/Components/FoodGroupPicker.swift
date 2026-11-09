import SwiftUI

/// Shared optional selection for creation and the narrowly scoped own-product editor.
struct FoodGroupPicker: View {
    @Binding var selection: FoodGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matgruppe (valgfritt)")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)
            HStack(spacing: 12) {
                ProductThumbnailView(url: nil, foodGroup: selection ?? .other, size: 44)
                Picker("Matgruppe (valgfritt)", selection: $selection) {
                    Text("Ikke valgt").tag(nil as FoodGroup?)
                    ForEach(FoodGroup.allCases, id: \.rawValue) { group in
                        Text(group.title).tag(Optional(group))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(AppColors.actionText)
                .frame(minHeight: 44)
                .accessibilityIdentifier("food-group-picker")
            }
        }
    }
}
