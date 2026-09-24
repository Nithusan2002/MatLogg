import SwiftUI

struct ProductThumbnailView: View {
    let url: URL?
    var placeholderSystemImage: String = "fork.knife"
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(AppColors.mutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.separator.opacity(0.8), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: placeholderSystemImage)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
