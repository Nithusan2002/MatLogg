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

struct FoodSearchLibrary {
    let products: [Product]
    let recent: [Product]
    let favorites: [Product]
    let suggestions: [Product]
    var recentFoods: [RecentFood] = []
}

@MainActor
protocol FoodSearchRepository {
    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func searchRemote(query: String, owner: UUID?) async throws -> [Product]
    func saveManual(_ product: Product, owner: UUID) async throws
    func prepare(_ product: Product, owner: UUID) async throws
    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome
}

extension FoodSearchRepository {
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

    init(products: any ProductRepository, catalog: any ProductCatalogService, remote: any ProductNameSearchService,
         recentFoods: any RecentFoodRepository) {
        self.products = products
        self.catalog = catalog
        self.remote = remote
        self.recentFoods = recentFoods
    }

    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        let stored = try await products.getSearchableProducts(ownerUserId: owner)
        let recent = if let owner { try await recentFoods.getRecentFoods(owner: owner, before: Date(), limit: 6) } else { [RecentFood]() }
        let favorites = if let owner { await products.getFavorites(userId: owner, kind: nil) } else { [Product]() }
        return FoodSearchLibrary(products: stored, recent: recent.map(\.product), favorites: favorites,
                                 suggestions: [], recentFoods: recent)
    }

    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        let local = try await loadLocalLibrary(owner: owner)
        let raw: [MatvaretabellenProduct]
        do {
            raw = try await catalog.fetchCommonFoods()
        } catch {
            if let cached = products.getMatvaretabellenCache(maxAgeDays: 365), !cached.isEmpty {
                raw = cached
            } else if !local.products.isEmpty {
                raw = []
            } else {
                throw error
            }
        }
        let rawProducts = raw.map(FoodSearchCatalog.product)
        return FoodSearchLibrary(
            products: FoodSearchMatcher.unique(local.products + rawProducts),
            recent: local.recent, favorites: local.favorites,
            suggestions: Array(rawProducts.prefix(8)), recentFoods: local.recentFoods
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
