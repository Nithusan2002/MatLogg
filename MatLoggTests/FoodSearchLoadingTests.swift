import Foundation
import Testing
@testable import MatLogg

@MainActor
struct FoodSearchLoadingTests {
    @Test func countryAndGlobalSearchHaveSeparateCaches() async throws {
        let products = LoadingSearchProducts()
        let remote = CountingNameSearch()
        let repository = DefaultFoodSearchRepository(products: products, catalog: LoadingCatalog(),
            remote: remote, recentFoods: products)
        let norwegian = Product(name: "Havre norsk", caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
        let global = Product(name: "Havre global", caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
        remote.result = [norwegian]
        _ = try await repository.searchRemote(query: "havre", owner: nil)
        remote.result = [global]
        let expanded = try await repository.searchRemote(query: "havre", owner: nil, scope: .global)
        let cached = try await repository.searchRemote(query: " HAVRE ", owner: nil)
        #expect(expanded.map(\.id) == [global.id])
        #expect(cached.map(\.id) == [norwegian.id])
        #expect(remote.calls == 2)
    }

    @Test func catalogStartsBeforeLocalReadCompletesAndLibraryIsReadOnlyOnce() async throws {
        let products = LoadingSearchProducts()
        let catalog = LoadingCatalog()
        let item = Product(name: "Havregryn", caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
        let repository = DefaultFoodSearchRepository(products: products, catalog: catalog,
            remote: LoadingNameSearch(), recentFoods: products)
        let model = FoodSearchViewModel(repository: repository)
        let load = Task { await model.load(owner: UUID()) }
        try await waitUntil { products.pending != nil && catalog.pending != nil }
        #expect(model.isLoading)
        #expect(model.isLoadingCatalog)
        products.pending?.resume(returning: [item])
        products.pending = nil
        try await waitUntil { !model.isLoading }
        #expect(model.isLoadingCatalog)
        model.setQuery("havre")
        try await waitUntil { model.results.map(\.id) == [item.id] }
        #expect(model.results.map(\.id) == [item.id])
        catalog.pending?.resume(returning: [])
        catalog.pending = nil
        await load.value
        #expect(products.localReadCount == 1)
        #expect(products.recentReadCount == 1)
        #expect(products.favoriteReadCount == 1)
        #expect(!model.isLoadingCatalog)
        #expect(model.results.map(\.id) == [item.id])
    }

    @Test func quickChoicesSkipTheFullProductLibrary() async throws {
        let products = LoadingSearchProducts()
        let repository = DefaultFoodSearchRepository(products: products, catalog: LoadingCatalog(),
            remote: LoadingNameSearch(), recentFoods: products)
        let model = QuickLogViewModel(repository: repository)
        await model.load(userId: UUID())
        #expect(products.localReadCount == 0)
        #expect(products.recentReadCount == 1)
        #expect(products.favoriteReadCount == 1)
        #expect(model.errorMessage == nil)
    }

    @Test func searchCacheExpiresAndStillReadsCurrentOwnerOverrides() async throws {
        let products = LoadingSearchProducts()
        let remote = CountingNameSearch()
        let publicProduct = Product(name: "Havre", barcodeEan: "123",
            caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
        remote.result = [publicProduct]
        var clock = Date(timeIntervalSince1970: 100)
        let repository = DefaultFoodSearchRepository(products: products, catalog: LoadingCatalog(),
            remote: remote, recentFoods: products, now: { clock })
        let owner = UUID()
        _ = try await repository.searchRemote(query: " HAVRE ", owner: owner)
        let edited = Product(name: "Havre", barcodeEan: "123",
            caloriesPer100g: 200, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
        products.override = edited
        let cached = try await repository.searchRemote(query: "havre", owner: owner)
        #expect(remote.calls == 1)
        #expect(cached.first?.caloriesPer100g == 200)
        #expect(products.barcodeOwners.count == 2)
        products.override = nil
        let otherOwner = UUID()
        let other = try await repository.searchRemote(query: "havre", owner: otherOwner)
        #expect(other.first?.id == publicProduct.id)
        #expect(products.barcodeOwners.last == otherOwner)
        clock = clock.addingTimeInterval(30 * 60)
        _ = try await repository.searchRemote(query: "havre", owner: owner)
        #expect(remote.calls == 2)
    }

    @Test func concurrentSearchesShareRequestAndFailuresCanRetry() async throws {
        let products = LoadingSearchProducts()
        let remote = CountingNameSearch()
        remote.suspend = true
        let repository = DefaultFoodSearchRepository(products: products, catalog: LoadingCatalog(),
            remote: remote, recentFoods: products)
        let first = Task { try await repository.searchRemote(query: "havre", owner: UUID()) }
        try await waitUntil { remote.pending != nil }
        let second = Task { try await repository.searchRemote(query: " HAVRE ", owner: UUID()) }
        for _ in 0..<20 { await Task.yield() }
        #expect(remote.calls == 1)
        remote.pending?.resume(throwing: URLError(.notConnectedToInternet))
        remote.pending = nil
        for task in [first, second] {
            do { _ = try await task.value; Issue.record("Expected network failure") }
            catch {}
        }
        remote.suspend = false
        _ = try await repository.searchRemote(query: "havre", owner: nil)
        _ = try await repository.searchRemote(query: "havre", owner: nil)
        #expect(remote.calls == 2)
    }

    @Test func cancelledCallerDoesNotCancelSharedSearchOrPublishResults() async throws {
        let products = LoadingSearchProducts()
        let remote = CountingNameSearch()
        remote.suspend = true
        let repository = DefaultFoodSearchRepository(products: products, catalog: LoadingCatalog(),
            remote: remote, recentFoods: products)
        let cancelled = Task { try await repository.searchRemote(query: "havre", owner: UUID()) }
        try await waitUntil { remote.pending != nil }
        let active = Task { try await repository.searchRemote(query: "havre", owner: nil) }
        for _ in 0..<20 { await Task.yield() }
        cancelled.cancel()
        remote.pending?.resume(returning: [])
        remote.pending = nil
        do { _ = try await cancelled.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
        _ = try await active.value
        #expect(remote.calls == 1)
        #expect(products.barcodeOwners.isEmpty)
    }

    @Test func searchCacheHasBoundedCapacity() async throws {
        let products = LoadingSearchProducts()
        let remote = CountingNameSearch()
        var clock = Date(timeIntervalSince1970: 100)
        let repository = DefaultFoodSearchRepository(products: products, catalog: LoadingCatalog(),
            remote: remote, recentFoods: products, now: { clock })
        for index in 0..<21 {
            clock = clock.addingTimeInterval(1)
            _ = try await repository.searchRemote(query: "vare \(index)", owner: nil)
        }
        _ = try await repository.searchRemote(query: "vare 0", owner: nil)
        #expect(remote.calls == 22)
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(predicate())
    }
}

@MainActor
private final class LoadingCatalog: ProductCatalogService {
    var pending: CheckedContinuation<[MatvaretabellenProduct], Error>?
    func fetchCommonFoods() async throws -> [MatvaretabellenProduct] {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    func searchProducts(query: String) async throws -> [MatvaretabellenProduct] { [] }
}

@MainActor
private final class LoadingSearchProducts: ProductRepository, RecentFoodRepository {
    var pending: CheckedContinuation<[Product], Error>?
    var override: Product?
    var barcodeOwners: [UUID?] = []
    var localReadCount = 0
    var recentReadCount = 0
    var favoriteReadCount = 0
    func getSearchableProducts(ownerUserId: UUID?) async throws -> [Product] {
        localReadCount += 1
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func getLoggedProductTimes(owner: UUID, before: Date) async throws -> [UUID: Date] { [:] }
    func getRecentFoods(owner: UUID, before: Date, limit: Int) async throws -> [RecentFood] {
        recentReadCount += 1
        return []
    }
    func getFavorites(userId: UUID, kind: ProductKind?) async -> [Product] {
        favoriteReadCount += 1
        return []
    }
    func saveProduct(_ product: Product, ownerUserId: UUID) async throws {}
    func cacheCatalogProduct(_ product: Product) async throws {}
    func getProduct(_ id: UUID) async -> Product? { nil }
    func getProductByBarcode(_ barcode: String, ownerUserId: UUID?) async -> Product? {
        barcodeOwners.append(ownerUserId)
        return override
    }
    func saveMatchMapping(_ mapping: ProductMatchMapping) {}
    func getMatchMapping(for barcode: String) -> ProductMatchMapping? { nil }
    func toggleFavorite(userId: UUID, productId: UUID) async throws {}
    func isFavorite(userId: UUID, productId: UUID) async -> Bool { false }
    func saveScanHistory(userId: UUID, productId: UUID) async throws {}
    func getRecentScans(userId: UUID, limit: Int) async -> [ScanHistory] { [] }
    func getRecentProducts(userId: UUID, kind: ProductKind?, limit: Int) async -> [Product] { [] }
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) async {}
    func getMatvaretabellenCache(maxAgeDays: Int) async -> [MatvaretabellenProduct]? { nil }
    func saveLog(_ log: FoodLog) async throws {}
}

private struct LoadingNameSearch: ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope) async throws -> [Product] { [] }
}


@MainActor
private final class CountingNameSearch: ProductNameSearchService {
    var calls = 0
    var result: [Product] = []
    var suspend = false
    var pending: CheckedContinuation<[Product], Error>?
    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope) async throws -> [Product] {
        calls += 1
        if suspend { return try await withCheckedThrowingContinuation { pending = $0 } }
        return result
    }
}
