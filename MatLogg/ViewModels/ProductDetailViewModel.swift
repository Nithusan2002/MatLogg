import Foundation
import Combine

@MainActor
final class ProductDetailViewModel: ObservableObject {
    @Published private(set) var product: Product
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshMessage: String?
    private let repository: any BarcodeLookupRepository

    init(product: Product, repository: any BarcodeLookupRepository) {
        self.product = product
        self.repository = repository
    }

    var canRefresh: Bool { product.canRefreshCatalogData }

    func refresh(manually: Bool) async {
        guard !isRefreshing, canRefresh else { return }
        isRefreshing = true
        refreshMessage = nil
        defer { isRefreshing = false }
        do {
            if let updated = try await repository.refresh(product, manually: manually) {
                // Keep the approved amount unit stable while this card is open.
                guard updated.amountUnit == product.amountUnit else {
                    refreshMessage = "Produktets måleenhet er endret hos kilden. Åpne produktet på nytt for å bruke de nye dataene."
                    return
                }
                product = updated
                if manually { refreshMessage = "Produktdata er oppdatert." }
            }
        } catch {
            if manually { refreshMessage = BarcodeLookupFailure.classify(error).message }
        }
    }
}
