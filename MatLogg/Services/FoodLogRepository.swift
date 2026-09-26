import Foundation

protocol FoodLogRepository {
    func saveLogs(_ logs: [FoodLog]) async throws
    func deleteLogs(_ ids: [UUID]) async throws
    func saveLog(_ log: FoodLog) async throws
    func deleteLog(_ id: UUID) async throws
    func getAllLogs(userId: UUID) async -> [FoodLog]
    func getSummary(userId: UUID, date: Date) async -> DailySummary
    func getTodaysSummary(userId: UUID) async -> DailySummary
    func getProduct(_ id: UUID) -> Product?
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product]
}

extension FoodLogRepository {
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            getProduct(id).map { (id, $0) }
        })
    }
}

extension DatabaseService: FoodLogRepository {}
