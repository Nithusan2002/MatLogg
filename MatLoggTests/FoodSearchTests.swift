import Foundation
import Testing
@testable import MatLogg

@MainActor
struct FoodSearchTests {
    // Fixed relevance benchmark against the bundled public catalog; no live provider or user data.
    @Test(arguments: [
        ("melk", "Melk, uspesifisert"),
        ("lettmelk", "Lettmelk, uspesifisert"),
        ("havregryn", "Havregryn"),
        ("banan", "Banan, rå"),
        ("egg", "Egg, kokt"),
        ("ris", "Ris, basmati, kokt"),
        ("potet", "Potet, bakt"),
        ("laks", "Laks, oppdrett, rå"),
        ("yoghurt naturell", "Yoghurt, naturell"),
        ("smør", "Smør"),
        ("brokkoli", "Brokkoli, norsk, rå"),
        ("kylling filet", "Kylling, filet, uten skinn, rå"),
        ("kokt ris", "Ris, basmati, kokt"),
        ("rå laks", "Laks, oppdrett, rå"),
        ("lettmelk tine", "Lettmelk, 1,0 % fett, Tine"),
        ("havre", "Havre- og bokhvetegrøt, glutenfri"),
        ("brød grovt", "Brød, grovt (50-75 %), kjøpt"),
        ("eple", "Eple, uspesifisert, rå"),
        ("pasta kokt", "Pasta, naturell, kokt"),
        ("yoghurt vanilje", "Yoghurt, vanilje")
    ])
    func catalogBenchmarkFindsRelevantFoodInFirstFive(query: String, expected: String) async throws {
        let catalog = try await MatvaretabellenService().fetchCommonFoods().map(FoodSearchCatalog.product)
        let results = try await FoodSearchIndex().results(library: catalog, remote: [], query: query)
        #expect(results.prefix(5).contains { $0.name == expected }, "\(query): \(results.prefix(5).map(\.name))")
    }

    @Test func wholeWordsOutrankCompoundAndIngredientMatches() async throws {
        let milk = product("Skummet melk")
        let compound = product("Melkesjokolade")
        let ingredient = product("Bolle med melk")
        let results = try await FoodSearchIndex().results(library: [compound, ingredient, milk], remote: [], query: "melk")
        #expect(results.first?.id == milk.id)
        #expect(Set(results.map(\.id)) == Set([milk.id, compound.id, ingredient.id]))
    }

    @Test func weakHistoryDoesNotHideExactUnloggedMatch() async throws {
        let exact = product("Melk")
        let old = product("Melkesjokolade")
        let sections = try await FoodSearchIndex().sections(library: [old, exact], remote: [], query: "melk",
            loggedProductTimes: [old.id: Date()])
        #expect(sections.all.first?.id == exact.id)
        #expect(sections.history.isEmpty)
        #expect(sections.other.contains { $0.id == old.id })
    }

    @Test func preferencesBreakTextualTiesWithoutPromotingWeakerMatches() async throws {
        let first = product("Yoghurt naturell", brand: "A")
        let favorite = product("Yoghurt naturell", brand: "B")
        let recent = product("Yoghurt naturell", brand: "C")
        let weaker = product("Yoghurtis naturell")
        let index = FoodSearchIndex()
        let result = try await index.results(library: [first, favorite, recent, weaker], remote: [], query: "yoghurt",
            favoriteIDs: [favorite.id, weaker.id], loggedProductTimes: [recent.id: Date(), weaker.id: Date()])
        #expect(result.map(\.id) == [favorite.id, recent.id, first.id, weaker.id])
        let repeated = try await index.results(library: [weaker, recent, favorite, first], remote: [], query: "yoghurt",
            favoriteIDs: [favorite.id, weaker.id], loggedProductTimes: [recent.id: Date(), weaker.id: Date()])
        #expect(result.map(\.id) == repeated.map(\.id))
    }

    @Test func brandWordOrderAndPartialQueriesRemainSearchable() async throws {
        let milk = product("Lettmelk", brand: "Testmerke")
        let distraction = product("Lettmelkesjokolade", brand: "Testmerke")
        let index = FoodSearchIndex()
        for query in ["TESTMERKE lettmelk", "lettmelk testmerke", "lettm testm"] {
            let result = try await index.results(library: [distraction, milk], remote: [], query: query)
            #expect(result.first?.id == milk.id)
        }
        let result = try await index.results(library: [milk], remote: [product("Irrelevant")], query: "lettmelk")
        #expect(result.map(\.id) == [milk.id])
        #expect(FoodSearchMatcher.sorted([distraction, milk], query: "lettmelk").first?.id == milk.id)
    }

    @Test func viewModelUsesFavoritesAndClearsPreferenceOnOwnerSwitch() async {
        let repository = SearchRepositoryStub()
        let a = product("Yoghurt", brand: "A")
        let b = product("Yoghurt", brand: "B")
        repository.library = FoodSearchLibrary(products: [a, b], recent: [], favorites: [b], suggestions: [])
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("yoghurt")
        await waitUntil { vm.results.first?.id == b.id }
        repository.library = FoodSearchLibrary(products: [a, b], recent: [], favorites: [], suggestions: [])
        await vm.load(owner: UUID())
        vm.setQuery("yoghurt")
        await waitUntil { vm.results.first?.id == a.id }
        #expect(vm.favorites.isEmpty)
    }

    @Test func singleBrandQueryKeepsNamedFoodAheadOfOtherBrandProducts() async throws {
        let cheese = product("Jarlsberg Original", brand: "Tine")
        let pizza = product("Hjertepizza", brand: "Grandiosa, Jarlsberg")
        let original = product("Grandiosa Original", brand: "Orkla")
        let pepperoni = product("Grandiosa Pepperoni", brand: "Grandiosa")
        let other = product("4x ost", brand: "Grandiosa")
        let index = FoodSearchIndex()
        let cheeses = try await index.results(library: [], remote: [pizza, cheese], query: "jarlsberg")
        #expect(cheeses.first?.id == cheese.id)
        let pizzas = try await index.results(library: [], remote: [other, pepperoni, original], query: "grandiosa")
        #expect(pizzas.first?.id == original.id)
    }

    @Test func separateBrandMetadataDoesNotPromoteExtraFlavorVariants() async throws {
        let plain = product("Proteinyoghurt Vanilje", brand: "Skyr")
        let mango = product("Skyr Mango & Vanilje", brand: "Q-Meieriene")
        let milk = product("Havredrik barista edition", brand: "Oatly")
        let vanilla = product("Vanilla Barista", brand: "Oatly")
        let index = FoodSearchIndex()
        let skyr = try await index.results(library: [mango, plain], remote: [], query: "skyr vanilje")
        #expect(skyr.first?.id == plain.id)
        let barista = try await index.results(library: [], remote: [vanilla, milk], query: "oatly barista")
        #expect(barista.first?.id == milk.id)
        #expect(Set(skyr.map(\.id)) == [plain.id, mango.id])
        #expect(Set(barista.map(\.id)) == [milk.id, vanilla.id])
    }

    @Test func unavailableProviderExplainsRetryAndKeepsLocalMatches() async {
        let repository = SearchRepositoryStub()
        let milk = product("Melk")
        repository.library = FoodSearchLibrary(products: [milk], recent: [], favorites: [], suggestions: [])
        let vm = FoodSearchViewModel(repository: repository)
        await vm.load(owner: UUID())
        vm.setQuery("melk")
        vm.search()
        await repository.waitForRequests(1)
        repository.requests[0].resume(throwing: APIService.APIError.serverError(503))
        await waitUntil { vm.phase == .offline }
        #expect(vm.results.map(\.id) == [milk.id])
        #expect(vm.query == "melk")
        #expect(vm.searchError?.contains("midlertidig utilgjengelig") == true)
        #expect(vm.canSearchGlobally)
    }

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
        let count = try store.pendingSyncCount()
        #expect(try Set(store.getSearchableProducts(ownerUserId: owner).map(\.id)) == [own.id, shared.id])
        #expect(try store.getSearchableProducts(ownerUserId: nil).map(\.id) == [shared.id])
        #expect(try store.pendingSyncCount() == count)
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
        let count = try store.pendingSyncCount()
        try await repository.prepare(raw, owner: owner)
        #expect(try store.getProduct(raw.id)?.id == raw.id)
        #expect(try store.pendingSyncCount() == count)
        let manual = product("Manuell testvare")
        try await repository.saveManual(manual, owner: owner)
        #expect(try store.pendingSyncCount() == count + 1)
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
