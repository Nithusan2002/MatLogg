import Foundation

class DatabaseService {
    static let shared = DatabaseService()
    
    // In-memory storage for MVP (will be replaced with SQLite later)
    private var users: [UUID: User] = [:]
    private var goals: [UUID: Goal] = [:]
    private var products: [UUID: Product] = [:]
    private var logs: [UUID: FoodLog] = [:]
    private var favorites: [UUID: Favorite] = [:]
    private var scanHistory: [UUID: ScanHistory] = [:]
    
    func saveGoal(_ goal: Goal) async throws {
        goals[goal.id] = goal
    }
    
    func getLatestGoal(userId: UUID, completion: @escaping (Goal?) -> Void) {
        let userGoals = goals.values.filter { $0.userId == userId }
        let latest = userGoals.max { $0.createdDate < $1.createdDate }
        completion(latest)
    }
    
    func saveLog(_ log: FoodLog) async throws {
        logs[log.id] = log
    }
    
    func deleteLog(_ id: UUID) async throws {
        logs.removeValue(forKey: id)
    }
    
    func getTodaysSummary(userId: UUID) async -> DailySummary {
        let today = Calendar.current.startOfDay(for: Date())
        let todaysLogs = logs.values.filter { 
            $0.userId == userId && 
            Calendar.current.isDate($0.loggedDate, inSameDayAs: today)
        }
        
        let totalCalories = todaysLogs.reduce(0) { $0 + $1.calories }
        let totalProtein = todaysLogs.reduce(0) { $0 + $1.proteinG }
        let totalCarbs = todaysLogs.reduce(0) { $0 + $1.carbsG }
        let totalFat = todaysLogs.reduce(0) { $0 + $1.fatG }
        
        return DailySummary(
            date: today,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            logs: Array(todaysLogs).sorted { $0.loggedTime < $1.loggedTime }
        )
    }
    
    func saveProduct(_ product: Product) async throws {
        products[product.id] = product
    }
    
    func getProduct(_ id: UUID) -> Product? {
        return products[id]
    }
    
    func toggleFavorite(userId: UUID, productId: UUID) async throws {
        if let existing = favorites.values.first(where: { $0.userId == userId && $0.productId == productId }) {
            favorites.removeValue(forKey: existing.id)
        } else {
            let favorite = Favorite(userId: userId, productId: productId)
            favorites[favorite.id] = favorite
        }
    }
    
    func isFavorite(userId: UUID, productId: UUID) -> Bool {
        return favorites.values.contains { $0.userId == userId && $0.productId == productId }
    }
    
    func saveScanHistory(userId: UUID, productId: UUID) async throws {
        let scanHistory = ScanHistory(userId: userId, productId: productId)
        self.scanHistory[scanHistory.id] = scanHistory
    }
    
    func getRecentScans(userId: UUID, limit: Int = 15) async -> [ScanHistory] {
        let userScans = scanHistory.values.filter { $0.userId == userId }
        return Array(userScans.sorted { $0.scannedAt > $1.scannedAt }.prefix(limit))
    }
}
