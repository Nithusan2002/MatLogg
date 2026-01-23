import Foundation

class DatabaseService {
    static let shared = DatabaseService()
    private let store = LocalStore.shared
    
    func saveGoal(_ goal: Goal) async throws {
        try store.saveGoal(goal)
    }
    
    func getLatestGoal(userId: UUID, completion: @escaping (Goal?) -> Void) {
        completion(store.getLatestGoal(userId: userId))
    }
    
    func saveLog(_ log: FoodLog) async throws {
        try store.saveLog(log)
    }
    
    func deleteLog(_ id: UUID) async throws {
        try store.deleteLog(id)
    }

    func getAllLogs(userId: UUID) async -> [FoodLog] {
        store.getAllLogs(userId: userId)
    }
    
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        store.getSummary(userId: userId, date: date)
    }
    
    func getTodaysSummary(userId: UUID) async -> DailySummary {
        await getSummary(userId: userId, date: Date())
    }
    
    func saveProduct(_ product: Product) async throws {
        try store.saveProduct(product)
    }
    
    func getProduct(_ id: UUID) -> Product? {
        store.getProduct(id)
    }
    
    func getProductByBarcode(_ barcode: String) -> Product? {
        store.getProductByBarcode(barcode)
    }
    
    func saveMatchMapping(_ mapping: ProductMatchMapping) {
        store.saveMatchMapping(mapping)
    }
    
    func getMatchMapping(for barcode: String) -> ProductMatchMapping? {
        store.getMatchMapping(for: barcode)
    }
    
    func toggleFavorite(userId: UUID, productId: UUID) async throws {
        try store.toggleFavorite(userId: userId, productId: productId)
    }
    
    func isFavorite(userId: UUID, productId: UUID) -> Bool {
        store.isFavorite(userId: userId, productId: productId)
    }
    
    func saveScanHistory(userId: UUID, productId: UUID) async throws {
        try store.saveScanHistory(userId: userId, productId: productId)
    }
    
    func getRecentScans(userId: UUID, limit: Int = 15) async -> [ScanHistory] {
        store.getRecentScans(userId: userId, limit: limit)
    }
    
    func saveWeightEntry(_ entry: WeightEntry) async throws {
        try store.saveWeightEntry(entry)
    }
    
    func deleteWeightEntry(_ id: UUID) async throws {
        try store.deleteWeightEntry(id)
    }
    
    func getWeightEntries(userId: UUID) async -> [WeightEntry] {
        store.getWeightEntries(userId: userId)
    }
    
    func getFavorites(userId: UUID, kind: ProductKind? = nil) async -> [Product] {
        store.getFavorites(userId: userId, kind: kind)
    }
    
    func getRecentProducts(userId: UUID, kind: ProductKind? = nil, limit: Int = 10) async -> [Product] {
        store.getRecentProducts(userId: userId, kind: kind, limit: limit)
    }
    
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) {
        store.saveMatvaretabellenCache(items)
    }
    
    func getMatvaretabellenCache(maxAgeDays: Int) -> [MatvaretabellenProduct]? {
        store.getMatvaretabellenCache(maxAgeDays: maxAgeDays)
    }
    
    func pendingSyncCount() async -> Int {
        store.pendingSyncCount()
    }
    
    func fetchPendingEvents(limit: Int) async -> [SyncEvent] {
        store.fetchPendingEvents(limit: limit)
    }
    
    func markEventsInFlight(_ eventIds: [UUID]) async {
        store.markEventsInFlight(eventIds)
    }
    
    func markEventsAcked(_ eventIds: [UUID]) async {
        store.markEventsAcked(eventIds)
    }
    
    func markEventForRetry(_ eventId: UUID, error: String?, backoffSeconds: TimeInterval) async {
        store.markEventForRetry(eventId, error: error, backoffSeconds: backoffSeconds)
    }
    
    func resetInFlightEvents() async {
        store.resetInFlightToPending()
    }
    
    func cleanupAckedEvents(olderThanDays: Int) async {
        store.cleanupAckedEvents(olderThanDays: olderThanDays)
    }
}
