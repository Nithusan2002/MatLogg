import Foundation

struct BarcodeProductCachePolicy {
    nonisolated static let standard = BarcodeProductCachePolicy(
        freshnessLifetime: 30 * 24 * 60 * 60,
        refreshRetryDelay: 24 * 60 * 60
    )

    let freshnessLifetime: TimeInterval
    let refreshRetryDelay: TimeInterval

    nonisolated func needsRevalidation(_ product: Product, now: Date) -> Bool {
        guard product.canRefreshCatalogData else { return false }
        guard let fetchedAt = product.fetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) >= freshnessLifetime
    }
}

enum BarcodeLookupFailure: Error, Equatable {
    case notFound
    case incomplete
    case rateLimited(Int?)
    case unavailable
    case protectedProduct
    case storageFailure

    static func classify(_ error: Error) -> Self {
        if let failure = error as? Self { return failure }
        if let localError = error as? LocalStoreError, case .ownershipMismatch = localError {
            return .protectedProduct
        }
        guard let apiError = error as? APIService.APIError else { return .unavailable }
        switch apiError {
        case .serverError(404): return .notFound
        case .backendError(let status, _, _) where status == 404: return .notFound
        case .incompleteProductData: return .incomplete
        case .rateLimited(let seconds): return .rateLimited(seconds)
        default: return .unavailable
        }
    }

    var title: String {
        switch self {
        case .notFound: return "Vi fant ikke produktet"
        case .incomplete: return "Produktet mangler næringsdata"
        case .rateLimited: return "Produktdatabasen trenger en pause"
        case .unavailable: return "Fikk ikke kontakt med produktdatabasen"
        case .protectedProduct: return "Egne produktdata beholdes"
        case .storageFailure: return "Kunne ikke lagre produktdata"
        }
    }

    var message: String {
        switch self {
        case .notFound: return "Denne strekkoden finnes ikke hos Open Food Facts. Du kan registrere produktet manuelt."
        case .incomplete: return "Vi fant ikke komplette næringsverdier per 100 g eller 100 ml. Registrer verdiene fra pakken manuelt."
        case .rateLimited(let seconds):
            if let seconds { return "Vent minst \(max(1, seconds)) sekunder før du prøver igjen. Lagrede produktdata beholdes." }
            return "Vent litt før du prøver igjen. Lagrede produktdata beholdes."
        case .unavailable: return "Sjekk nettet og prøv igjen. Lagrede produktdata beholdes, og du kan registrere manuelt."
        case .protectedProduct: return "Brukerregistrerte eller endrede næringsdata overskrives ikke av katalogen."
        case .storageFailure: return "Oppdateringen kunne ikke lagres på enheten. Tidligere data beholdes. Prøv igjen."
        }
    }
}

@MainActor
protocol BarcodeLookupRepository {
    func cached(barcode: String, owner: UUID?) -> Product?
    func fetch(barcode: String) async throws -> Product
    func refresh(_ product: Product, manually: Bool) async throws -> Product?
}

@MainActor
final class DefaultBarcodeLookupRepository: BarcodeLookupRepository {
    private let products: any ProductRepository
    private let remote: any BarcodeProductService
    private let policy: BarcodeProductCachePolicy
    private let now: () -> Date
    private var tasks: [String: Task<Product, Error>] = [:]
    private var retryAfter: [String: Date] = [:]
    // A provider limit applies to all barcode requests, including manual ones.
    private var rateLimitUntil: Date?

    init(products: any ProductRepository, remote: any BarcodeProductService,
         policy: BarcodeProductCachePolicy = .standard, now: @escaping () -> Date = Date.init) {
        self.products = products
        self.remote = remote
        self.policy = policy
        self.now = now
    }

    func cached(barcode: String, owner: UUID?) -> Product? {
        products.getProductByBarcode(barcode, ownerUserId: owner)
    }

    func refresh(_ product: Product, manually: Bool) async throws -> Product? {
        guard product.canRefreshCatalogData, let barcode = product.barcodeEan else { return nil }
        let current = products.getProductByBarcode(barcode, ownerUserId: nil) ?? product
        guard current.canRefreshCatalogData else {
            if manually { throw BarcodeLookupFailure.protectedProduct }
            return nil
        }
        if !manually, !policy.needsRevalidation(current, now: now()) {
            return current.fetchedAt != product.fetchedAt ? current : nil
        }
        if !manually, let next = retryAfter[barcode], next > now() { return nil }
        return try await fetch(barcode: barcode)
    }

    func fetch(barcode: String) async throws -> Product {
        if let task = tasks[barcode] { return try await task.value }
        if let until = rateLimitUntil, until > now() {
            throw BarcodeLookupFailure.rateLimited(Int(ceil(until.timeIntervalSince(now()))))
        }
        let task = Task<Product, Error> { [remote, products] in
            let product = try await remote.searchProductByBarcodeOpenFoodFacts(barcode)
            if let stored = products.getProduct(product.id), !stored.canRefreshCatalogData {
                throw BarcodeLookupFailure.protectedProduct
            }
            do {
                try await products.cacheCatalogProduct(product)
            } catch {
                if let localError = error as? LocalStoreError, case .ownershipMismatch = localError {
                    throw BarcodeLookupFailure.protectedProduct
                }
                throw BarcodeLookupFailure.storageFailure
            }
            return product
        }
        tasks[barcode] = task
        defer { tasks[barcode] = nil }
        do {
            let product = try await task.value
            retryAfter[barcode] = nil
            return product
        } catch {
            let failure = BarcodeLookupFailure.classify(error)
            retryAfter[barcode] = now().addingTimeInterval(policy.refreshRetryDelay)
            if case .rateLimited(let seconds) = failure {
                rateLimitUntil = now().addingTimeInterval(TimeInterval(max(1, seconds ?? 60)))
            }
            throw failure
        }
    }
}

extension Product {
    nonisolated var canRefreshCatalogData: Bool {
        source == "openfoodfacts" && nutritionSource == .openFoodFacts
            && barcodeEan?.isEmpty == false
    }
}
