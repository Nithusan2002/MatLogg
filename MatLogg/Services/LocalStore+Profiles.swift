import Foundation

// Read-only domain operations; connection, queue and transactions remain owned by LocalStore.
extension LocalStore {
    func getLatestGoal(userId: UUID) throws -> Goal? {
        try readRows(sql: "SELECT json FROM goals WHERE userId = ? ORDER BY createdDate DESC LIMIT 1;", values: [.text(userId.uuidString)]) { try $0.decode(Goal.self) }.first
    }

    func getWeightEntries(userId: UUID) throws -> [WeightEntry] {
        try readRows(sql: "SELECT json FROM weights WHERE userId = ? ORDER BY date ASC;", values: [.text(userId.uuidString)]) { try $0.decode(WeightEntry.self) }
    }

    func loadSavedMeals(userId: UUID) throws -> [SavedMeal] {
        try readRows(sql: "SELECT json FROM saved_meals WHERE userId = ? ORDER BY updatedAt DESC;", values: [.text(userId.uuidString)]) { try $0.decode(SavedMeal.self) }
    }
}
