import SwiftUI

struct SummaryPill: View {
    let label: String
    let value: String
    let tintColor: Color
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
        .background(pillBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .cornerRadius(10)
    }
    
    private var pillBackground: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(backgroundFill)
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tintColor)
                    .frame(width: 3)
                    .padding(.leading, 0)
            }
        }
    }
    
    private var backgroundFill: Color {
        colorScheme == .dark ? AppColors.surface : tintColor.opacity(0.10)
    }
    
    private var strokeColor: Color {
        colorScheme == .dark ? AppColors.separator.opacity(0.22) : AppColors.separator
    }
}
