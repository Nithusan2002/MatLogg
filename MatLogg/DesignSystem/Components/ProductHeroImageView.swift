import SwiftUI
import UIKit

struct ProductHeroImageView: View {
    private let image: UIImage?
    private let url: URL?
    private let height: CGFloat
    private let cornerRadius: CGFloat
    private let thumbnailHeight: CGFloat = 170
    
    init(image: UIImage?, height: CGFloat = 220, cornerRadius: CGFloat = 18) {
        self.image = image
        self.url = nil
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    init(url: URL?, height: CGFloat = 220, cornerRadius: CGFloat = 18) {
        self.image = nil
        self.url = url
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            Group {
                if let image {
                    heroView(with: Image(uiImage: image), width: width)
                } else if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            heroPlaceholder(width: width)
                        case .success(let image):
                            heroView(with: image, width: width)
                        case .failure:
                            heroPlaceholder(width: width)
                        @unknown default:
                            heroPlaceholder(width: width)
                        }
                    }
                } else {
                    heroPlaceholder(width: width)
                }
            }
            .frame(width: width, height: height)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.separator.opacity(0.7), lineWidth: 1)
            )
            .clipped()
        }
        .frame(height: height)
    }
    
    private func heroView(with image: Image, width: CGFloat) -> some View {
        ZStack {
            image
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .blur(radius: 18)
                .overlay(washOverlay)
            
            image
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.7, height: thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppColors.ink.opacity(0.12), radius: 10, x: 0, y: 6)
        }
    }
    
    private var washOverlay: some View {
        let opacity = colorScheme == .dark ? 0.12 : 0.06
        return AppColors.ink.opacity(opacity)
    }
    
    private func heroPlaceholder(width: CGFloat) -> some View {
        ZStack {
            AppColors.surface
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textSecondary)
                Text("Bilde ikke tilgjengelig")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(width: width, height: height)
    }
}
