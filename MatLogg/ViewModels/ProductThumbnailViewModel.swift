import SwiftUI
import Combine

@MainActor
final class ProductThumbnailViewModel: ObservableObject {
    @Published private(set) var image: UIImage?
    private var requestID = UUID()

    func load(url: URL?, localData: Data? = nil, repository: (any ProductImageRepository)?, maximumPixelSize: Int = 160) async {
        let id = UUID()
        requestID = id
        image = nil
        do {
            let prepared: UIImage
            if let localData {
                prepared = try await ProductImagePreparation.image(from: localData, maximumPixelSize: maximumPixelSize)
            } else if let url, let repository {
                prepared = UIImage(cgImage: try await repository.pixels(for: url, maximumPixelSize: maximumPixelSize))
            } else { return }
            guard requestID == id, !Task.isCancelled else { return }
            image = prepared
        } catch {
            // Keep the fixed placeholder for missing, invalid or offline images.
        }
    }
}

private struct ProductImageRepositoryKey: EnvironmentKey {
    static let defaultValue: (any ProductImageRepository)? = nil
}

extension EnvironmentValues {
    var productImageRepository: (any ProductImageRepository)? {
        get { self[ProductImageRepositoryKey.self] }
        set { self[ProductImageRepositoryKey.self] = newValue }
    }
}
