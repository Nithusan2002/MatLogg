import SwiftUI

struct ProgressRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let label: String
    let valueText: String
    let progress: Double
    let tint: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout())
            layout {
                Text(label)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text(valueText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            GeometryReader { proxy in
                let clamped = min(max(progress, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.progressTrack)
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * clamped)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(valueText)
    }
}
