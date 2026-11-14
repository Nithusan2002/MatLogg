import Foundation

protocol SavedMealRepository {
    func saveSavedMeal(_ meal: SavedMeal) async throws
    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws
    func getSavedMeals(userId: UUID) async -> [SavedMeal]
    func loadSavedMeals(userId: UUID) async throws -> [SavedMeal]
}

extension SavedMealRepository {
    func loadSavedMeals(userId: UUID) async throws -> [SavedMeal] { await getSavedMeals(userId: userId) }
}

extension DatabaseService: SavedMealRepository {}
