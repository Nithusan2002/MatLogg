import Foundation

protocol WaterRepository {
    func getWaterGlasses(userId: UUID) async throws -> [WaterGlass]
    func saveWaterGlass(_ glass: WaterGlass) async throws
    func deleteWaterGlass(_ id: UUID, userId: UUID) async throws
}
