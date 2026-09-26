import Foundation
import Combine

struct RawFoodSearchOutcome {
    enum Source {
        case localCache
        case remote
    }

    let items: [MatvaretabellenProduct]
    let source: Source
}

struct FoodSearchOutcome {
    let items: [Product]
    let source: RawFoodSearchOutcome.Source
}

private enum FoodSearchMatcher {
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

@MainActor
final class ProductViewModel: ObservableObject {
    @Published private(set) var errorMessage: String?

    private let repository: any ProductRepository
    private let catalogService: any ProductCatalogService
    private let barcodeService: any BarcodeProductService
    private let nameSearchService: any ProductNameSearchService
    private let matchingService: MatchingService

    static func searchMatches(query: String, name: String, brand: String? = nil) -> Bool {
        FoodSearchMatcher.matches(query: query, name: name, brand: brand)
    }

    static func sortedSearchResults(_ products: [Product], query: String) -> [Product] {
        FoodSearchMatcher.sorted(products, query: query)
    }

    convenience init(repository: any ProductRepository) {
        let apiService = APIService()
        self.init(
            repository: repository,
            catalogService: MatvaretabellenService(),
            barcodeService: apiService,
            nameSearchService: apiService,
            matchingService: MatchingService()
        )
    }

    init(
        repository: any ProductRepository,
        catalogService: any ProductCatalogService,
        barcodeService: any BarcodeProductService,
        nameSearchService: any ProductNameSearchService,
        matchingService: MatchingService
    ) {
        self.repository = repository
        self.catalogService = catalogService
        self.barcodeService = barcodeService
        self.nameSearchService = nameSearchService
        self.matchingService = matchingService
    }

    func product(id: UUID) -> Product? {
        repository.getProduct(id)
    }

    func products(ids: Set<UUID>) async -> [UUID: Product] {
        await repository.getProducts(ids)
    }

    func saveManualProduct(_ product: Product) async throws {
        try await repository.saveProduct(product)
    }

    func cachedProduct(barcode: String) -> Product? {
        repository.getProductByBarcode(barcode)
    }

    func fetchProduct(barcode: String) async throws -> Product {
        try await barcodeService.searchProductByBarcodeOpenFoodFacts(barcode)
    }

    @discardableResult
    func saveScannedProduct(_ product: Product, userId: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await repository.cacheCatalogProduct(product)
            try await repository.saveScanHistory(userId: userId, productId: product.id)
            return true
        } catch {
            errorMessage = "Kunne ikke lagre skanning: \(error.localizedDescription)"
            return false
        }
    }

    func recentScans(userId: UUID, limit: Int = 15) async -> [ScanHistory] {
        await repository.getRecentScans(userId: userId, limit: limit)
    }

    @discardableResult
    func recordScan(productId: UUID, userId: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await repository.saveScanHistory(userId: userId, productId: productId)
            return true
        } catch {
            errorMessage = "Skannehistorikken kunne ikke oppdateres."
            return false
        }
    }

    func recentProducts(userId: UUID, kind: ProductKind? = nil, limit: Int = 10) async -> [Product] {
        await repository.getRecentProducts(userId: userId, kind: kind, limit: limit)
    }

    func favoriteProducts(userId: UUID, kind: ProductKind? = nil) async -> [Product] {
        await repository.getFavorites(userId: userId, kind: kind)
    }

    @discardableResult
    func toggleFavorite(_ product: Product, userId: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await repository.toggleFavorite(userId: userId, productId: product.id)
            return true
        } catch {
            errorMessage = "Kunne ikke oppdatere favoritt: \(error.localizedDescription)"
            return false
        }
    }

    func isFavorite(_ product: Product, userId: UUID) -> Bool {
        repository.isFavorite(userId: userId, productId: product.id)
    }

    func rawFoodSuggestions() async -> [MatvaretabellenProduct] {
        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 30) {
            return cached
        }
        let items = (try? await catalogService.fetchCommonFoods()) ?? []
        repository.saveMatvaretabellenCache(items)
        return items
    }

    func searchRawFoods(query: String) async -> [MatvaretabellenProduct] {
        (try? await searchRawFoodsWithStatus(query: query).items) ?? []
    }

    func searchRawFoodsWithStatus(query: String) async throws -> RawFoodSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RawFoodSearchOutcome(items: [], source: .localCache)
        }

        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 30), !cached.isEmpty {
            let filtered = cached.filter {
                Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand)
            }
            if !filtered.isEmpty {
                return RawFoodSearchOutcome(items: filtered, source: .localCache)
            }
        }

        let items = try await catalogService.searchProducts(query: trimmed)
            .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
        return RawFoodSearchOutcome(items: items, source: .remote)
    }

    func searchFoodsWithStatus(query: String) async throws -> FoodSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return FoodSearchOutcome(items: [], source: .localCache)
        }

        var products: [Product] = []
        var usedRemoteSource = false
        var firstError: Error?

        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 30), !cached.isEmpty {
            let cachedMatches = cached
                .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
            products.append(contentsOf: cachedMatches.map(makeRawFoodProduct))
            if cachedMatches.isEmpty {
                do {
                    let rawFoods = try await catalogService.searchProducts(query: trimmed)
                    products.append(contentsOf: rawFoods
                        .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
                        .map(makeRawFoodProduct))
                    usedRemoteSource = true
                } catch {
                    firstError = error
                }
            }
        } else {
            do {
                let rawFoods = try await catalogService.searchProducts(query: trimmed)
                products.append(contentsOf: rawFoods
                    .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
                    .map(makeRawFoodProduct))
                usedRemoteSource = true
            } catch {
                firstError = error
            }
        }

        do {
            let packagedProducts = try await nameSearchService.searchProductsByNameOpenFoodFacts(trimmed)
            products.append(contentsOf: packagedProducts
                .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
                .map { product in
                    guard let barcode = product.barcodeEan else { return product }
                    return repository.getProductByBarcode(barcode) ?? product
                })
            usedRemoteSource = true
        } catch {
            firstError = firstError ?? error
        }

        if products.isEmpty, !usedRemoteSource, let firstError {
            throw firstError
        }

        var seen = Set<String>()
        let uniqueProducts = products.filter { product in
            let key = product.barcodeEan.map { "barcode:\($0)" }
                ?? "\(product.source):\(normalize(product.name)):\(normalize(product.brand ?? ""))"
            return seen.insert(key).inserted
        }

        return FoodSearchOutcome(
            items: Self.sortedSearchResults(uniqueProducts, query: trimmed),
            source: usedRemoteSource ? .remote : .localCache
        )
    }

    func upgradeNutritionIfPossible(for product: Product) async -> Product? {
        guard let barcode = product.barcodeEan else { return nil }

        if let mapping = repository.getMatchMapping(for: barcode) {
            let daysOld = Calendar.current.dateComponents([.day], from: mapping.updatedAt, to: Date()).day ?? 0
            if daysOld <= 30, mapping.confidenceScore >= 0.85 {
                return await persistUpgrade(makeUpgradedProduct(from: product, mapping: mapping, verified: true))
            }
        }

        let candidates = (try? await catalogService.searchProducts(query: product.name)) ?? []
        guard let best = matchingService.bestMatch(offProduct: product, candidates: candidates) else { return nil }

        let mapping = ProductMatchMapping(
            barcode: barcode,
            matvaretabellenId: best.product.id,
            matchedName: best.product.name,
            confidenceScore: best.score,
            updatedAt: Date(),
            caloriesPer100g: best.product.caloriesPer100g,
            proteinGPer100g: best.product.proteinGPer100g,
            carbsGPer100g: best.product.carbsGPer100g,
            fatGPer100g: best.product.fatGPer100g,
            sugarGPer100g: best.product.sugarGPer100g,
            fiberGPer100g: best.product.fiberGPer100g,
            sodiumMgPer100g: best.product.sodiumMgPer100g,
            category: best.product.category
        )

        if best.score >= 0.85 {
            repository.saveMatchMapping(mapping)
            return await persistUpgrade(makeUpgradedProduct(from: product, mapping: mapping, verified: true))
        }

        if best.score >= 0.60 {
            repository.saveMatchMapping(mapping)
            let suggested = Product(
                id: product.id,
                name: product.name,
                brand: product.brand,
                category: product.category,
                barcodeEan: barcode,
                source: product.source,
                kind: product.kind,
                caloriesPer100g: product.caloriesPer100g,
                proteinGPer100g: product.proteinGPer100g,
                carbsGPer100g: product.carbsGPer100g,
                fatGPer100g: product.fatGPer100g,
                sugarGPer100g: product.sugarGPer100g,
                fiberGPer100g: product.fiberGPer100g,
                sodiumMgPer100g: product.sodiumMgPer100g,
                imageUrl: product.imageUrl,
                standardPortions: product.standardPortions,
                servings: product.servings,
                nutritionSource: product.nutritionSource,
                imageSource: product.imageUrl == nil ? .none : product.imageSource,
                verificationStatus: .suggestedMatch,
                confidenceScore: best.score,
                isVerified: false,
                createdAt: product.createdAt,
                externalID: product.externalID,
                nutritionBasis: product.nutritionBasis,
                sourceUpdatedAt: product.sourceUpdatedAt,
                sourceRevision: product.sourceRevision,
                sourceSchemaVersion: product.sourceSchemaVersion,
                fetchedAt: product.fetchedAt,
                dataQualityWarnings: product.dataQualityWarnings
            )
            return await persistUpgrade(suggested)
        }

        return nil
    }

    private func makeUpgradedProduct(from product: Product, mapping: ProductMatchMapping, verified: Bool) -> Product {
        Product(
            id: product.id,
            name: product.name,
            brand: product.brand,
            category: mapping.category ?? product.category,
            barcodeEan: product.barcodeEan,
            source: product.source,
            kind: product.kind,
            caloriesPer100g: mapping.caloriesPer100g,
            proteinGPer100g: mapping.proteinGPer100g,
            carbsGPer100g: mapping.carbsGPer100g,
            fatGPer100g: mapping.fatGPer100g,
            sugarGPer100g: mapping.sugarGPer100g,
            fiberGPer100g: mapping.fiberGPer100g,
            sodiumMgPer100g: mapping.sodiumMgPer100g,
            imageUrl: product.imageUrl,
            standardPortions: product.standardPortions,
            servings: product.servings,
            nutritionSource: .matvaretabellen,
            imageSource: product.imageUrl == nil ? .none : product.imageSource,
            verificationStatus: verified ? .verified : .suggestedMatch,
            confidenceScore: mapping.confidenceScore,
            isVerified: verified,
            createdAt: product.createdAt,
            externalID: product.externalID,
            nutritionBasis: product.nutritionBasis,
            sourceUpdatedAt: product.sourceUpdatedAt,
            sourceRevision: product.sourceRevision,
            sourceSchemaVersion: product.sourceSchemaVersion,
            fetchedAt: product.fetchedAt,
            dataQualityWarnings: product.dataQualityWarnings
        )
    }

    private func persistUpgrade(_ product: Product) async -> Product {
        do {
            try await repository.cacheCatalogProduct(product)
        } catch {
            errorMessage = "Kunne ikke lagre forbedrede næringsdata: \(error.localizedDescription)"
        }
        return product
    }

    private func makeRawFoodProduct(_ item: MatvaretabellenProduct) -> Product {
        Product(
            id: Product.catalogID(source: "matvaretabellen", externalID: item.id),
            name: item.name,
            brand: item.brand,
            category: item.category,
            barcodeEan: nil,
            source: "matvaretabellen",
            kind: .genericFood,
            caloriesPer100g: item.caloriesPer100g,
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

    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
