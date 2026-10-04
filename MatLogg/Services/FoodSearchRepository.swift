import Foundation

nonisolated struct RecentFood: Identifiable, Sendable {
    let product: Product
    let log: FoodLog
    let amountLabel: String
    let canRepeat: Bool
    var id: UUID { product.id }

    init(product: Product, log: FoodLog) {
        self.product = product
        self.log = log
        amountLabel = PortionDisplay.amount(Double(log.amountG), unit: log.resolvedAmountUnit, portion: log.portionSelection)
        canRepeat = Self.canRepeat(product: product, log: log)
    }

    private static func canRepeat(product: Product, log: FoodLog) -> Bool {
        guard product.id == log.productId, product.amountUnit == log.resolvedAmountUnit,
              NutritionCalculator.validatedCalculation(per100: NutritionBreakdown(
                calories: product.caloriesPer100g, protein: product.proteinGPer100g,
                carbs: product.carbsGPer100g, fat: product.fatGPer100g), amount: log.amountG) != nil else { return false }
        guard let portion = log.portionSelection else { return true }
        return portion.matches(amount: Double(log.amountG), unit: product.amountUnit)
            && (product.servings ?? []).contains {
                $0.portionLabel == portion.label && $0.grams == portion.amountPerServing
                    && $0.amountUnit == portion.unit && $0.source == portion.source
                    && $0.selectableKind == portion.kind
            }
    }
}

protocol RecentFoodRepository {
    func getRecentFoods(owner: UUID, before: Date, limit: Int) async throws -> [RecentFood]
    func saveLog(_ log: FoodLog) async throws
}

enum RepeatFoodOutcome {
    case logged(Product, FoodLog)
    case review(Product)
}

nonisolated struct FoodSearchLibrary: Sendable {
    let products: [Product]
    let recent: [Product]
    let favorites: [Product]
    let suggestions: [Product]
    var recentFoods: [RecentFood] = []
}

@MainActor
protocol FoodSearchRepository {
    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func loadQuickChoices(owner: UUID?) async throws -> FoodSearchLibrary
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func loadLibrary(owner: UUID?, onLocalLoaded: (FoodSearchLibrary) -> Void) async throws -> FoodSearchLibrary
    func searchRemote(query: String, owner: UUID?) async throws -> [Product]
    func saveManual(_ product: Product, owner: UUID) async throws
    func prepare(_ product: Product, owner: UUID) async throws
    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome
}

extension FoodSearchRepository {
    func loadQuickChoices(owner: UUID?) async throws -> FoodSearchLibrary {
        try await loadLocalLibrary(owner: owner)
    }

    func loadLibrary(owner: UUID?, onLocalLoaded: (FoodSearchLibrary) -> Void) async throws -> FoodSearchLibrary {
        onLocalLoaded(try await loadLocalLibrary(owner: owner))
        return try await loadLibrary(owner: owner)
    }

    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome {
        throw DatabaseServiceError.unavailable
    }
    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        FoodSearchLibrary(products: [], recent: [], favorites: [], suggestions: [])
    }
}

@MainActor
final class DefaultFoodSearchRepository: FoodSearchRepository {
    private let products: any ProductRepository
    private let catalog: any ProductCatalogService
    private let remote: any ProductNameSearchService
    private let recentFoods: any RecentFoodRepository
    private let projection = FoodCatalogProjection()
    private struct SearchCacheEntry {
        let products: [Product]
        let expiresAt: Date
    }
    private var searchCache: [String: SearchCacheEntry] = [:]
    private var searches: [String: Task<[Product], Error>] = [:]
    private let now: () -> Date
    private let searchCacheLifetime: TimeInterval
    private let searchCacheLimit = 20

    init(products: any ProductRepository, catalog: any ProductCatalogService, remote: any ProductNameSearchService,
         recentFoods: any RecentFoodRepository, now: @escaping () -> Date = Date.init,
         searchCacheLifetime: TimeInterval = 30 * 60) {
        self.products = products
        self.catalog = catalog
        self.remote = remote
        self.recentFoods = recentFoods
        self.now = now
        self.searchCacheLifetime = searchCacheLifetime
    }

    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        let timing = PerformanceSignposts.begin("Search.LocalLibrary")
        defer { PerformanceSignposts.end(timing) }
        let stored = try await products.getSearchableProducts(ownerUserId: owner)
        let choices = try await loadQuickChoices(owner: owner)
        return FoodSearchLibrary(products: stored, recent: choices.recent, favorites: choices.favorites,
                                 suggestions: [], recentFoods: choices.recentFoods)
    }

    func loadQuickChoices(owner: UUID?) async throws -> FoodSearchLibrary {
        let recent = if let owner { try await recentFoods.getRecentFoods(owner: owner, before: Date(), limit: 6) } else { [RecentFood]() }
        let favorites = if let owner { await products.getFavorites(userId: owner, kind: nil) } else { [Product]() }
        return FoodSearchLibrary(products: [], recent: recent.map(\.product), favorites: favorites,
                                 suggestions: [], recentFoods: recent)
    }

    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        try await loadLibrary(owner: owner, onLocalLoaded: { _ in })
    }

    func loadLibrary(owner: UUID?, onLocalLoaded: (FoodSearchLibrary) -> Void) async throws -> FoodSearchLibrary {
        let timing = PerformanceSignposts.begin("Search.Library")
        defer { PerformanceSignposts.end(timing) }
        async let catalogItems = catalog.fetchCommonFoods()
        let local = try await loadLocalLibrary(owner: owner)
        try Task.checkCancellation()
        onLocalLoaded(local)
        let raw: [MatvaretabellenProduct]
        do {
            raw = try await catalogItems
        } catch {
            if let cached = await products.getMatvaretabellenCache(maxAgeDays: 365), !cached.isEmpty {
                raw = cached
            } else if !local.products.isEmpty {
                raw = []
            } else {
                throw error
            }
        }
        let rawProducts = try await projection.products(for: raw)
        let merged = try await BackgroundWork.run {
            let timing = PerformanceSignposts.begin("Search.Merge")
            defer { PerformanceSignposts.end(timing) }
            return (FoodSearchMatcher.unique(local.products + rawProducts), Array(rawProducts.prefix(8)))
        }
        return FoodSearchLibrary(
            products: merged.0,
            recent: local.recent, favorites: local.favorites,
            suggestions: merged.1, recentFoods: local.recentFoods
        )
    }

    func searchRemote(query: String, owner: UUID?) async throws -> [Product] {
        let timing = PerformanceSignposts.begin("Search.Remote")
        defer { PerformanceSignposts.end(timing) }
        let result = try await { () async throws -> [Product] in
            let timing = PerformanceSignposts.begin("Search.RemoteProviderOrCache")
            defer { PerformanceSignposts.end(timing) }
            return try await remoteResults(query: query)
        }()
        try Task.checkCancellation()
        let filtered = try await BackgroundWork.run {
            let timing = PerformanceSignposts.begin("Search.RemoteFilter")
            defer { PerformanceSignposts.end(timing) }
            return result.filter { FoodSearchMatcher.matches(query: query, name: $0.name, brand: $0.brand) }
        }
        let cacheTiming = PerformanceSignposts.begin("Search.RemoteCache")
        let cached = await products.getProductsByBarcodes(Set(filtered.compactMap(\.barcodeEan)), ownerUserId: owner)
        PerformanceSignposts.end(cacheTiming)
        return filtered.map { product in
            product.barcodeEan.flatMap { cached[$0] } ?? product
        }
    }

    // Only public provider results are cached. Owner-specific overrides are read
    // on every search so edits and profile switches never reuse another owner's data.
    private func remoteResults(query: String) async throws -> [Product] {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !key.isEmpty else { return [] }
        searchCache = searchCache.filter { $0.value.expiresAt > now() }
        if let cached = searchCache[key] { return cached.products }
        if let pending = searches[key] { return try await pending.value }
        let task = Task { [remote] in
            let timing = PerformanceSignposts.begin("Search.RemoteAPI")
            defer { PerformanceSignposts.end(timing) }
            return try await remote.searchProductsByNameOpenFoodFacts(key)
        }
        searches[key] = task
        defer { searches[key] = nil }
        let result = try await task.value
        if searchCache.count >= searchCacheLimit,
           let oldest = searchCache.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
            searchCache[oldest] = nil
        }
        searchCache[key] = SearchCacheEntry(products: result, expiresAt: now().addingTimeInterval(searchCacheLifetime))
        return result
    }

    func saveManual(_ product: Product, owner: UUID) async throws {
        try await products.saveProduct(product, ownerUserId: owner)
    }

    func prepare(_ product: Product, owner: UUID) async throws {
        // Existing owner rows must not be converted into shared catalog cache.
        if product.source != "user", await products.getProduct(product.id) == nil {
            try await products.cacheCatalogProduct(product)
        }
    }

    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome {
        guard food.log.userId == owner, ["frokost", "lunsj", "middag", "snacks"].contains(mealType),
              date.timeIntervalSince1970.isFinite else { throw DatabaseServiceError.unavailable }
        // Recheck ownership, current product data and the last logged amount before writing.
        let current = try await recentFoods.getRecentFoods(owner: owner, before: Date(), limit: 6)
        guard let candidate = current.first(where: { $0.id == food.id }) else { throw DatabaseServiceError.unavailable }
        guard candidate.log.id == food.log.id, candidate.canRepeat,
              let nutrition = NutritionCalculator.validatedCalculation(per100: NutritionBreakdown(
                calories: candidate.product.caloriesPer100g, protein: candidate.product.proteinGPer100g,
                carbs: candidate.product.carbsGPer100g, fat: candidate.product.fatGPer100g), amount: candidate.log.amountG)
        else { return .review(candidate.product) }
        let log = FoodLog(userId: owner, productId: candidate.id, mealType: mealType,
                          amountG: candidate.log.amountG, amountUnit: candidate.log.resolvedAmountUnit,
                          portionSelection: candidate.log.portionSelection,
                          loggedDate: Calendar.current.startOfDay(for: date), loggedTime: Date(),
                          calories: nutrition.calories, proteinG: nutrition.protein,
                          carbsG: nutrition.carbs, fatG: nutrition.fat)
        try await recentFoods.saveLog(log)
        return .logged(candidate.product, log)
    }
}

nonisolated enum FoodSearchMatcher {
    static func matches(query: String, name: String, brand: String? = nil) -> Bool {
        let tokens = normalized(query).split(separator: " ")
        guard !tokens.isEmpty else { return false }
        let searchableText = normalized([name, brand].compactMap { $0 }.joined(separator: " "))
        return tokens.allSatisfy { searchableText.contains($0) }
    }

    static func sorted(_ products: [Product], query: String) -> [Product] {
        let normalizedQuery = normalized(query)
        return products.map { ($0, relevance(of: $0, normalizedQuery: normalizedQuery)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.name.localizedCaseInsensitiveCompare(rhs.0.name) == .orderedAscending
            }.map(\.0)
    }

    private static func relevance(of product: Product, normalizedQuery: String) -> Int {
        let name = normalized(product.name)
        let brand = normalized(product.brand ?? "")
        if name == normalizedQuery { return 0 }
        if name.hasPrefix(normalizedQuery) { return 1 }
        if brand == normalizedQuery { return 2 }
        if name.contains(normalizedQuery) { return 3 }
        return 4
    }

    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum FoodSearchCatalog {
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
    nonisolated static func unique(_ products: [Product]) -> [Product] {
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

/// Actor-owned index reuses normalized fields across keystrokes and library loads.
actor FoodSearchIndex {
    private struct Fields {
        let originalName: String
        let originalBrand: String?
        let name: String
        let brand: String
        let searchable: String
    }
    private var fields: [UUID: Fields] = [:]

    func results(library: [Product], remote: [Product], query: String) throws -> [Product] {
        let timing = PerformanceSignposts.begin("Search.Index")
        defer { PerformanceSignposts.end(timing) }
        let normalizedQuery = FoodSearchMatcher.normalized(query)
        let tokens = normalizedQuery.split(separator: " ")
        guard !tokens.isEmpty else { return [] }
        let activeIDs = Set((library + remote).map(\.id))
        fields = fields.filter { activeIDs.contains($0.key) }
        func indexed(_ product: Product) -> Fields {
            if let stored = fields[product.id], stored.originalName == product.name, stored.originalBrand == product.brand {
                return stored
            }
            let name = FoodSearchMatcher.normalized(product.name)
            let brand = FoodSearchMatcher.normalized(product.brand ?? "")
            let value = Fields(originalName: product.name, originalBrand: product.brand,
                               name: name, brand: brand, searchable: name + " " + brand)
            fields[product.id] = value
            return value
        }
        var local: [Product] = []
        for product in library {
            try Task.checkCancellation()
            let field = indexed(product)
            if tokens.allSatisfy({ field.searchable.contains($0) }) { local.append(product) }
        }
        let ranked = FoodSearchMatcher.unique(local + remote).map { product in
            let field = indexed(product)
            let score: Int
            if field.name == normalizedQuery { score = 0 }
            else if field.name.hasPrefix(normalizedQuery) { score = 1 }
            else if field.brand == normalizedQuery { score = 2 }
            else if field.name.contains(normalizedQuery) { score = 3 }
            else { score = 4 }
            return (product, score)
        }
        try Task.checkCancellation()
        return ranked.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
        }.map(\.0)
    }
}

actor FoodCatalogProjection {
    private var input: [MatvaretabellenProduct] = []
    private var projected: [Product] = []

    func products(for catalog: [MatvaretabellenProduct]) throws -> [Product] {
        let timing = PerformanceSignposts.begin("Catalog.Projection")
        defer { PerformanceSignposts.end(timing) }
        try Task.checkCancellation()
        guard input != catalog else { return projected }
        let products = catalog.map(FoodSearchCatalog.product)
        try Task.checkCancellation()
        input = catalog
        projected = products
        return products
    }
}
