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
        amountLabel = PortionDisplay.amount(Double(log.amountG), unit: log.resolvedAmountUnit, portion: log.portionSelection, preparation: log.nutritionPreparation)
        canRepeat = Self.canRepeat(product: product, log: log)
    }

    private static func canRepeat(product: Product, log: FoodLog) -> Bool {
        guard product.id == log.productId, product.amountUnit == log.resolvedAmountUnit,
              (product.nutritionPreparation ?? .asSold) == (log.nutritionPreparation ?? .asSold),
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
    func getLoggedProductTimes(owner: UUID, before: Date) async throws -> [UUID: Date]
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
    var loggedProductTimes: [UUID: Date] = [:]
}

@MainActor
protocol FoodSearchRepository {
    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func loadQuickChoices(owner: UUID?) async throws -> FoodSearchLibrary
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary
    func loadLibrary(owner: UUID?, onLocalLoaded: (FoodSearchLibrary) -> Void) async throws -> FoodSearchLibrary
    func searchRemote(query: String, owner: UUID?, scope: FoodSearchScope) async throws -> [Product]
    func saveManual(_ product: Product, owner: UUID) async throws
    func prepare(_ product: Product, owner: UUID) async throws
    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome
}

extension FoodSearchRepository {
    func searchRemote(query: String, owner: UUID?) async throws -> [Product] {
        try await searchRemote(query: query, owner: owner, scope: .norway)
    }

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
    private struct PendingSearch {
        let id: UUID
        let task: Task<[Product], Error>
        var callers: Set<UUID>
    }
    private var searches: [String: PendingSearch] = [:]
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
        let times = if let owner { try await recentFoods.getLoggedProductTimes(owner: owner, before: now()) } else { [UUID: Date]() }
        return FoodSearchLibrary(products: stored, recent: choices.recent, favorites: choices.favorites,
                                 suggestions: [], recentFoods: choices.recentFoods, loggedProductTimes: times)
    }

    func loadQuickChoices(owner: UUID?) async throws -> FoodSearchLibrary {
        let recent = if let owner { try await recentFoods.getRecentFoods(owner: owner, before: Date(), limit: 6) } else { [RecentFood]() }
        let favorites = if let owner { try await products.getFavorites(userId: owner, kind: nil) } else { [Product]() }
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
            if let cached = try? await products.getMatvaretabellenCache(maxAgeDays: 365), !cached.isEmpty {
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
            suggestions: merged.1, recentFoods: local.recentFoods, loggedProductTimes: local.loggedProductTimes
        )
    }

    func searchRemote(query: String, owner: UUID?, scope: FoodSearchScope) async throws -> [Product] {
        let timing = PerformanceSignposts.begin("Search.Remote")
        defer { PerformanceSignposts.end(timing) }
        let result = try await { () async throws -> [Product] in
            let timing = PerformanceSignposts.begin("Search.RemoteProviderOrCache")
            defer { PerformanceSignposts.end(timing) }
            return try await remoteResults(query: query, scope: scope)
        }()
        try Task.checkCancellation()
        let filtered = try await BackgroundWork.run {
            let timing = PerformanceSignposts.begin("Search.RemoteFilter")
            defer { PerformanceSignposts.end(timing) }
            return result.filter { FoodSearchMatcher.matches(query: query, name: $0.name, brand: $0.brand) }
        }
        let cacheTiming = PerformanceSignposts.begin("Search.RemoteCache")
        let cached = try await products.getProductsByBarcodes(Set(filtered.compactMap(\.barcodeEan)), ownerUserId: owner)
        PerformanceSignposts.end(cacheTiming)
        return filtered.map { product in
            guard let stored = product.barcodeEan.flatMap({ cached[$0] }) else { return product }
            return ProductPackageLabel.fillingMissingValue(in: stored, from: product)
        }
    }

    // Only public provider results are cached. Owner-specific overrides are read
    // on every search so edits and profile switches never reuse another owner's data.
    private func remoteResults(query: String, scope: FoodSearchScope) async throws -> [Product] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !normalizedQuery.isEmpty else { return [] }
        let key = scope.rawValue + ":" + normalizedQuery
        searchCache = searchCache.filter { $0.value.expiresAt > now() }
        if let cached = searchCache[key] { return cached.products }
        try Task.checkCancellation()
        let callerID = UUID()
        let pending: PendingSearch
        if var existing = searches[key], !existing.task.isCancelled {
            existing.callers.insert(callerID)
            searches[key] = existing
            pending = existing
        } else {
            let task = Task { [remote] in
                let timing = PerformanceSignposts.begin("Search.RemoteAPI")
                defer { PerformanceSignposts.end(timing) }
                return try await remote.searchProductsByNameOpenFoodFacts(normalizedQuery, scope: scope)
            }
            pending = PendingSearch(id: UUID(), task: task, callers: [callerID])
            searches[key] = pending
        }
        defer { releaseSearch(key: key, id: pending.id, caller: callerID) }
        let result = try await withTaskCancellationHandler {
            try await pending.task.value
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.releaseSearch(key: key, id: pending.id, caller: callerID)
            }
        }
        try Task.checkCancellation()
        if searchCache.count >= searchCacheLimit,
           let oldest = searchCache.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
            searchCache[oldest] = nil
        }
        searchCache[key] = SearchCacheEntry(products: result, expiresAt: now().addingTimeInterval(searchCacheLifetime))
        return result
    }

    // Cancel provider retries only when no screen still needs this shared request.
    private func releaseSearch(key: String, id: UUID, caller: UUID) {
        guard var pending = searches[key], pending.id == id else { return }
        pending.callers.remove(caller)
        if pending.callers.isEmpty {
            searches[key] = nil
            pending.task.cancel()
        } else {
            searches[key] = pending
        }
    }

    func saveManual(_ product: Product, owner: UUID) async throws {
        try await products.saveProduct(product, ownerUserId: owner)
    }

    func prepare(_ product: Product, owner: UUID) async throws {
        // Existing owner rows must not be converted into shared catalog cache.
        if product.source != "user", try await products.getProduct(product.id) == nil {
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
                          nutritionPreparation: candidate.product.nutritionPreparation, nutritionSource: candidate.product.nutritionSource, loggedDate: Calendar.current.startOfDay(for: date), loggedTime: Date(),
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

    // Text precision always precedes personal preferences. Position separates a food
    // named in its own right from the same word buried in a recipe's ingredients.
    struct Relevance: Comparable {
        let tier: Int
        let position: Int
        let extraWords: Int

        static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.tier != rhs.tier { return lhs.tier < rhs.tier }
            if lhs.position != rhs.position { return lhs.position < rhs.position }
            return lhs.extraWords < rhs.extraWords
        }
    }

    static func relevance(name: String, brand: String, normalizedQuery: String) -> Relevance {
        let tokens = normalizedQuery.split(separator: " ")
        let words = name.split(separator: " ")
        let brandWords = brand.split(separator: " ")
        let combined = words + brandWords
        func containsAll(_ candidates: [Substring]) -> Bool {
            tokens.allSatisfy { candidates.contains($0) }
        }
        func prefixesMatch(_ candidates: [Substring]) -> Bool {
            tokens.allSatisfy { token in candidates.contains { $0.hasPrefix(token) } }
        }
        let tier: Int
        if name == normalizedQuery { tier = 0 }
        else if containsAll(words) && words.count == tokens.count { tier = 1 }
        else if containsAll(words) { tier = 2 }
        else if containsAll(combined) { tier = tokens.count > 1 ? 2 : 3 }
        else if prefixesMatch(words) { tier = 4 }
        else if prefixesMatch(combined) { tier = tokens.count > 1 ? 4 : 5 }
        else { tier = 6 }
        let position = tokens.reduce(0) { total, token in
            // A brand stored separately has no position in the product name.
            total + (words.firstIndex { word in
                word == token || (tier >= 4 && word.hasPrefix(token))
            } ?? 0)
        }
        let queriesBrand = tokens.contains { token in
            brandWords.contains { $0 == token || (tier >= 4 && $0.hasPrefix(token)) }
        }
        // In multiword brand searches, short flavor-only titles should not beat
        // descriptive titles merely because the provider omitted words from the name.
        // Single-word brand searches retain name priority (Jarlsberg cheese before pizza).
        let extraWords = tokens.count > 1 && queriesBrand ? 0 : max(0, words.count - tokens.count)
        return Relevance(tier: tier, position: position, extraWords: extraWords)
    }

    static func precedes(_ lhs: Product, _ rhs: Product) -> Bool {
        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
        let brandOrder = (lhs.brand ?? "").localizedCaseInsensitiveCompare(rhs.brand ?? "")
        if brandOrder != .orderedSame { return brandOrder == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func sorted(_ products: [Product], query: String) -> [Product] {
        let normalizedQuery = normalized(query)
        return products.map {
            ($0, relevance(name: normalized($0.name), brand: normalized($0.brand ?? ""), normalizedQuery: normalizedQuery))
        }.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            return precedes($0.0, $1.0)
        }.map(\.0)
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

nonisolated struct FoodSearchResultSections: Sendable {
    let history: [Product]
    let other: [Product]
    let all: [Product]

    static let empty = FoodSearchResultSections(history: [], other: [], all: [])
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

    func sections(library: [Product], remote: [Product], query: String,
                  loggedProductTimes: [UUID: Date], favoriteIDs: Set<UUID> = []) throws -> FoodSearchResultSections {
        let matches = try results(library: library, remote: remote, query: query,
                                  favoriteIDs: favoriteIDs, loggedProductTimes: loggedProductTimes)
        let normalizedQuery = FoodSearchMatcher.normalized(query)
        func relevance(_ product: Product) -> FoodSearchMatcher.Relevance {
            let field = fields[product.id]
            return FoodSearchMatcher.relevance(name: field?.name ?? "", brand: field?.brand ?? "",
                                               normalizedQuery: normalizedQuery)
        }
        let best = matches.first.map(relevance)
        // Weaker history remains in other results, so it cannot displace a more
        // precise unlogged product simply because it was used recently.
        let history = Array(matches.filter {
            loggedProductTimes[$0.id] != nil && relevance($0) == best
        }.sorted {
            if favoriteIDs.contains($0.id) != favoriteIDs.contains($1.id) { return favoriteIDs.contains($0.id) }
            let left = loggedProductTimes[$0.id] ?? .distantPast
            let right = loggedProductTimes[$1.id] ?? .distantPast
            if left != right { return left > right }
            return $0.id.uuidString < $1.id.uuidString
        }.prefix(3))
        let historyIDs = Set(history.map(\.id))
        let other = matches.filter { !historyIDs.contains($0.id) }
        return FoodSearchResultSections(history: history, other: other, all: history + other)
    }

    func results(library: [Product], remote: [Product], query: String,
                 favoriteIDs: Set<UUID> = [], loggedProductTimes: [UUID: Date] = [:]) throws -> [Product] {
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
        var matching: [Product] = []
        for product in library + remote {
            try Task.checkCancellation()
            let field = indexed(product)
            if tokens.allSatisfy({ field.searchable.contains($0) }) { matching.append(product) }
        }
        // Local rows still own identity and nutrition after deduplication. A fresh
        // matching public source may contribute only a missing package label.
        var packageSourcesByID: [UUID: Product] = [:]
        var packageSourcesByBarcode: [String: Product] = [:]
        for product in remote where product.packageQuantityLabel != nil {
            if packageSourcesByID[product.id] == nil { packageSourcesByID[product.id] = product }
            if let barcode = product.barcodeEan, !barcode.isEmpty, packageSourcesByBarcode[barcode] == nil {
                packageSourcesByBarcode[barcode] = product
            }
        }
        let ranked = FoodSearchMatcher.unique(matching).map { original in
            let incoming = packageSourcesByID[original.id]
                ?? original.barcodeEan.flatMap { packageSourcesByBarcode[$0] }
            let product = incoming.map { ProductPackageLabel.fillingMissingValue(in: original, from: $0) } ?? original
            let field = indexed(product)
            return (product, FoodSearchMatcher.relevance(name: field.name, brand: field.brand,
                                                        normalizedQuery: normalizedQuery))
        }
        try Task.checkCancellation()
        return ranked.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            let left = $0.0, right = $1.0
            if favoriteIDs.contains(left.id) != favoriteIDs.contains(right.id) { return favoriteIDs.contains(left.id) }
            let leftTime = loggedProductTimes[left.id] ?? .distantPast
            let rightTime = loggedProductTimes[right.id] ?? .distantPast
            if leftTime != rightTime { return leftTime > rightTime }
            return FoodSearchMatcher.precedes(left, right)
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
