import Foundation
import Combine

@MainActor
final class ProfileFavoritesViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = true
    private let repository: any ProductRepository
    private var requestId = UUID()
    private var owner: UUID?

    init(repository: any ProductRepository) { self.repository = repository }

    func load(userId: UUID?) async {
        let request = UUID()
        requestId = request
        if owner != userId {
            products = []
            isLoading = true
            owner = userId
        }
        guard let userId else { products = []; isLoading = false; return }
        let result = await repository.getFavorites(userId: userId, kind: nil)
        guard requestId == request, !Task.isCancelled else { return }
        products = result
        isLoading = false
    }
}
