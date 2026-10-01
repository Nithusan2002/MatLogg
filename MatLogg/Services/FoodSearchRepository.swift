import Foundation

struct FoodSearchLibrary {
    let products: [Product]
    let recent: [Product]
    let favorites: [Product]
    let suggestions: [Product]
}

@MainActor
protocol FoodSearchRepository {
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func searchRemote(query: String, owner: UUID?) async throws -> [Product]
    func saveManual(_ product: Product, owner: UUID) async throws
    func prepare(_ product: Product, owner: UUID) async throws
}

@MainActor
final class DefaultFoodSearchRepository: FoodSearchRepository {
    private let products: any ProductRepository
    private let catalog: any ProductCatalogService
    private let remote: any ProductNameSearchService

    init(products: any ProductRepository, catalog: any ProductCatalogService, remote: any ProductNameSearchService) {
        self.products = products
        self.catalog = catalog
        self.remote = remote
    }

    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        let stored = try await products.getSearchableProducts(ownerUserId: owner)
        let recent = if let owner { await products.getRecentProducts(userId: owner, kind: nil, limit: 6) } else { [Product]() }
        let favorites = if let owner { await products.getFavorites(userId: owner, kind: nil) } else { [Product]() }
        let raw: [MatvaretabellenProduct]
        do {
            raw = try await catalog.fetchCommonFoods()
        } catch {
            if let cached = products.getMatvaretabellenCache(maxAgeDays: 365), !cached.isEmpty {
                raw = cached
            } else if !stored.isEmpty {
                raw = []
            } else {
                throw error
            }
        }
        let rawProducts = raw.map(FoodSearchCatalog.product)
        return FoodSearchLibrary(
            products: FoodSearchMatcher.unique(stored + rawProducts),
            recent: recent, favorites: favorites,
            suggestions: Array(rawProducts.prefix(8))
        )
    }

    func searchRemote(query: String, owner: UUID?) async throws -> [Product] {
        let result = try await remote.searchProductsByNameOpenFoodFacts(query)
        return result.filter {
            FoodSearchMatcher.matches(query: query, name: $0.name, brand: $0.brand)
        }.map { product in
            guard let barcode = product.barcodeEan else { return product }
            return products.getProductByBarcode(barcode, ownerUserId: owner) ?? product
        }
    }

    func saveManual(_ product: Product, owner: UUID) async throws {
        try await products.saveProduct(product, ownerUserId: owner)
    }

    func prepare(_ product: Product, owner: UUID) async throws {
        // Existing owner rows must not be converted into shared catalog cache.
        if product.source != "user", products.getProduct(product.id) == nil {
            try await products.cacheCatalogProduct(product)
        }
    }
}

enum FoodSearchMatcher {
    static func matches(query: String, name: String, brand: String? = nil) -> Bool {
        let tokens = normalized(query).split(separator: " ")
        guard !tokens.isEmpty else { return false }
        let searchableText = normalized([name, brand].compactMap { $0 }.joined(separator: " "))
        return tokens.allSatisfy { searchableText.contains($0) }
    }

    static func sorted(_ products: [Product], query: String) -> [Product] {
        products.sorted { lhs, rhs in
            let lhsScore = relevance(of: lhs, query: query)
            let rhsScore = relevance(of: rhs, query: query)
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func relevance(of product: Product, query: String) -> Int {
        let normalizedQuery = normalized(query)
        let name = normalized(product.name)
        let brand = normalized(product.brand ?? "")
        if name == normalizedQuery { return 0 }
        if name.hasPrefix(normalizedQuery) { return 1 }
        if brand == normalizedQuery { return 2 }
        if name.contains(normalizedQuery) { return 3 }
        return 4
    }

    private static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FoodSearchCatalog {
    static func product(_ item: MatvaretabellenProduct) -> Product {
        Product(
            id: Product.catalogID(source: "matvaretabellen", externalID: item.id),
            name: item.name,
            brand: item.brand,
            category: item.category,
            barcodeEan: nil,
            source: "matvaretabellen",
            kind: .genericFood,
            caloriesPer100g: Float(item.caloriesPer100g),
            proteinGPer100g: item.proteinGPer100g,
            carbsGPer100g: item.carbsGPer100g,
            fatGPer100g: item.fatGPer100g,
            sugarGPer100g: item.sugarGPer100g,
            fiberGPer100g: item.fiberGPer100g,
            sodiumMgPer100g: item.sodiumMgPer100g,
            imageUrl: nil,
            standardPortions: nil,
            nutritionSource: .matvaretabellen,
            imageSource: .none,
            verificationStatus: .verified,
            confidenceScore: nil,
            isVerified: true,
            externalID: item.id,
            nutritionBasis: .per100g,
            fetchedAt: Date()
        )
    }

}

extension FoodSearchMatcher {
    static func unique(_ products: [Product]) -> [Product] {
        var ids = Set<UUID>()
        var barcodes = Set<String>()
        return products.filter { product in
            guard ids.insert(product.id).inserted else { return false }
            if let barcode = product.barcodeEan, !barcode.isEmpty {
                return barcodes.insert(barcode).inserted
            }
            return true
        }
    }
}
