import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LocalStore {
    static let shared = LocalStore()
    
    private let queue = DispatchQueue(label: "matlogg.localstore.queue")
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        openDatabase()
        createTables()
        resetInFlightToPending()
    }
    
    // MARK: - Goals
    
    func saveGoal(_ goal: Goal) throws {
        let data = try encoder.encode(goal)
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO goals(id, userId, createdDate, json)
            VALUES(?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, goal.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, goal.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, goal.createdDate.timeIntervalSince1970)
            bindBlob(stmt, index: 4, data: data)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        enqueueSyncEvent(type: .goalUpsert, entityId: goal.id.uuidString, payload: data)
    }
    
    func getLatestGoal(userId: UUID) -> Goal? {
        queue.sync {
            let sql = """
            SELECT json FROM goals
            WHERE userId = ?
            ORDER BY createdDate DESC
            LIMIT 1;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0) {
                    return try? decoder.decode(Goal.self, from: data)
                }
            }
            return nil
        }
    }
    
    // MARK: - Logs
    
    func saveLog(_ log: FoodLog) throws {
        let data = try encoder.encode(log)
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO logs(id, userId, productId, mealType, loggedDate, loggedTime, calories, protein, carbs, fat, json)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, log.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, log.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, log.productId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, log.mealType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 5, log.loggedDate.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 6, log.loggedTime.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 7, Int32(log.calories))
            sqlite3_bind_double(stmt, 8, Double(log.proteinG))
            sqlite3_bind_double(stmt, 9, Double(log.carbsG))
            sqlite3_bind_double(stmt, 10, Double(log.fatG))
            bindBlob(stmt, index: 11, data: data)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        enqueueSyncEvent(type: .logUpsert, entityId: log.id.uuidString, payload: data)
    }
    
    func deleteLog(_ id: UUID) throws {
        queue.sync {
            let sql = "DELETE FROM logs WHERE id = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        let payload = try? encoder.encode(SyncEventIdPayload(id: id.uuidString))
        if let payload {
            enqueueSyncEvent(type: .logDelete, entityId: id.uuidString, payload: payload)
        }
    }
    
    func getAllLogs(userId: UUID) -> [FoodLog] {
        queue.sync {
            let sql = """
            SELECT json FROM logs
            WHERE userId = ?
            ORDER BY loggedTime DESC;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            var results: [FoodLog] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0),
                   let log = try? decoder.decode(FoodLog.self, from: data) {
                    results.append(log)
                }
            }
            return results
        }
    }
    
    func getSummary(userId: UUID, date: Date) -> DailySummary {
        let dayStart = Calendar.current.startOfDay(for: date)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let logs = queue.sync { () -> [FoodLog] in
            let sql = """
            SELECT json FROM logs
            WHERE userId = ?
            AND loggedDate >= ?
            AND loggedDate < ?
            ORDER BY loggedTime ASC;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, dayStart.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 3, nextDay.timeIntervalSince1970)
            defer { sqlite3_finalize(stmt) }
            var results: [FoodLog] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0),
                   let log = try? decoder.decode(FoodLog.self, from: data) {
                    results.append(log)
                }
            }
            return results
        }
        
        let totalCalories = logs.reduce(0) { $0 + $1.calories }
        let totalProtein = logs.reduce(0) { $0 + $1.proteinG }
        let totalCarbs = logs.reduce(0) { $0 + $1.carbsG }
        let totalFat = logs.reduce(0) { $0 + $1.fatG }
        
        return DailySummary(
            date: dayStart,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            logs: logs
        )
    }
    
    // MARK: - Products
    
    func saveProduct(_ product: Product) throws {
        let data = try encoder.encode(product)
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO products(id, barcode, json)
            VALUES(?, ?, ?);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, product.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, product.barcodeEan ?? "", -1, SQLITE_TRANSIENT)
            bindBlob(stmt, index: 3, data: data)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        enqueueSyncEvent(type: .productUpsert, entityId: product.id.uuidString, payload: data)
    }
    
    func getProduct(_ id: UUID) -> Product? {
        queue.sync {
            let sql = "SELECT json FROM products WHERE id = ? LIMIT 1;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0) {
                    return try? decoder.decode(Product.self, from: data)
                }
            }
            return nil
        }
    }
    
    func getProductByBarcode(_ barcode: String) -> Product? {
        queue.sync {
            let sql = "SELECT json FROM products WHERE barcode = ? LIMIT 1;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, barcode, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0) {
                    return try? decoder.decode(Product.self, from: data)
                }
            }
            return nil
        }
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(userId: UUID, productId: UUID) throws {
        if let existingId = favoriteId(userId: userId, productId: productId) {
            queue.sync {
                let sql = "DELETE FROM favorites WHERE id = ?;"
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, existingId, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
            let payload = try? encoder.encode(SyncEventIdPayload(id: existingId))
            if let payload {
                enqueueSyncEvent(type: .favoriteRemove, entityId: existingId, payload: payload)
            }
            return
        }
        
        let favorite = Favorite(userId: userId, productId: productId)
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO favorites(id, userId, productId, createdAt)
            VALUES(?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, favorite.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, favorite.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, favorite.productId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 4, favorite.createdAt.timeIntervalSince1970)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        let payload = try? encoder.encode(favorite)
        if let payload {
            enqueueSyncEvent(type: .favoriteAdd, entityId: favorite.id.uuidString, payload: payload)
        }
    }
    
    func isFavorite(userId: UUID, productId: UUID) -> Bool {
        favoriteId(userId: userId, productId: productId) != nil
    }
    
    func getFavorites(userId: UUID, kind: ProductKind? = nil) -> [Product] {
        let favoriteProductIds = queue.sync { () -> [String] in
            let sql = "SELECT productId FROM favorites WHERE userId = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            var ids: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cString = sqlite3_column_text(stmt, 0) {
                    ids.append(String(cString: cString))
                }
            }
            return ids
        }
        
        var results: [Product] = []
        for id in favoriteProductIds {
            if let uuid = UUID(uuidString: id), let product = getProduct(uuid) {
                if let kind, product.kind != kind {
                    continue
                }
                results.append(product)
            }
        }
        return results
    }
    
    // MARK: - Scans
    
    func saveScanHistory(userId: UUID, productId: UUID) throws {
        let scan = ScanHistory(userId: userId, productId: productId)
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO scans(id, userId, productId, scannedAt)
            VALUES(?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, scan.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, scan.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, scan.productId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 4, scan.scannedAt.timeIntervalSince1970)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
    
    func getRecentScans(userId: UUID, limit: Int) -> [ScanHistory] {
        queue.sync {
            let sql = """
            SELECT id, userId, productId, scannedAt FROM scans
            WHERE userId = ?
            ORDER BY scannedAt DESC
            LIMIT ?;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            defer { sqlite3_finalize(stmt) }
            var results: [ScanHistory] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idText = sqlite3_column_text(stmt, 0),
                      let userText = sqlite3_column_text(stmt, 1),
                      let productText = sqlite3_column_text(stmt, 2) else { continue }
                let id = UUID(uuidString: String(cString: idText)) ?? UUID()
                let userId = UUID(uuidString: String(cString: userText)) ?? UUID()
                let productId = UUID(uuidString: String(cString: productText)) ?? UUID()
                let scannedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
                results.append(ScanHistory(id: id, userId: userId, productId: productId, scannedAt: scannedAt))
            }
            return results
        }
    }
    
    // MARK: - Weight
    
    func saveWeightEntry(_ entry: WeightEntry) throws {
        let data = try encoder.encode(entry)
        queue.sync {
            let deleteSql = "DELETE FROM weights WHERE userId = ? AND date = ?;"
            var deleteStmt: OpaquePointer?
            sqlite3_prepare_v2(db, deleteSql, -1, &deleteStmt, nil)
            sqlite3_bind_text(deleteStmt, 1, entry.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(deleteStmt, 2, entry.date.timeIntervalSince1970)
            sqlite3_step(deleteStmt)
            sqlite3_finalize(deleteStmt)
            
            let insertSql = """
            INSERT OR REPLACE INTO weights(id, userId, date, json)
            VALUES(?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, insertSql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, entry.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, entry.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, entry.date.timeIntervalSince1970)
            bindBlob(stmt, index: 4, data: data)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        enqueueSyncEvent(type: .weightUpsert, entityId: entry.id.uuidString, payload: data)
    }
    
    func deleteWeightEntry(_ id: UUID) throws {
        queue.sync {
            let sql = "DELETE FROM weights WHERE id = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        let payload = try? encoder.encode(SyncEventIdPayload(id: id.uuidString))
        if let payload {
            enqueueSyncEvent(type: .weightDelete, entityId: id.uuidString, payload: payload)
        }
    }
    
    func getWeightEntries(userId: UUID) -> [WeightEntry] {
        queue.sync {
            let sql = """
            SELECT json FROM weights
            WHERE userId = ?
            ORDER BY date ASC;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            var results: [WeightEntry] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0),
                   let entry = try? decoder.decode(WeightEntry.self, from: data) {
                    results.append(entry)
                }
            }
            return results
        }
    }
    
    // MARK: - Recent Products
    
    func getRecentProducts(userId: UUID, kind: ProductKind?, limit: Int) -> [Product] {
        let recentLogs = queue.sync { () -> [String] in
            let sql = """
            SELECT productId FROM logs
            WHERE userId = ?
            ORDER BY loggedTime DESC;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            var ids: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cString = sqlite3_column_text(stmt, 0) {
                    ids.append(String(cString: cString))
                }
            }
            return ids
        }
        
        var seen = Set<UUID>()
        var results: [Product] = []
        for id in recentLogs {
            guard let uuid = UUID(uuidString: id), seen.insert(uuid).inserted else { continue }
            if let product = getProduct(uuid) {
                if let kind, product.kind != kind {
                    continue
                }
                results.append(product)
                if results.count >= limit {
                    break
                }
            }
        }
        return results
    }
    
    // MARK: - Match Mappings & Cache
    
    func saveMatchMapping(_ mapping: ProductMatchMapping) {
        if let data = try? encoder.encode(mapping) {
            queue.sync {
                let sql = """
                INSERT OR REPLACE INTO match_mappings(barcode, updatedAt, json)
                VALUES(?, ?, ?);
                """
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, mapping.barcode, -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(stmt, 2, mapping.updatedAt.timeIntervalSince1970)
                bindBlob(stmt, index: 3, data: data)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }
    
    func getMatchMapping(for barcode: String) -> ProductMatchMapping? {
        queue.sync {
            let sql = "SELECT json FROM match_mappings WHERE barcode = ? LIMIT 1;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, barcode, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW,
               let data = readBlob(stmt, index: 0) {
                return try? decoder.decode(ProductMatchMapping.self, from: data)
            }
            return nil
        }
    }
    
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) {
        if let data = try? encoder.encode(items) {
            queue.sync {
                let sql = """
                INSERT OR REPLACE INTO matvare_cache(id, updatedAt, json)
                VALUES(1, ?, ?);
                """
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
                bindBlob(stmt, index: 2, data: data)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }
    
    func getMatvaretabellenCache(maxAgeDays: Int) -> [MatvaretabellenProduct]? {
        queue.sync {
            let sql = "SELECT updatedAt, json FROM matvare_cache WHERE id = 1 LIMIT 1;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
                let ageDays = Calendar.current.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0
                guard ageDays <= maxAgeDays,
                      let data = readBlob(stmt, index: 1) else { return nil }
                return try? decoder.decode([MatvaretabellenProduct].self, from: data)
            }
            return nil
        }
    }
    
    // MARK: - Sync Queue
    
    func pendingSyncCount() -> Int {
        queue.sync {
            let sql = "SELECT COUNT(*) FROM sync_queue WHERE status = 'pending';"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW {
                return Int(sqlite3_column_int(stmt, 0))
            }
            return 0
        }
    }
    
    func fetchPendingEvents(limit: Int) -> [SyncEvent] {
        let now = Date().timeIntervalSince1970
        return queue.sync {
            let sql = """
            SELECT eventId, type, createdAt, entityId, payload, status, attemptCount, lastAttemptAt, nextRetryAt, lastError
            FROM sync_queue
            WHERE status = 'pending' AND (nextRetryAt IS NULL OR nextRetryAt <= ?)
            ORDER BY createdAt ASC
            LIMIT ?;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_double(stmt, 1, now)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            defer { sqlite3_finalize(stmt) }
            var results: [SyncEvent] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let eventIdText = sqlite3_column_text(stmt, 0),
                      let typeText = sqlite3_column_text(stmt, 1) else { continue }
                let eventId = UUID(uuidString: String(cString: eventIdText)) ?? UUID()
                let type = String(cString: typeText)
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                let entityId = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                let payload = readBlob(stmt, index: 4) ?? Data()
                let statusRaw = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "pending"
                let attemptCount = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? 0 : Int(sqlite3_column_int(stmt, 6))
                let lastAttemptAt = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
                let nextRetryAt = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
                let lastError = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
                let status = SyncEventStatus(rawValue: statusRaw) ?? .pending
                results.append(SyncEvent(
                    eventId: eventId,
                    type: type,
                    createdAt: createdAt,
                    entityId: entityId,
                    payload: payload,
                    status: status,
                    attemptCount: attemptCount,
                    lastAttemptAt: lastAttemptAt,
                    nextRetryAt: nextRetryAt,
                    lastError: lastError
                ))
            }
            return results
        }
    }
    
    func markEventsInFlight(_ eventIds: [UUID]) {
        guard !eventIds.isEmpty else { return }
        queue.sync {
            let sql = """
            UPDATE sync_queue
            SET status = 'inFlight', attemptCount = COALESCE(attemptCount, 0) + 1, lastAttemptAt = ?
            WHERE eventId = ?;
            """
            let now = Date().timeIntervalSince1970
            for id in eventIds {
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                sqlite3_bind_double(stmt, 1, now)
                sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }
    
    func markEventsAcked(_ eventIds: [UUID]) {
        guard !eventIds.isEmpty else { return }
        queue.sync {
            let sql = """
            UPDATE sync_queue
            SET status = 'acked', lastError = NULL
            WHERE eventId = ?;
            """
            for id in eventIds {
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }
    }
    
    func markEventForRetry(_ eventId: UUID, error: String?, backoffSeconds: TimeInterval) {
        queue.sync {
            let sql = """
            UPDATE sync_queue
            SET status = 'pending', nextRetryAt = ?, lastError = ?
            WHERE eventId = ?;
            """
            let retryAt = Date().addingTimeInterval(backoffSeconds).timeIntervalSince1970
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_double(stmt, 1, retryAt)
            if let error {
                sqlite3_bind_text(stmt, 2, error, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            sqlite3_bind_text(stmt, 3, eventId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
    
    func resetInFlightToPending() {
        queue.sync {
            let sql = """
            UPDATE sync_queue
            SET status = 'pending'
            WHERE status = 'inFlight';
            """
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }
    
    func cleanupAckedEvents(olderThanDays: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())?.timeIntervalSince1970 ?? 0
        queue.sync {
            let sql = "DELETE FROM sync_queue WHERE status = 'acked' AND createdAt < ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_double(stmt, 1, cutoff)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
    
    // MARK: - Helpers
    
    private func openDatabase() {
        let url = databaseURL()
        sqlite3_open(url.path, &db)
    }
    
    private func createTables() {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS goals(
                id TEXT PRIMARY KEY,
                userId TEXT,
                createdDate REAL,
                json BLOB
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS logs(
                id TEXT PRIMARY KEY,
                userId TEXT,
                productId TEXT,
                mealType TEXT,
                loggedDate REAL,
                loggedTime REAL,
                calories INTEGER,
                protein REAL,
                carbs REAL,
                fat REAL,
                json BLOB
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS products(
                id TEXT PRIMARY KEY,
                barcode TEXT,
                json BLOB
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS favorites(
                id TEXT PRIMARY KEY,
                userId TEXT,
                productId TEXT,
                createdAt REAL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS scans(
                id TEXT PRIMARY KEY,
                userId TEXT,
                productId TEXT,
                scannedAt REAL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS weights(
                id TEXT PRIMARY KEY,
                userId TEXT,
                date REAL,
                json BLOB
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS match_mappings(
                barcode TEXT PRIMARY KEY,
                updatedAt REAL,
                json BLOB
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS matvare_cache(
                id INTEGER PRIMARY KEY,
                updatedAt REAL,
                json BLOB
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS sync_queue(
                eventId TEXT PRIMARY KEY,
                type TEXT,
                createdAt REAL,
                entityId TEXT,
                payload BLOB,
                status TEXT,
                attemptCount INTEGER,
                lastAttemptAt REAL,
                nextRetryAt REAL,
                lastError TEXT
            );
            """
        ]
        queue.sync {
            for sql in statements {
                sqlite3_exec(db, sql, nil, nil, nil)
            }
        }
        ensureSyncQueueSchema()
    }
    
    private func databaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MatLogg", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("matlogg.sqlite")
    }
    
    private func bindBlob(_ stmt: OpaquePointer?, index: Int32, data: Data) {
        data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(stmt, index, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    private func ensureSyncQueueSchema() {
        let expectedColumns: [String: String] = [
            "eventId": "TEXT PRIMARY KEY",
            "type": "TEXT",
            "createdAt": "REAL",
            "entityId": "TEXT",
            "payload": "BLOB",
            "status": "TEXT",
            "attemptCount": "INTEGER",
            "lastAttemptAt": "REAL",
            "nextRetryAt": "REAL",
            "lastError": "TEXT"
        ]
        let existing = queue.sync { () -> Set<String> in
            var columns = Set<String>()
            let sql = "PRAGMA table_info(sync_queue);"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(stmt, 1) {
                    columns.insert(String(cString: name))
                }
            }
            return columns
        }
        
        if existing.contains("id"), !existing.contains("eventId") {
            queue.sync {
                sqlite3_exec(db, "ALTER TABLE sync_queue RENAME COLUMN id TO eventId;", nil, nil, nil)
            }
        }
        
        let refreshed = queue.sync { () -> Set<String> in
            var columns = Set<String>()
            let sql = "PRAGMA table_info(sync_queue);"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let name = sqlite3_column_text(stmt, 1) {
                    columns.insert(String(cString: name))
                }
            }
            return columns
        }
        
        for (column, definition) in expectedColumns where !refreshed.contains(column) {
            let sql = "ALTER TABLE sync_queue ADD COLUMN \(column) \(definition);"
            queue.sync {
                sqlite3_exec(db, sql, nil, nil, nil)
            }
        }
    }
    
    private func readBlob(_ stmt: OpaquePointer?, index: Int32) -> Data? {
        guard let blob = sqlite3_column_blob(stmt, index) else { return nil }
        let size = Int(sqlite3_column_bytes(stmt, index))
        return Data(bytes: blob, count: size)
    }
    
    private func favoriteId(userId: UUID, productId: UUID) -> String? {
        queue.sync {
            let sql = "SELECT id FROM favorites WHERE userId = ? AND productId = ? LIMIT 1;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, productId.uuidString, -1, SQLITE_TRANSIENT)
            defer { sqlite3_finalize(stmt) }
            if sqlite3_step(stmt) == SQLITE_ROW,
               let cString = sqlite3_column_text(stmt, 0) {
                return String(cString: cString)
            }
            return nil
        }
    }
    
    private func enqueueSyncEvent(type: SyncEventType, entityId: String?, payload: Data) {
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO sync_queue(eventId, type, createdAt, entityId, payload, status, attemptCount)
            VALUES(?, ?, ?, ?, ?, 'pending', 0);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            let eventId = UUID().uuidString
            sqlite3_bind_text(stmt, 1, eventId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
            if let entityId {
                sqlite3_bind_text(stmt, 4, entityId, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            bindBlob(stmt, index: 5, data: payload)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}

private struct SyncEventIdPayload: Codable {
    let id: String
}

private enum SyncEventType: String {
    case goalUpsert = "goal_upsert"
    case logUpsert = "log_upsert"
    case logDelete = "log_delete"
    case productUpsert = "product_upsert"
    case favoriteAdd = "favorite_add"
    case favoriteRemove = "favorite_remove"
    case weightUpsert = "weight_upsert"
    case weightDelete = "weight_delete"
}
