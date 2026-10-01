import SwiftUI
import Combine

@MainActor
final class ProductThumbnailViewModel: ObservableObject {
    @Published private(set) var image: UIImage?
    private var requestID = UUID()

    func load(url: URL?, repository: (any ProductImageRepository)?) async {
        let id = UUID()
        requestID = id
        image = nil
        guard let url, let repository else { return }
        do {
            let data = try await repository.data(for: url)
            guard requestID == id, !Task.isCancelled else { return }
            image = UIImage(data: data)
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
