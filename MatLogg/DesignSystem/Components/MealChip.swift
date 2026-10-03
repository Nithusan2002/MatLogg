import SwiftUI

struct MealChip: View {
    let title: String
    let isSelected: Bool
    var fillsWidth: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(isSelected && fillsWidth ? "\(title) ✓" : title)
                .font(AppTypography.bodyEmphasis)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                .background(isSelected ? AppColors.chipFillSelected : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.controlBorder, lineWidth: 1)
                )
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
