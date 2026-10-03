import Foundation
import Combine

@MainActor
final class ProductDetailViewModel: ObservableObject {
    @Published private(set) var product: Product
    @Published private(set) var isRefreshing = false
    @Published private(set) var refreshMessage: String?
    @Published private(set) var isLogging = false
    @Published private(set) var logError: String?
    private let repository: any BarcodeLookupRepository

    init(product: Product, repository: any BarcodeLookupRepository) {
        self.product = product
        self.repository = repository
    }

    var nutriScoreInfo: ProductNutriScoreInfo? {
        product.source == "openfoodfacts" ? product.nutriScoreInfo : nil
    }

    var processingInfo: ProductProcessingInfo? {
        guard product.source == "openfoodfacts" else { return nil }
        return product.processingInfo ?? ProductProcessingInfo(novaGroup: nil, markers: [:], ingredients: nil)
    }

    var processingSourceURL: URL? {
        guard let code = product.barcodeEan, !code.isEmpty,
              code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return URL(string: "https://world.openfoodfacts.org/product/\(code)")
    }

    var canRefresh: Bool { product.canRefreshCatalogData }

    func nutrition(for amount: Double?) -> NutritionBreakdown {
        guard let amount else { return NutritionBreakdown(calories: 0, protein: 0, carbs: 0, fat: 0) }
        return product.calculateNutrition(forAmount: Float(amount))
    }

    func log(amount: AmountSelectionViewModel,
             operation: (Product, Double, PortionSelection?) async -> Bool) async -> Bool {
        guard !isLogging, amount.isValid, let total = amount.amount else { return false }
        isLogging = true
        logError = nil
        defer { isLogging = false }
        let success = await operation(product, total, amount.portion)
        if !success { logError = "Kunne ikke lagre på enheten. Prøv igjen." }
        return success
    }

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
                let portionsChanged = updated.servings != product.servings
                product = updated
                if portionsChanged {
                    refreshMessage = "Porsjonsdata er oppdatert. Aktivt porsjonsvalg beholder sitt grunnlag til du velger på nytt."
                } else if manually { refreshMessage = "Produktdata er oppdatert." }
            }
        } catch {
            if manually { refreshMessage = BarcodeLookupFailure.classify(error).message }
        }
    }
}
