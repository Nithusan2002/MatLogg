import Foundation

class DatabaseService: WaterRepository, ProfileDataExportRepository, RecentFoodRepository {
    static let shared = DatabaseService()
    private let store: LocalStore?
    private let ioQueue: DispatchQueue
    let startupError: Error?
    private var defaults: UserDefaults = .standard

    convenience init() {
        self.init(storeResult: LocalStore.sharedResult)
    }

    init(storeResult: Result<LocalStore, Error>) {
        ioQueue = DispatchQueue(label: "matlogg.database.io", qos: .userInitiated)
        switch storeResult {
        case .success(let store):
            self.store = store
            startupError = nil
        case .failure(let error):
            store = nil
            startupError = error
        }
    }

    init(store: LocalStore, defaults: UserDefaults = .standard, ioQueue: DispatchQueue = DispatchQueue(label: "matlogg.database.io", qos: .userInitiated)) {
        self.ioQueue = ioQueue
        self.defaults = defaults
        self.store = store
        startupError = nil
    }

    var isAvailable: Bool { store != nil }

    func exportProfileRecords(ownerId: UUID) async throws -> [String: [Data]] {
        var records = try await perform { try $0.exportProfileRecords(ownerId: ownerId) }
        let prefixes = ["lastAmount.\(ownerId.uuidString).", "useLastAmount.\(ownerId.uuidString)."]
        records["profile_preferences"] = try defaults.dictionaryRepresentation()
            .filter { entry in prefixes.contains { entry.key.hasPrefix($0) } }
            .sorted { $0.key < $1.key }
            .map { key, value in
                let data = value as? Data
                return try JSONSerialization.data(withJSONObject: [
                    "key": key,
                    "value": data?.base64EncodedString() ?? value,
                    "encoding": data == nil ? "json" : "base64"
                ])
            }
        return records
    }

    // The store serializes SQLite transactions internally. This outer queue keeps
    // synchronous store work off MainActor while preserving submission order.
    private func performIfAvailable<T: Sendable>(_ operation: @escaping @Sendable (LocalStore?) -> T) async -> T {
        let store = store
        return await withCheckedContinuation { continuation in
            ioQueue.async { continuation.resume(returning: operation(store)) }
        }
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable (LocalStore) throws -> T) async throws -> T {
        let store = try requireStore()
        return try await withCheckedThrowingContinuation { continuation in
            ioQueue.async {
                continuation.resume(with: Result { try operation(store) })
            }
        }
    }

    func getWaterGlasses(userId: UUID) async throws -> [WaterGlass] {
        try await perform { try $0.getWaterGlasses(userId: userId) }
    }

    func saveWaterGlass(_ glass: WaterGlass) async throws {
        try await perform { try $0.saveWaterGlass(glass) }
    }

    func deleteWaterGlass(_ id: UUID, userId: UUID) async throws {
        try await perform { try $0.deleteWaterGlass(id, userId: userId) }
    }

    private func requireStore() throws -> LocalStore {
        guard let store else {
            throw DatabaseServiceError.unavailable
        }
        return store
    }
    
    func saveGoal(_ goal: Goal) async throws {
        try await perform { try $0.saveGoal(goal) }
    }
    
    func getLatestGoal(userId: UUID, completion: @escaping (Goal?) -> Void) {
        completion(store?.getLatestGoal(userId: userId))
    }

    func latestGoal(userId: UUID) async -> Goal? {
        await performIfAvailable { $0?.getLatestGoal(userId: userId) }
    }
    
    func saveLogs(_ logs: [FoodLog]) async throws {
        try await perform { try $0.saveLogs(logs) }
    }

    func deleteLogs(_ ids: [UUID]) async throws {
        try await perform { try $0.deleteLogs(ids) }
    }

    func saveLog(_ log: FoodLog) async throws {
        try await perform { try $0.saveLog(log) }
    }
    
    func deleteLog(_ id: UUID) async throws {
        try await perform { try $0.deleteLog(id) }
    }

    func getAllLogs(userId: UUID) async -> [FoodLog] {
        await performIfAvailable { $0?.getAllLogs(userId: userId) ?? [] }
    }

    func getRecentFoods(owner: UUID, before: Date, limit: Int) async throws -> [RecentFood] {
        try await perform { try $0.getRecentFoods(owner: owner, before: before, limit: limit) }
    }
    
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        await performIfAvailable { $0?.getSummary(userId: userId, date: date) ?? DailySummary(
            date: date,
            totalCalories: 0,
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0,
            logs: []
        ) }
    }
    
    func getTodaysSummary(userId: UUID) async -> DailySummary {
        await getSummary(userId: userId, date: Date())
    }

    func saveSavedMeal(_ meal: SavedMeal) async throws {
        try await perform { try $0.saveSavedMeal(meal) }
    }

    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws {
        try await perform { try $0.deleteSavedMeal(id, userId: userId) }
    }

    func getSavedMeals(userId: UUID) async -> [SavedMeal] {
        await performIfAvailable { $0?.getSavedMeals(userId: userId) ?? [] }
    }
    
    func saveProduct(_ product: Product, ownerUserId: UUID) async throws {
        try await perform { try $0.saveProduct(product, ownerUserId: ownerUserId) }
    }

    func cacheCatalogProduct(_ product: Product) async throws {
        try await perform { try $0.cacheCatalogProduct(product) }
    }
    
    func getProduct(_ id: UUID) -> Product? {
        store?.getProduct(id)
    }

    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        await performIfAvailable { $0?.getProducts(ids) ?? [:] }
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
        try await perform { try $0.toggleFavorite(userId: userId, productId: productId) }
    }
    
    func isFavorite(userId: UUID, productId: UUID) -> Bool {
        store?.isFavorite(userId: userId, productId: productId) ?? false
    }
    
    func saveScanHistory(userId: UUID, productId: UUID) async throws {
        try await perform { try $0.saveScanHistory(userId: userId, productId: productId) }
    }
    
    func getRecentScans(userId: UUID, limit: Int = 15) async -> [ScanHistory] {
        await performIfAvailable { $0?.getRecentScans(userId: userId, limit: limit) ?? [] }
    }
    
    func saveWeightEntry(_ entry: WeightEntry) async throws {
        try await perform { try $0.saveWeightEntry(entry) }
    }
    
    func deleteWeightEntry(_ id: UUID) async throws {
        try await perform { try $0.deleteWeightEntry(id) }
    }
    
    func getWeightEntries(userId: UUID) async -> [WeightEntry] {
        await performIfAvailable { $0?.getWeightEntries(userId: userId) ?? [] }
    }
    
    func getSearchableProducts(ownerUserId: UUID?) async throws -> [Product] {
        try await perform { try $0.getSearchableProducts(ownerUserId: ownerUserId) }
    }

    func getFavorites(userId: UUID, kind: ProductKind? = nil) async -> [Product] {
        await performIfAvailable { $0?.getFavorites(userId: userId, kind: kind) ?? [] }
    }
    
    func getRecentProducts(userId: UUID, kind: ProductKind? = nil, limit: Int = 10) async -> [Product] {
        await performIfAvailable { $0?.getRecentProducts(userId: userId, kind: kind, limit: limit) ?? [] }
    }
    
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) {
        store?.saveMatvaretabellenCache(items)
    }
    
    func getMatvaretabellenCache(maxAgeDays: Int) -> [MatvaretabellenProduct]? {
        store?.getMatvaretabellenCache(maxAgeDays: maxAgeDays)
    }
    
    func pendingSyncCount() async -> Int {
        await performIfAvailable { $0?.pendingSyncCount() ?? 0 }
    }

    func failedSyncCount() async -> Int {
        await performIfAvailable { $0?.failedSyncCount() ?? 0 }
    }

    func syncQueueStatus() async -> SyncQueueStatus {
        await performIfAvailable { $0?.syncQueueStatus() ?? .empty }
    }

    func syncQueueStatus(ownerUserId: UUID) async -> SyncQueueStatus {
        await performIfAvailable { $0?.syncQueueStatus(ownerUserId: ownerUserId) ?? .empty }
    }

    func failedSyncEvents(limit: Int = 5) async -> [SyncFailureSummary] {
        await performIfAvailable { $0?.failedSyncEvents(limit: limit) ?? [] }
    }

    func failedSyncEvents(ownerUserId: UUID, limit: Int = 5) async -> [SyncFailureSummary] {
        await performIfAvailable { $0?.failedSyncEvents(ownerUserId: ownerUserId, limit: limit) ?? [] }
    }

    func nextPendingRetryDate() async -> Date? {
        await performIfAvailable { $0?.nextPendingRetryDate() }
    }

    func nextPendingRetryDate(ownerUserId: UUID) async -> Date? {
        await performIfAvailable { $0?.nextPendingRetryDate(ownerUserId: ownerUserId) }
    }

    func quarantinedSyncCount() async -> Int {
        await performIfAvailable { $0?.quarantinedSyncCount() ?? 0 }
    }

    func localSchemaVersion() async -> Int {
        await performIfAvailable { $0?.schemaVersion() ?? 0 }
    }

    func resetAllLocalData() async throws {
        try await perform { try $0.resetAllData() }
        defaults.removeObject(forKey: "personalDetails")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("morningCheckIn.") {
            defaults.removeObject(forKey: key)
        }
    }

    func localDataSummary(ownerId: UUID) async -> LocalDataSummary {
        await performIfAvailable { $0?.localDataSummary(ownerId: ownerId) ?? .empty }
    }

    func claimLocalData(from localOwnerId: UUID, to accountOwnerId: UUID) async throws {
        try await perform { try $0.claimLocalData(from: localOwnerId, to: accountOwnerId) }
        let oldKey = "personalDetails.\(localOwnerId.uuidString)"
        let newKey = "personalDetails.\(accountOwnerId.uuidString)"
        if defaults.object(forKey: newKey) == nil, let details = defaults.data(forKey: oldKey) {
            defaults.set(details, forKey: newKey)
        }
        let checkInKey = UserDefaultsMorningCheckInStore.key(localOwnerId)
        let accountCheckInKey = UserDefaultsMorningCheckInStore.key(accountOwnerId)
        if defaults.object(forKey: accountCheckInKey) == nil, let status = defaults.object(forKey: checkInKey) {
            defaults.set(status, forKey: accountCheckInKey)
        }
        defaults.removeObject(forKey: checkInKey)
        defaults.removeObject(forKey: oldKey)
    }

    func deleteLocalData(ownerId: UUID) async throws {
        try await perform { try $0.deleteLocalData(ownerId: ownerId) }
        defaults.removeObject(forKey: "personalDetails.\(ownerId.uuidString)")
        defaults.removeObject(forKey: UserDefaultsMorningCheckInStore.key(ownerId))
        let profilePrefixes = ["lastAmount.\(ownerId.uuidString).", "useLastAmount.\(ownerId.uuidString)."]
        for key in defaults.dictionaryRepresentation().keys
            where profilePrefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
    }
    
    func fetchPendingEvents(limit: Int) async -> [SyncEvent] {
        await performIfAvailable { $0?.fetchPendingEvents(limit: limit) ?? [] }
    }

    func fetchPendingEvents(ownerUserId: UUID, limit: Int) async -> [SyncEvent] {
        await performIfAvailable { $0?.fetchPendingEvents(ownerUserId: ownerUserId, limit: limit) ?? [] }
    }
    
    func markEventsInFlight(_ eventIds: [UUID]) async {
        await performIfAvailable { $0?.markEventsInFlight(eventIds) }
    }
    
    func markEventsAcked(_ eventIds: [UUID]) async {
        await performIfAvailable { $0?.markEventsAcked(eventIds) }
    }
    
    func markEventForRetry(_ eventId: UUID, error: String?, backoffSeconds: TimeInterval) async {
        await performIfAvailable { $0?.markEventForRetry(eventId, error: error, backoffSeconds: backoffSeconds) }
    }

    func markEventDeadLetter(_ eventId: UUID, error: String) async {
        await performIfAvailable { $0?.markEventDeadLetter(eventId, error: error) }
    }

    func retryFailedEvents(ownerUserId: UUID) async {
        await performIfAvailable { $0?.retryDeadLetterEvents(ownerUserId: ownerUserId) }
    }

    func retryFailedEvent(_ eventId: UUID, ownerUserId: UUID) async {
        await performIfAvailable { $0?.retryDeadLetterEvent(eventId, ownerUserId: ownerUserId) }
    }
    
    func resetInFlightEvents() async {
        await performIfAvailable { $0?.resetInFlightToPending() }
    }
    
    func cleanupAckedEvents(olderThanDays: Int) async {
        await performIfAvailable { $0?.cleanupAckedEvents(olderThanDays: olderThanDays) }
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
