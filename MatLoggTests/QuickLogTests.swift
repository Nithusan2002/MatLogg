import Foundation
import Testing
@testable import MatLogg

@MainActor
struct QuickLogTests {
    @Test func repeatChoicesOnlyContainLoggedFoods() async {
        let repository = QuickLibraryStub()
        let recent = product("Nylig vare"), favorite = product("Ulogget favoritt"), owner = UUID()
        let log = FoodLog(userId: owner, productId: recent.id, mealType: "frokost", amountG: 150,
                          loggedDate: Date(), calories: 150, proteinG: 3, carbsG: 15, fatG: 6)
        repository.library = FoodSearchLibrary(products: [], recent: [recent], favorites: [recent, favorite],
                                               suggestions: [], recentFoods: [RecentFood(product: recent, log: log)])
        let model = QuickLogViewModel(repository: repository)
        await model.load(userId: owner)
        #expect(model.recentFoods.map(\.id) == [recent.id])
        model.reset()
        #expect(model.recentFoods.isEmpty && model.products.isEmpty)
    }

    @Test func homeQuickChoicesKeepFavoritesWithoutAddingRepeatChoices() async {
        let repository = QuickLibraryStub()
        let favorite = product("Favoritt")
        let recent = product("Nylig logget")
        repository.library = FoodSearchLibrary(products: [], recent: [favorite, recent], favorites: [favorite], suggestions: [])
        let model = QuickLogViewModel(repository: repository)
        await model.load(userId: UUID())
        #expect(model.recentFoods.isEmpty)
        #expect(model.products.map(\.id) == [favorite.id, recent.id])
        #expect(repository.fullLibraryCalls == 0)
        #expect(model.errorMessage == nil)
    }

    @Test func localReadFailureCanBeRetried() async {
        let repository = QuickLibraryStub()
        repository.shouldFail = true
        let model = QuickLogViewModel(repository: repository)
        await model.load(userId: UUID())
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)
        repository.shouldFail = false
        await model.load(userId: UUID())
        #expect(model.errorMessage == nil)
        #expect(model.recentFoods.isEmpty)
    }

    @Test func resetDiscardsAnInFlightProfileRead() async {
        let repository = QuickLibraryStub()
        repository.suspend = true
        repository.library = FoodSearchLibrary(products: [], recent: [product("Forrige profil")], favorites: [], suggestions: [])
        let model = QuickLogViewModel(repository: repository)
        let read = Task { await model.load(userId: UUID()) }
        while repository.pending == nil { await Task.yield() }
        model.reset()
        repository.resume()
        await read.value
        #expect(model.recentFoods.isEmpty && model.products.isEmpty)
        #expect(!model.isLoading)
    }

    @Test func manualSaveUsesLocalRepositoryAndWaitsForFormDismissal() async throws {
        let repository = QuickLibraryStub()
        let model = QuickLogViewModel(repository: repository)
        let owner = UUID()
        await model.load(userId: owner)
        let manual = product("Egen matvare")
        try await model.saveManual(manual)
        model.manualProductSaved(manual)
        #expect(repository.savedOwner == owner)
        #expect(repository.savedProduct?.id == manual.id)
        #expect(repository.fullLibraryCalls == 0)
        #expect(model.selectedManualProduct == nil)
        model.finishManualCreation()
        #expect(model.selectedManualProduct?.id == manual.id)
    }

    @Test func profileResetDiscardsPendingManualSelection() async {
        let model = QuickLogViewModel(repository: QuickLibraryStub())
        await model.load(userId: UUID())
        model.manualProductSaved(product("Forrige profil"))
        model.reset()
        model.finishManualCreation()
        #expect(model.selectedManualProduct == nil)
    }

    private func product(_ name: String) -> Product {
        Product(id: UUID(), name: name, source: "user", caloriesPer100g: 100,
                proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4,
                nutritionSource: .user, imageSource: .none)
    }
}

@MainActor
private final class QuickLibraryStub: FoodSearchRepository {
    var library = FoodSearchLibrary(products: [], recent: [], favorites: [], suggestions: [])
    var shouldFail = false
    var suspend = false
    var pending: CheckedContinuation<Void, Never>?
    var fullLibraryCalls = 0
    var savedOwner: UUID?
    var savedProduct: Product?

    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        if suspend { await withCheckedContinuation { pending = $0 } }
        if shouldFail { throw URLError(.cannotOpenFile) }
        return library
    }
    func resume() { pending?.resume(); pending = nil }
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        fullLibraryCalls += 1
        return library
    }
    func searchRemote(query: String, owner: UUID?) async throws -> [Product] { [] }
    func saveManual(_ product: Product, owner: UUID) async throws {
        savedOwner = owner
        savedProduct = product
    }
    func prepare(_ product: Product, owner: UUID) async throws {}
}
