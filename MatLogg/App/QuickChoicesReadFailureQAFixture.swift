#if DEBUG
import Foundation

/// Fails only the first quick-choice read; all persistence remains in the real QA store.
@MainActor
final class QuickChoicesReadFailureQAFixture: FoodSearchRepository {
    private let base: any FoodSearchRepository
    private var shouldFail = true

    init(base: any FoodSearchRepository) { self.base = base }

    func loadQuickChoices(owner: UUID?) async throws -> FoodSearchLibrary {
        if shouldFail {
            shouldFail = false
            throw DatabaseServiceError.unavailable
        }
        return try await base.loadQuickChoices(owner: owner)
    }

    func loadLocalLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        try await base.loadLocalLibrary(owner: owner)
    }

    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        try await base.loadLibrary(owner: owner)
    }

    func loadLibrary(owner: UUID?, onLocalLoaded: (FoodSearchLibrary) -> Void) async throws -> FoodSearchLibrary {
        try await base.loadLibrary(owner: owner, onLocalLoaded: onLocalLoaded)
    }

    func searchRemote(query: String, owner: UUID?, scope: FoodSearchScope) async throws -> [Product] {
        try await base.searchRemote(query: query, owner: owner, scope: scope)
    }

    func saveManual(_ product: Product, owner: UUID) async throws {
        try await base.saveManual(product, owner: owner)
    }

    func prepare(_ product: Product, owner: UUID) async throws {
        try await base.prepare(product, owner: owner)
    }

    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome {
        try await base.logAgain(food, owner: owner, mealType: mealType, date: date)
    }
}
#endif
