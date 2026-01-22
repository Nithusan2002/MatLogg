import SwiftUI

struct MealChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.bodyEmphasis)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(isSelected ? AppColors.chipFillSelected : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.chipStroke, lineWidth: 1)
                )
                .cornerRadius(12)
        }
    }
}
