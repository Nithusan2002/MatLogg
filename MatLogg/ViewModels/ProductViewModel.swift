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

@MainActor
final class ProductViewModel: ObservableObject {
    @Published private(set) var errorMessage: String?

    private let repository: any ProductRepository
    private let catalogService: any ProductCatalogService
    let barcodeRepository: any BarcodeLookupRepository
    private let nameSearchService: any ProductNameSearchService
    @Published private(set) var scannedProduct: Product?
    @Published private(set) var scannedBarcode: String?
    @Published private(set) var isScanning = false
    @Published private(set) var scanFailure: BarcodeLookupFailure?
    private var scanRequestID = UUID()
    private var scanFeedbackTask: Task<Void, Never>?
    @Published private(set) var isScanTakingLong = false

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
            cachePolicy: .standard
        )
    }

    init(
        repository: any ProductRepository,
        catalogService: any ProductCatalogService,
        barcodeService: any BarcodeProductService,
        nameSearchService: any ProductNameSearchService,
        cachePolicy: BarcodeProductCachePolicy = .standard,
        now: @escaping () -> Date = Date.init,
        barcodeRepository: (any BarcodeLookupRepository)? = nil
    ) {
        self.repository = repository
        self.catalogService = catalogService
        self.barcodeRepository = barcodeRepository ?? DefaultBarcodeLookupRepository(
            products: repository, remote: barcodeService, policy: cachePolicy, now: now
        )
        self.nameSearchService = nameSearchService
    }

    func product(id: UUID) -> Product? {
        repository.getProduct(id)
    }

    func products(ids: Set<UUID>) async -> [UUID: Product] {
        await repository.getProducts(ids)
    }

    func saveManualProduct(_ product: Product, ownerUserId: UUID) async throws {
        try await repository.saveProduct(product, ownerUserId: ownerUserId)
    }

    func cachedProduct(barcode: String, ownerUserId: UUID?) -> Product? {
        repository.getProductByBarcode(barcode, ownerUserId: ownerUserId)
    }

    func lookupBarcode(from scannedCode: ScannedBarcode) throws -> String {
        try ProductBarcodeParser.lookupBarcode(from: scannedCode)
    }

    func fetchProduct(barcode: String) async throws -> Product {
        try await barcodeRepository.fetch(barcode: barcode)
    }

    func refreshCachedProductIfNeeded(_ cached: Product) async -> Product? {
        try? await barcodeRepository.refresh(cached, manually: false)
    }

    func resetScan() {
        scanFeedbackTask?.cancel()
        isScanTakingLong = false
        scanRequestID = UUID()
        scannedBarcode = nil
        scannedProduct = nil
        scanFailure = nil
        isScanning = false
    }

    func acceptManualScan(_ product: Product) {
        scanFeedbackTask?.cancel()
        isScanTakingLong = false
        scanRequestID = UUID()
        scannedProduct = product
        isScanning = false
        scanFailure = nil
    }

    /// Publishes local data immediately; the product card owns revalidation.
    func scan(barcode: String, ownerUserId: UUID?) async {
        guard !isScanning, scannedBarcode != barcode else { return }
        let requestID = UUID()
        scanRequestID = requestID
        scannedBarcode = barcode
        scannedProduct = nil
        scanFailure = nil
        isScanning = true
        isScanTakingLong = false
        scanFeedbackTask?.cancel()
        scanFeedbackTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard let self, scanRequestID == requestID, isScanning else { return }
            isScanTakingLong = true
        }
        defer {
            if scanRequestID == requestID {
                scanFeedbackTask?.cancel()
                isScanTakingLong = false
            }
        }
        do {
            let product: Product
            if let cached = barcodeRepository.cached(barcode: barcode, owner: ownerUserId) {
                product = cached
            } else {
                product = try await barcodeRepository.fetch(barcode: barcode)
            }
            guard scanRequestID == requestID else { return }
            scannedProduct = product
            isScanning = false
            if let ownerUserId { _ = await recordScan(productId: product.id, userId: ownerUserId) }
        } catch {
            guard scanRequestID == requestID else { return }
            scanFailure = BarcodeLookupFailure.classify(error)
            isScanning = false
        }
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
        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 365) {
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

        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 365), !cached.isEmpty {
            let filtered = cached.filter {
                Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand)
            }
            if !filtered.isEmpty {
                return RawFoodSearchOutcome(items: filtered, source: .localCache)
            }
        }

        let items = try await catalogService.searchProducts(query: trimmed)
            .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
        return RawFoodSearchOutcome(items: items, source: .localCache)
    }

    func searchFoodsWithStatus(query: String, ownerUserId: UUID? = nil) async throws -> FoodSearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return FoodSearchOutcome(items: [], source: .localCache)
        }

        var products: [Product] = []
        var usedRemoteSource = false
        var firstError: Error?

        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 365), !cached.isEmpty {
            let cachedMatches = cached
                .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
            products.append(contentsOf: cachedMatches.map(makeRawFoodProduct))
            if cachedMatches.isEmpty {
                do {
                    let rawFoods = try await catalogService.searchProducts(query: trimmed)
                    products.append(contentsOf: rawFoods
                        .filter { Self.searchMatches(query: trimmed, name: $0.name, brand: $0.brand) }
                        .map(makeRawFoodProduct))
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
                    return repository.getProductByBarcode(barcode, ownerUserId: ownerUserId) ?? product
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

    func makeUpgradedProduct(from product: Product, mapping: ProductMatchMapping, verified: Bool) -> Product {
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
            nutritionBasis: .per100g,
            sourceUpdatedAt: product.sourceUpdatedAt,
            sourceRevision: product.sourceRevision,
            sourceSchemaVersion: product.sourceSchemaVersion,
            fetchedAt: product.fetchedAt,
            nutriScoreInfo: product.nutriScoreInfo,
            processingInfo: product.processingInfo,
            dataQualityWarnings: product.dataQualityWarnings
        )
    }

    func makeRawFoodProduct(_ item: MatvaretabellenProduct) -> Product {
        FoodSearchCatalog.product(item)
    }

    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
