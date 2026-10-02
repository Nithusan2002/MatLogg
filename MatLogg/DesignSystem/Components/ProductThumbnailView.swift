import SwiftUI

struct ProductThumbnailView: View {
    @Environment(\.productImageRepository) private var repository
    @StateObject private var viewModel = ProductThumbnailViewModel()
    let url: URL?
    var localData: Data? = nil
    var placeholderSystemImage: String = "fork.knife"
    var size: CGFloat = 52
    var imagePadding: CGFloat = 4

    var body: some View {
        Group {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(imagePadding)
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
        .task(id: ImageIdentity(url: url, data: localData)) { await viewModel.load(url: url, localData: localData, repository: repository) }
    }

    private struct ImageIdentity: Equatable { let url: URL?; let data: Data? }

    private var placeholder: some View {
        Image(systemName: placeholderSystemImage)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
