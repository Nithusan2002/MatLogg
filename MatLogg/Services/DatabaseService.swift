import Foundation

class DatabaseService: WaterRepository {
    static let shared = DatabaseService()
    private let store: LocalStore?
    let startupError: Error?

    convenience init() {
        self.init(storeResult: LocalStore.sharedResult)
    }

    init(storeResult: Result<LocalStore, Error>) {
        switch storeResult {
        case .success(let store):
            self.store = store
            startupError = nil
        case .failure(let error):
            store = nil
            startupError = error
        }
    }

    init(store: LocalStore) {
        self.store = store
        startupError = nil
    }

    var isAvailable: Bool { store != nil }

    func getWaterGlasses(userId: UUID) async throws -> [WaterGlass] {
        try requireStore().getWaterGlasses(userId: userId)
    }

    func saveWaterGlass(_ glass: WaterGlass) async throws {
        try requireStore().saveWaterGlass(glass)
    }

    func deleteWaterGlass(_ id: UUID, userId: UUID) async throws {
        try requireStore().deleteWaterGlass(id, userId: userId)
    }

    private func requireStore() throws -> LocalStore {
        guard let store else {
            throw DatabaseServiceError.unavailable
        }
        return store
    }
    
    func saveGoal(_ goal: Goal) async throws {
        try requireStore().saveGoal(goal)
    }
    
    func getLatestGoal(userId: UUID, completion: @escaping (Goal?) -> Void) {
        completion(store?.getLatestGoal(userId: userId))
    }

    func latestGoal(userId: UUID) async -> Goal? {
        store?.getLatestGoal(userId: userId)
    }
    
    func saveLogs(_ logs: [FoodLog]) async throws {
        try requireStore().saveLogs(logs)
    }

    func deleteLogs(_ ids: [UUID]) async throws {
        try requireStore().deleteLogs(ids)
    }

    func saveLog(_ log: FoodLog) async throws {
        try requireStore().saveLog(log)
    }
    
    func deleteLog(_ id: UUID) async throws {
        try requireStore().deleteLog(id)
    }

    func getAllLogs(userId: UUID) async -> [FoodLog] {
        store?.getAllLogs(userId: userId) ?? []
    }
    
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        store?.getSummary(userId: userId, date: date) ?? DailySummary(
            date: date,
            totalCalories: 0,
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0,
            logs: []
        )
    }
    
    func getTodaysSummary(userId: UUID) async -> DailySummary {
        await getSummary(userId: userId, date: Date())
    }

    func saveSavedMeal(_ meal: SavedMeal) async throws {
        try requireStore().saveSavedMeal(meal)
    }

    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws {
        try requireStore().deleteSavedMeal(id, userId: userId)
    }

    func getSavedMeals(userId: UUID) async -> [SavedMeal] {
        store?.getSavedMeals(userId: userId) ?? []
    }
    
    func saveProduct(_ product: Product, ownerUserId: UUID) async throws {
        try requireStore().saveProduct(product, ownerUserId: ownerUserId)
    }

    func cacheCatalogProduct(_ product: Product) async throws {
        try requireStore().cacheCatalogProduct(product)
    }
    
    func getProduct(_ id: UUID) -> Product? {
        store?.getProduct(id)
    }

    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        store?.getProducts(ids) ?? [:]
    }
    
    func getProductByBarcode(_ barcode: String, ownerUserId: UUID?) -> Product? {
        store?.getProductByBarcode(barcode, ownerUserId: ownerUserId)
    }
    
    func saveMatchMapping(_ mapping: ProductMatchMapping) {
        store?.saveMatchMapping(mapping)
    }
    
    func getMatchMapping(for barcode: String) -> ProductMatchMapping? {
        store?.getMatchMapping(for: barcode)
    }
    
    func toggleFavorite(userId: UUID, productId: UUID) async throws {
        try requireStore().toggleFavorite(userId: userId, productId: productId)
    }
    
    func isFavorite(userId: UUID, productId: UUID) -> Bool {
        store?.isFavorite(userId: userId, productId: productId) ?? false
    }
    
    func saveScanHistory(userId: UUID, productId: UUID) async throws {
        try requireStore().saveScanHistory(userId: userId, productId: productId)
    }
    
    func getRecentScans(userId: UUID, limit: Int = 15) async -> [ScanHistory] {
        store?.getRecentScans(userId: userId, limit: limit) ?? []
    }
    
    func saveWeightEntry(_ entry: WeightEntry) async throws {
        try requireStore().saveWeightEntry(entry)
    }
    
    func deleteWeightEntry(_ id: UUID) async throws {
        try requireStore().deleteWeightEntry(id)
    }
    
    func getWeightEntries(userId: UUID) async -> [WeightEntry] {
        store?.getWeightEntries(userId: userId) ?? []
    }
    
    func getFavorites(userId: UUID, kind: ProductKind? = nil) async -> [Product] {
        store?.getFavorites(userId: userId, kind: kind) ?? []
    }
    
    func getRecentProducts(userId: UUID, kind: ProductKind? = nil, limit: Int = 10) async -> [Product] {
        store?.getRecentProducts(userId: userId, kind: kind, limit: limit) ?? []
    }
    
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) {
        store?.saveMatvaretabellenCache(items)
    }
    
    func getMatvaretabellenCache(maxAgeDays: Int) -> [MatvaretabellenProduct]? {
        store?.getMatvaretabellenCache(maxAgeDays: maxAgeDays)
    }
    
    func pendingSyncCount() async -> Int {
        store?.pendingSyncCount() ?? 0
    }

    func failedSyncCount() async -> Int {
        store?.failedSyncCount() ?? 0
    }

    func syncQueueStatus() async -> SyncQueueStatus {
        store?.syncQueueStatus() ?? .empty
    }

    func syncQueueStatus(ownerUserId: UUID) async -> SyncQueueStatus {
        store?.syncQueueStatus(ownerUserId: ownerUserId) ?? .empty
    }

    func failedSyncEvents(limit: Int = 5) async -> [SyncFailureSummary] {
        store?.failedSyncEvents(limit: limit) ?? []
    }

    func failedSyncEvents(ownerUserId: UUID, limit: Int = 5) async -> [SyncFailureSummary] {
        store?.failedSyncEvents(ownerUserId: ownerUserId, limit: limit) ?? []
    }

    func nextPendingRetryDate() async -> Date? {
        store?.nextPendingRetryDate()
    }

    func nextPendingRetryDate(ownerUserId: UUID) async -> Date? {
        store?.nextPendingRetryDate(ownerUserId: ownerUserId)
    }

    func quarantinedSyncCount() async -> Int {
        store?.quarantinedSyncCount() ?? 0
    }

    func localSchemaVersion() async -> Int {
        store?.schemaVersion() ?? 0
    }

    func resetAllLocalData() async throws {
        try requireStore().resetAllData()
        UserDefaults.standard.removeObject(forKey: "personalDetails")
    }

    func localDataSummary(ownerId: UUID) async -> LocalDataSummary {
        store?.localDataSummary(ownerId: ownerId) ?? .empty
    }

    func claimLocalData(from localOwnerId: UUID, to accountOwnerId: UUID) async throws {
        try requireStore().claimLocalData(from: localOwnerId, to: accountOwnerId)
        let defaults = UserDefaults.standard
        let oldKey = "personalDetails.\(localOwnerId.uuidString)"
        let newKey = "personalDetails.\(accountOwnerId.uuidString)"
        if defaults.object(forKey: newKey) == nil, let details = defaults.data(forKey: oldKey) {
            defaults.set(details, forKey: newKey)
        }
        defaults.removeObject(forKey: oldKey)
    }

    func deleteLocalData(ownerId: UUID) async throws {
        try requireStore().deleteLocalData(ownerId: ownerId)
        UserDefaults.standard.removeObject(forKey: "personalDetails.\(ownerId.uuidString)")
    }
    
    func fetchPendingEvents(limit: Int) async -> [SyncEvent] {
        store?.fetchPendingEvents(limit: limit) ?? []
    }

    func fetchPendingEvents(ownerUserId: UUID, limit: Int) async -> [SyncEvent] {
        store?.fetchPendingEvents(ownerUserId: ownerUserId, limit: limit) ?? []
    }
    
    func markEventsInFlight(_ eventIds: [UUID]) async {
        store?.markEventsInFlight(eventIds)
    }
    
    func markEventsAcked(_ eventIds: [UUID]) async {
        store?.markEventsAcked(eventIds)
    }
    
    func markEventForRetry(_ eventId: UUID, error: String?, backoffSeconds: TimeInterval) async {
        store?.markEventForRetry(eventId, error: error, backoffSeconds: backoffSeconds)
    }

    func markEventDeadLetter(_ eventId: UUID, error: String) async {
        store?.markEventDeadLetter(eventId, error: error)
    }

    func retryFailedEvents(ownerUserId: UUID) async {
        store?.retryDeadLetterEvents(ownerUserId: ownerUserId)
    }

    func retryFailedEvent(_ eventId: UUID, ownerUserId: UUID) async {
        store?.retryDeadLetterEvent(eventId, ownerUserId: ownerUserId)
    }
    
    func resetInFlightEvents() async {
        store?.resetInFlightToPending()
    }
    
    func cleanupAckedEvents(olderThanDays: Int) async {
        store?.cleanupAckedEvents(olderThanDays: olderThanDays)
    }
}

enum DatabaseServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Den lokale databasen er ikke tilgjengelig. Dataene er ikke slettet."
        }
    }
}
