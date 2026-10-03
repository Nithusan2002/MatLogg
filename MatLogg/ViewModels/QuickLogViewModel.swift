import Foundation
import Combine

@MainActor
final class QuickLogViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedManualProduct: Product?
    private var pendingManualProduct: Product?
    private var owner: UUID?
    private let repository: any FoodSearchRepository
    private var requestID = UUID()

    init(repository: any FoodSearchRepository) { self.repository = repository }

    func reset() {
        requestID = UUID()
        products = []
        owner = nil
        pendingManualProduct = nil
        selectedManualProduct = nil
        errorMessage = nil
        isLoading = false
    }

    func saveManual(_ product: Product) async throws {
        guard let owner else { throw DatabaseServiceError.unavailable }
        try await repository.saveManual(product, owner: owner)
        guard self.owner == owner, !Task.isCancelled else { throw CancellationError() }
    }

    func manualProductSaved(_ product: Product) { pendingManualProduct = product }

    func finishManualCreation() {
        selectedManualProduct = pendingManualProduct
        pendingManualProduct = nil
    }

    func load(userId: UUID?) async {
        if owner != userId {
            pendingManualProduct = nil
            selectedManualProduct = nil
        }
        owner = userId
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        do {
            let library = try await repository.loadLocalLibrary(owner: userId)
            guard requestID == request, !Task.isCancelled else { return }
            products = Array(FoodSearchMatcher.unique(library.favorites + library.recent).prefix(8))
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            products = []
            errorMessage = "Kunne ikke hente hurtigvalg. Prøv igjen."
        }
        isLoading = false
    }
}
