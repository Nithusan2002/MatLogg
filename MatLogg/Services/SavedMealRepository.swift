import Foundation

protocol SavedMealRepository {
    func saveSavedMeal(_ meal: SavedMeal) async throws
    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws
    func loadSavedMeals(userId: UUID) async throws -> [SavedMeal]
}

extension DatabaseService: SavedMealRepository {}
