import Foundation
import Testing
@testable import MatLogg

@MainActor
struct FoodSearchTests {
    @Test func historyMatchesAreLimitedPreciseAndResetWithOwnerOrQuery() async {
        let repository = SearchRepositoryStub()
        let foods = [product("Yoghurt vanilje"), product("Yoghurt jordbær"),
                     product("Yoghurt naturell"), product("Yoghurt gresk"), product("Yoghurt ny")]
        let times = Dictionary(uniqueKeysWithValues: foods.prefix(4).enumerated().map {
            ($0.element.id, Date(timeIntervalSince1970: Double(100 + $0.offset)))
        })
        repository.library = FoodSearchLibrary(products: foods, recent: [], favorites: [], suggestions: [],
                                                loggedProductTimes: times)
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("yoghurt")
        await waitUntil { vm.resultSections.history.count == 3 }
        #expect(vm.resultSections.history.map(\.id) == [foods[3].id, foods[2].id, foods[1].id])
        #expect(Set(vm.results.map(\.id)).count == 5)
        #expect(Set(vm.resultSections.other.map(\.id)) == [foods[0].id, foods[4].id])
        #expect(repository.requests.isEmpty)
        vm.setQuery("YOGHURT jordbær")
        await waitUntil { vm.results.map(\.id) == [foods[1].id] }
        #expect(vm.resultSections.history.map(\.id) == [foods[1].id])
        #expect(vm.resultSections.other.isEmpty)
        vm.setQuery("yoghurt ny")
        await waitUntil { vm.results.map(\.id) == [foods[4].id] }
        #expect(vm.resultSections.history.isEmpty)
        vm.setQuery("")
        #expect(vm.results.isEmpty && vm.resultSections.history.isEmpty)
        repository.library = FoodSearchLibrary(products: foods, recent: [], favorites: [], suggestions: [])
        await vm.load(owner: UUID())
        vm.setQuery("yoghurt")
        await waitUntil { vm.results.count == 5 }
        #expect(vm.resultSections.history.isEmpty)
        #expect(vm.resultSections.other.count == 5)
    }

    @Test func historyHasStableTiesAndDeduplicatesRemoteBarcodes() async throws {
        let index = FoodSearchIndex()
        let first = Product(id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
                            name: "Yoghurt A", barcodeEan: "123", caloriesPer100g: 100,
                            proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        let second = product("Yoghurt B")
        let duplicate = Product(name: "Yoghurt kopi", barcodeEan: "123", caloriesPer100g: 100,
                                proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        let times = [first.id: Date(timeIntervalSince1970: 100), second.id: Date(timeIntervalSince1970: 100)]
        let result = try await index.sections(library: [second, first], remote: [duplicate, first],
                                              query: "yoghurt", loggedProductTimes: times)
        #expect(result.history.map(\.id) == [first.id, second.id])
        #expect(result.all.count == 2 && result.other.isEmpty)
        #expect(try await index.sections(library: [first], remote: [], query: " ", loggedProductTimes: times).all.isEmpty)
    }

    @Test func globalExpansionPreservesFirstResultsDeduplicatesAndResetsOnEdit() async {
        let repository = SearchRepositoryStub()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("havre")
        #expect(!vm.canSearchGlobally)
        vm.search()
        await repository.waitForRequests(1)
        let norwegian = product("Havre norsk")
        repository.requests[0].resume(returning: [norwegian])
        await waitUntil { vm.phase == .complete }
        vm.searchGlobally()
        await repository.waitForRequests(2)
        #expect(repository.scopes == [.norway, .global])
        #expect(vm.results.map(\.id) == [norwegian.id])
        let international = product("Havre global")
        repository.requests[1].resume(returning: [norwegian, international, international])
        await waitUntil { vm.hasSearchedGlobally }
        #expect(vm.globalResults.map(\.id) == [international.id])
        #expect(vm.results.map(\.id) == [norwegian.id])
        vm.setQuery("melk")
        #expect(vm.globalResults.isEmpty)
        #expect(!vm.hasSearchedGlobally)
        #expect(!vm.canSearchGlobally)
    }

    @Test func globalFailureKeepsResultsAndRetryDiscardsStaleResponse() async {
        let repository = SearchRepositoryStub()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("havre")
        vm.search()
        await repository.waitForRequests(1)
        let norwegian = product("Havre norsk")
        repository.requests[0].resume(returning: [norwegian])
        await waitUntil { vm.phase == .complete }
        vm.searchGlobally()
        await repository.waitForRequests(2)
        repository.requests[1].resume(throwing: URLError(.notConnectedToInternet))
        await waitUntil { vm.globalSearchError != nil }
        #expect(vm.results.map(\.id) == [norwegian.id])
        #expect(vm.canSearchGlobally)
        vm.searchGlobally()
        await repository.waitForRequests(3)
        vm.setQuery("melk")
        repository.requests[2].resume(returning: [product("Havre gammel")])
        await Task.yield()
        #expect(vm.globalResults.isEmpty)
        #expect(!vm.isSearchingGlobally)
        #expect(vm.globalSearchError == nil)
    }

    @Test func localProductsRemainUsableWhileCatalogIsLoadingAndAfterFailure() async {
        let repository = SearchRepositoryStub()
        let owner = UUID()
        let oats = product("Havregryn")
        repository.library = FoodSearchLibrary(products: [oats], recent: [oats], favorites: [oats], suggestions: [])
        repository.delayedOwner = owner
        let vm = FoodSearchViewModel(repository: repository)
        let load = Task { await vm.load(owner: owner) }
        await waitUntil { repository.libraryRequest != nil }
        #expect(!vm.isLoading)
        #expect(vm.isLoadingCatalog)
        #expect(vm.favorites.map(\.id) == [oats.id])
        vm.setQuery("havre")
        await waitUntil { vm.results.map(\.id) == [oats.id] }
        #expect(vm.results.map(\.id) == [oats.id])
        await vm.open(oats)
        #expect(vm.selectedProduct?.id == oats.id)
        repository.libraryRequest?.resume(throwing: URLError(.notConnectedToInternet))
        await load.value
        #expect(!vm.isLoadingCatalog)
        #expect(vm.loadError != nil)
        #expect(vm.results.map(\.id) == [oats.id])
    }

    @Test func typingUsesLocalNamesAndBrandsWithoutNetworkAndClearRestoresLibrary() async {
        let repository = SearchRepositoryStub()
        let oats = product("Havregryn", brand: "Testmerke")
        repository.library = FoodSearchLibrary(products: [oats], recent: [oats], favorites: [oats], suggestions: [])
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("testmerke havre")
        await waitUntil { vm.results.map(\.id) == [oats.id] }
        #expect(vm.results.map(\.id) == [oats.id])
        #expect(repository.requests.isEmpty)
        #expect(vm.recent.map(\.id) == [oats.id])
        #expect(vm.favorites.map(\.id) == [oats.id])
        vm.setQuery("   ")
        #expect(!vm.hasQuery)
        #expect(vm.results.isEmpty)
        #expect(vm.favorites.count == 1)
    }

    @Test func networkFailurePreservesLocalResultsAndRetryAddsDeduplicatedProducts() async throws {
        let repository = SearchRepositoryStub()
        let oats = product("Havregryn")
        let branded = product("Havregryn", brand: "Pakke")
        repository.library = FoodSearchLibrary(products: [oats], recent: [], favorites: [], suggestions: [])
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("havre")
        await waitUntil { vm.results.map(\.id) == [oats.id] }
        vm.search()
        await repository.waitForRequests(1)
        #expect(vm.results.map(\.id) == [oats.id])
        repository.requests[0].resume(throwing: URLError(.notConnectedToInternet))
        await waitUntil { vm.phase == .offline }
        #expect(vm.searchError != nil)
        #expect(vm.results.map(\.id) == [oats.id])
        vm.search()
        await repository.waitForRequests(2)
        repository.requests[1].resume(returning: [oats, branded])
        await waitUntil { vm.phase == .complete }
        #expect(vm.results.count == 2)
        #expect(vm.searchError == nil)
    }

    @Test func olderSameQueryResponseCannotReplaceNewerSearch() async {
        let repository = SearchRepositoryStub()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("havre")
        vm.search()
        await repository.waitForRequests(1)
        vm.search()
        await repository.waitForRequests(2)
        let latest = product("Havre ny")
        repository.requests[1].resume(returning: [latest])
        await waitUntil { vm.phase == .complete }
        repository.requests[0].resume(returning: [product("Havre gammel")])
        await Task.yield()
        #expect(vm.results.map(\.id) == [latest.id])
    }

    @Test func editingAndProfileChangesDiscardPendingNetworkResults() async {
        let repository = SearchRepositoryStub()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("havre")
        vm.search()
        await repository.waitForRequests(1)
        vm.setQuery("melk")
        repository.requests[0].resume(returning: [product("Havre")])
        await Task.yield()
        #expect(vm.query == "melk")
        #expect(vm.results.isEmpty)
        vm.search()
        await repository.waitForRequests(2)
        await vm.load(owner: UUID())
        repository.requests[1].resume(returning: [product("Melk")])
        await Task.yield()
        #expect(vm.query.isEmpty)
        #expect(vm.results.isEmpty)
        #expect(vm.selectedProduct == nil)
    }

    @Test func ownerChangeRejectsDelayedLibraryResponse() async {
        let repository = SearchRepositoryStub()
        let firstOwner = UUID()
        repository.delayedOwner = firstOwner
        let vm = FoodSearchViewModel(repository: repository)
        let first = Task { await vm.load(owner: firstOwner) }
        await waitUntil { repository.libraryRequest != nil }
        let current = product("Ny profil")
        repository.library = FoodSearchLibrary(products: [current], recent: [current], favorites: [], suggestions: [])
        await vm.load(owner: UUID())
        repository.libraryRequest?.resume(returning: FoodSearchLibrary(
            products: [], recent: [product("Annen profils vare")], favorites: [], suggestions: []
        ))
        await first.value
        #expect(vm.recent.map(\.id) == [current.id])
    }

    @Test func preparationFailureDoesNotOpenProductAndCanBeRetried() async {
        let repository = SearchRepositoryStub()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        let item = product("Melk")
        repository.prepareFails = true
        await vm.open(item)
        #expect(vm.selectedProduct == nil)
        #expect(vm.selectionError != nil)
        #expect(!vm.isPreparing)
        repository.prepareFails = false
        await vm.open(item)
        #expect(vm.selectedProduct?.id == item.id)
        #expect(vm.selectionError == nil)
    }

    @Test func quickPreparationNeverShowsIndicator() async {
        let repository = SearchRepositoryStub()
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        await vm.open(product("Melk"))
        try? await Task.sleep(for: .milliseconds(240))
        #expect(vm.selectedProduct != nil)
        await vm.open(product("Havre"))
        #expect(repository.prepareCount == 1)
        #expect(vm.preparingProductID == nil)
        #expect(!vm.isPreparing)
    }

    @Test func slowPreparationShowsOnlySelectedRowAndIgnoresDoubleTap() async {
        let repository = SearchRepositoryStub()
        repository.delayPreparation = true
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        let item = product("Melk")
        let opening = Task { await vm.open(item) }
        await repository.waitForPreparation()
        #expect(vm.preparingProductID == nil)
        await vm.open(product("Havre"))
        #expect(repository.prepareCount == 1)
        try? await Task.sleep(for: .milliseconds(240))
        #expect(vm.preparingProductID == item.id)
        repository.prepareRequest?.resume()
        repository.prepareRequest = nil
        await opening.value
        #expect(vm.selectedProduct?.id == item.id)
        #expect(vm.preparingProductID == nil)
        #expect(!vm.isPreparing)
    }

    @Test func suspendedPreparationCannotOpenOrRestoreIndicator() async {
        let repository = SearchRepositoryStub()
        repository.delayPreparation = true
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        let opening = Task { await vm.open(product("Melk")) }
        await repository.waitForPreparation()
        vm.suspend()
        try? await Task.sleep(for: .milliseconds(240))
        repository.prepareRequest?.resume()
        repository.prepareRequest = nil
        await opening.value
        #expect(vm.selectedProduct == nil)
        #expect(vm.preparingProductID == nil)
        #expect(!vm.isPreparing)
    }

    @Test func savedSearchProductsRespectOwnerAndReadDoesNotCreateSyncEvents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("search.sqlite"))
        let owner = UUID(), other = UUID()
        let own = product("Min mat"), foreign = product("Privat mat"), shared = product("Felles melk")
        try store.saveProduct(own, ownerUserId: owner)
        try store.saveProduct(foreign, ownerUserId: other)
        try store.cacheCatalogProduct(shared)
        let count = store.pendingSyncCount()
        #expect(Set(try store.getSearchableProducts(ownerUserId: owner).map(\.id)) == [own.id, shared.id])
        #expect(try store.getSearchableProducts(ownerUserId: nil).map(\.id) == [shared.id])
        #expect(store.pendingSyncCount() == count)
    }

    @Test func repositoryCombinesBundledCatalogAndOwnerProductsAndPreparesWithoutSync() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("repository.sqlite"))
        let database = DatabaseService(store: store)
        let owner = UUID()
        let own = product("Min havre")
        try store.saveProduct(own, ownerUserId: owner)
        try store.toggleFavorite(userId: owner, productId: own.id)
        let repository = DefaultFoodSearchRepository(products: database, catalog: MatvaretabellenService(), remote: SearchNameServiceStub(), recentFoods: database)
        let library = try await repository.loadLibrary(owner: owner)
        #expect(library.products.count > 2_000)
        #expect(library.products.contains { $0.id == own.id })
        #expect(library.favorites.map(\.id) == [own.id])
        let raw = try #require(library.suggestions.first)
        #expect(raw.nutritionSource == .matvaretabellen)
        #expect(raw.amountUnit == .grams)
        let count = store.pendingSyncCount()
        try await repository.prepare(raw, owner: owner)
        #expect(store.getProduct(raw.id)?.id == raw.id)
        #expect(store.pendingSyncCount() == count)
        let manual = product("Manuell testvare")
        try await repository.saveManual(manual, owner: owner)
        #expect(store.pendingSyncCount() == count + 1)
        #expect(try store.getSearchableProducts(ownerUserId: owner).contains { $0.id == manual.id })
        #expect(try !store.getSearchableProducts(ownerUserId: UUID()).contains { $0.id == manual.id })
    }

    private func product(_ name: String, brand: String? = nil) -> Product {
        Product(name: name, brand: brand, caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(predicate())
    }
}

@MainActor
private final class SearchRepositoryStub: FoodSearchRepository {
    var library = FoodSearchLibrary(products: [], recent: [], favorites: [], suggestions: [])
    var scopes: [FoodSearchScope] = []
    var requests: [CheckedContinuation<[Product], Error>] = []
    var delayedOwner: UUID?
    var libraryRequest: CheckedContinuation<FoodSearchLibrary, Error>?
    var prepareFails = false
    var delayPreparation = false
    var prepareCount = 0
    var prepareRequest: CheckedContinuation<Void, Never>?

    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary { library }
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        if let delayedOwner, delayedOwner == owner {
            return try await withCheckedThrowingContinuation { libraryRequest = $0 }
        }
        return library
    }
    func searchRemote(query: String, owner: UUID?, scope: FoodSearchScope) async throws -> [Product] {
        scopes.append(scope)
        return try await withCheckedThrowingContinuation { requests.append($0) }
    }
    func saveManual(_ product: Product, owner: UUID) async throws {}
    func prepare(_ product: Product, owner: UUID) async throws {
        prepareCount += 1
        if delayPreparation { await withCheckedContinuation { prepareRequest = $0 } }
        if prepareFails { throw URLError(.cannotWriteToFile) }
    }
    func waitForPreparation() async {
        for _ in 0..<1_000 {
            if prepareRequest != nil { return }
            await Task.yield()
        }
        #expect(prepareRequest != nil)
    }

    func waitForRequests(_ count: Int) async {
        for _ in 0..<1_000 {
            if requests.count >= count { return }
            await Task.yield()
        }
        #expect(requests.count >= count)
    }
}

private struct SearchNameServiceStub: ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope) async throws -> [Product] { [] }
}
