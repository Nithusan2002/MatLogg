import SwiftUI

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let height: CGFloat
    let action: () -> Void
    
    init(title: String, systemImage: String? = nil, height: CGFloat = 56, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.height = height
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(AppColors.brand)
            .cornerRadius(height / 2)
        }
    }
}
