import SwiftUI

struct ProductThumbnailView: View {
    @Environment(\.productImageRepository) private var repository
    @StateObject private var viewModel = ProductThumbnailViewModel()
    let url: URL?
    var placeholderSystemImage: String = "fork.knife"
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
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
        .task(id: url) { await viewModel.load(url: url, repository: repository) }
    }

    private var placeholder: some View {
        Image(systemName: placeholderSystemImage)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
