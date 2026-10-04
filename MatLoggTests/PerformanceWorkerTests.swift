import Foundation
import Testing
@testable import MatLogg

@MainActor
struct PerformanceWorkerTests {
    @Test func backgroundWorkLeavesMainThreadAndPropagatesErrors() async throws {
        let onMainThread = try await BackgroundWork.run { Thread.isMainThread }
        #expect(!onMainThread)
        await #expect(throws: CocoaError.self) {
            try await BackgroundWork.run { () -> Int in throw CocoaError(.fileReadCorruptFile) }
        }
    }

    @Test func cancelledWorkCannotPublishAResult() async {
        let task = Task { try await BackgroundWork.run { 42 } }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func searchIndexReplacesChangedFieldsAndKeepsLatestNutrition() async throws {
        let index = FoodSearchIndex()
        let id = UUID()
        let original = Product(id: id, name: "Havregryn", brand: "Blå", caloriesPer100g: 100,
                               proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        let first = try await index.results(library: [original], remote: [], query: "bla havre")
        #expect(first.map(\.id) == [id])
        let renamed = Product(id: id, name: "Melk", brand: "Blå", caloriesPer100g: 200,
                              proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        #expect(try await index.results(library: [renamed], remote: [], query: "havre").isEmpty)
        let second = try await index.results(library: [renamed], remote: [], query: "melk")
        #expect(second.first?.caloriesPer100g == 200)
        #expect(try await index.results(library: [], remote: [], query: "melk").isEmpty)
    }

    @Test func boundedHistoryPreservesOwnerAndExclusiveEndDate() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("history.sqlite"))
        let database = DatabaseService(store: store)
        let owner = UUID(), other = UUID()
        let food = Product(name: "Testmat", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        try store.cacheCatalogProduct(food)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86_400)
        func log(owner: UUID, date: Date) -> FoodLog {
            FoodLog(userId: owner, productId: food.id, mealType: "frokost", amountG: 100,
                    loggedDate: date, loggedTime: date, calories: 100, proteinG: 1, carbsG: 2, fatG: 3)
        }
        let included = log(owner: owner, date: start)
        try store.saveLogs([included, log(owner: owner, date: start.addingTimeInterval(-1)),
                            log(owner: owner, date: end), log(owner: other, date: start)])
        let count = store.pendingSyncCount()
        let loaded = await database.getLogs(userId: owner, from: start, before: end)
        #expect(loaded.map(\.id) == [included.id])
        #expect(store.pendingSyncCount() == count)
        #expect(await database.getProduct(food.id)?.id == food.id)
    }
    @Test func startupWaitsForDatabaseAndPublishesControlledFailure() async throws {
        let suite = "startup-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var completion: CheckedContinuation<DatabaseService, Never>?
        let mode = DemoMode(selectionDefaults: defaults, demoDefaults: nil,
            directory: FileManager.default.temporaryDirectory, openDatabase: {
                await withCheckedContinuation { completion = $0 }
            })
        #expect(!mode.isReady)
        let restore = Task { await mode.restore() }
        while completion == nil { await Task.yield() }
        #expect(mode.isLoading)
        #expect(!mode.isReady)
        completion?.resume(returning: DatabaseService(storeResult: .failure(DatabaseServiceError.unavailable)))
        await restore.value
        #expect(mode.isReady)
        #expect(!mode.isLoading)
        #expect(!mode.database.isAvailable)
        #expect(mode.database.startupError != nil)
    }

    @Test func batchBarcodeLookupPrefersOwnerAndExcludesOtherProfiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("barcodes.sqlite"))
        let database = DatabaseService(store: store)
        let owner = UUID(), other = UUID()
        func food(name: String, code: String) -> Product {
            Product(name: name, barcodeEan: code, caloriesPer100g: 100,
                    proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        }
        let shared = food(name: "Katalog", code: "1234567890123")
        let own = food(name: "Egen", code: "1234567890123")
        let foreign = food(name: "Annen profil", code: "9999999999999")
        try store.cacheCatalogProduct(shared)
        try store.saveProduct(own, ownerUserId: owner)
        try store.saveProduct(foreign, ownerUserId: other)
        let codes: Set<String> = ["1234567890123", "9999999999999", "missing"]
        let count = store.pendingSyncCount()
        let owned = await database.getProductsByBarcodes(codes, ownerUserId: owner)
        #expect(owned.count == 1)
        #expect(owned["1234567890123"]?.id == own.id)
        let catalog = await database.getProductsByBarcodes(codes, ownerUserId: nil)
        #expect(catalog.count == 1)
        #expect(catalog["1234567890123"]?.id == shared.id)
        #expect(store.pendingSyncCount() == count)
    }

    @Test func lateFavoriteLoadCannotOverwriteToggleOrProfileReset() async throws {
        let favorites = PerformanceFavorites()
        let product = Product(name: "Testmat", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        let model = ProductDetailViewModel(product: product, repository: PerformanceBarcodeRepository(), favorites: favorites)
        let owner = UUID()
        let load = Task { await model.loadFavorite(owner: owner) }
        while favorites.pending == nil { await Task.yield() }
        #expect(await model.toggleFavorite(owner: owner))
        #expect(!model.isFavorite)
        favorites.pending?.resume(returning: true)
        await load.value
        #expect(!model.isFavorite)
        #expect(!model.isChangingFavorite)
        favorites.delayNext = true
        let older = Task { await model.loadFavorite(owner: owner) }
        while !favorites.isWaiting { await Task.yield() }
        await model.loadFavorite(owner: nil)
        favorites.pending?.resume(returning: true)
        await older.value
        #expect(!model.isFavorite)
    }

}


@MainActor
private final class PerformanceFavorites: ProductFavoriteRepository {
    var pending: CheckedContinuation<Bool, Never>?
    var delayNext = true
    var isWaiting = false
    private var value = true

    func isFavorite(userId: UUID, productId: UUID) async -> Bool {
        if delayNext {
            delayNext = false
            isWaiting = true
            defer { isWaiting = false; pending = nil }
            return await withCheckedContinuation { pending = $0 }
        }
        return value
    }

    func toggleFavorite(userId: UUID, productId: UUID) async throws { value.toggle() }
}

@MainActor
private struct PerformanceBarcodeRepository: BarcodeLookupRepository {
    func cached(barcode: String, owner: UUID?) async -> Product? { nil }
    func fetch(barcode: String) async throws -> Product { throw URLError(.notConnectedToInternet) }
    func refresh(_ product: Product, manually: Bool) async throws -> Product? { nil }
}
