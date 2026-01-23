import SwiftUI

struct ProgressRow: View {
    let label: String
    let valueText: String
    let progress: Double
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(valueText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            GeometryReader { proxy in
                let clamped = min(max(progress, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.progressTrack)
                    Capsule()
                        .fill(tint.opacity(0.75))
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .frame(height: 6)
        }
    }
}
