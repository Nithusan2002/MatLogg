import SwiftUI

struct SummaryPill: View {
    let label: String
    let value: String
    let backgroundColor: Color
    let height: CGFloat = 46
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.ink)
                .lineLimit(1)
            Text(value)
                .font(.headline)
                .foregroundColor(AppColors.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.horizontal, 8)
        .background(backgroundColor.opacity(backgroundOpacity))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .cornerRadius(10)
    }
    
    private var backgroundOpacity: Double {
        colorScheme == .dark ? 0.07 : 0.10
    }
}
