import Foundation

protocol SavedMealRepository {
    func saveSavedMeal(_ meal: SavedMeal) async throws
    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws
    func getSavedMeals(userId: UUID) async -> [SavedMeal]
}

extension DatabaseService: SavedMealRepository {}
