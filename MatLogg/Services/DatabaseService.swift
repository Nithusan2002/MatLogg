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
    private var matchMappings: [String: ProductMatchMapping] = [:]
    
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
    
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        let day = Calendar.current.startOfDay(for: date)
        let dayLogs = logs.values.filter {
            $0.userId == userId &&
            Calendar.current.isDate($0.loggedDate, inSameDayAs: day)
        }
        
        let totalCalories = dayLogs.reduce(0) { $0 + $1.calories }
        let totalProtein = dayLogs.reduce(0) { $0 + $1.proteinG }
        let totalCarbs = dayLogs.reduce(0) { $0 + $1.carbsG }
        let totalFat = dayLogs.reduce(0) { $0 + $1.fatG }
        
        return DailySummary(
            date: day,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            logs: Array(dayLogs).sorted { $0.loggedTime < $1.loggedTime }
        )
    }
    
    func getTodaysSummary(userId: UUID) async -> DailySummary {
        await getSummary(userId: userId, date: Date())
    }
    
    func saveProduct(_ product: Product) async throws {
        products[product.id] = product
    }
    
    func getProduct(_ id: UUID) -> Product? {
        return products[id]
    }
    
    func getProductByBarcode(_ barcode: String) -> Product? {
        products.values.first { $0.barcodeEan == barcode }
    }
    
    func saveMatchMapping(_ mapping: ProductMatchMapping) {
        matchMappings[mapping.barcode] = mapping
    }
    
    func getMatchMapping(for barcode: String) -> ProductMatchMapping? {
        matchMappings[barcode]
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
