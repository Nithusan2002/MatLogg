import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LocalStore {
    static let shared = LocalStore(databaseURL: nil)
    static let latestSchemaVersion = 1
    
    private let queue = DispatchQueue(label: "matlogg.localstore.queue")
    private let configuredDatabaseURL: URL?
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let syncEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    init(databaseURL: URL?) {
        configuredDatabaseURL = databaseURL
        openDatabase()
        do {
            try migrateDatabase()
        } catch {
            fatalError("Kunne ikke migrere lokal database: \(error.localizedDescription)")
        }
        resetInFlightToPending()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func schemaVersion() -> Int {
        queue.sync { schemaVersionLocked() }
    }

    func resetAllData() throws {
        try queue.sync {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                for table in ["favorites", "scans", "logs", "goals", "weights", "match_mappings", "matvare_cache", "sync_queue", "products"] {
                    try execute("DELETE FROM \(table);")
                }
                try execute("COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }
    
    // MARK: - Goals
    
    func saveGoal(_ goal: Goal) throws {
        let data = try encoder.encode(goal)
        let payload = try syncEncoder.encode(GoalSyncPayload(goal: goal))
        try performAtomicWrite(type: .goalSet, entityId: goal.id.uuidString, payload: payload) {
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
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
        }
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
        let payload = try syncEncoder.encode(LogSyncPayload(log: log))
        try performAtomicWrite(type: .logUpsert, entityId: log.id.uuidString, payload: payload) {
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
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
        }
    }
    
    func deleteLog(_ id: UUID) throws {
        let payload = try syncEncoder.encode(SyncEventIdPayload(id: id.uuidString))
        try performAtomicWrite(type: .logDelete, entityId: id.uuidString, payload: payload) {
            let sql = "DELETE FROM logs WHERE id = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
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
        let payload = try syncEncoder.encode(ProductSyncPayload(product: product))
        try performAtomicWrite(type: .productUpsert, entityId: product.id.uuidString, payload: payload) {
            let sql = """
            INSERT INTO products(id, barcode, json)
            VALUES(?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                barcode = excluded.barcode,
                json = excluded.json;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, product.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, product.barcodeEan ?? "", -1, SQLITE_TRANSIENT)
            bindBlob(stmt, index: 3, data: data)
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
        }
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
            let payload = try syncEncoder.encode(FavoriteSyncPayload(productId: productId.uuidString))
            try performAtomicWrite(type: .favoriteRemove, entityId: existingId, payload: payload) {
                let sql = "DELETE FROM favorites WHERE id = ?;"
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, existingId, -1, SQLITE_TRANSIENT)
                try requireDone(sqlite3_step(stmt))
                sqlite3_finalize(stmt)
            }
            return
        }
        
        let favorite = Favorite(userId: userId, productId: productId)
        let payload = try syncEncoder.encode(FavoriteSyncPayload(productId: productId.uuidString))
        try performAtomicWrite(type: .favoriteAdd, entityId: favorite.id.uuidString, payload: payload) {
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
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
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
        let payload = try syncEncoder.encode(WeightSyncPayload(entry: entry))
        try performAtomicWrite(type: .weightUpsert, entityId: entry.id.uuidString, payload: payload) {
            let deleteSql = "DELETE FROM weights WHERE userId = ? AND date = ?;"
            var deleteStmt: OpaquePointer?
            sqlite3_prepare_v2(db, deleteSql, -1, &deleteStmt, nil)
            sqlite3_bind_text(deleteStmt, 1, entry.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(deleteStmt, 2, entry.date.timeIntervalSince1970)
            try requireDone(sqlite3_step(deleteStmt))
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
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
        }
    }
    
    func deleteWeightEntry(_ id: UUID) throws {
        let payload = try syncEncoder.encode(SyncEventIdPayload(id: id.uuidString))
        try performAtomicWrite(type: .weightDelete, entityId: id.uuidString, payload: payload) {
            let sql = "DELETE FROM weights WHERE id = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
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
            SELECT eventId, type, createdAt, entityId, schemaVersion, payload, status, attemptCount, lastAttemptAt, nextRetryAt, lastError
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
                let schemaVersion = Int(sqlite3_column_int(stmt, 4))
                let payload = readBlob(stmt, index: 5) ?? Data()
                let statusRaw = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "pending"
                let attemptCount = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? 0 : Int(sqlite3_column_int(stmt, 7))
                let lastAttemptAt = sqlite3_column_type(stmt, 8) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
                let nextRetryAt = sqlite3_column_type(stmt, 9) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 9))
                let lastError = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
                let status = SyncEventStatus(rawValue: statusRaw) ?? .pending
                results.append(SyncEvent(
                    eventId: eventId,
                    type: type,
                    createdAt: createdAt,
                    entityId: entityId,
                    schemaVersion: schemaVersion,
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
        let url = databaseFileURL()
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            fatalError("Kunne ikke åpne lokal database")
        }
    }

    private func migrateDatabase() throws {
        try queue.sync {
            var currentVersion = schemaVersionLocked()
            guard currentVersion <= Self.latestSchemaVersion else {
                throw LocalStoreError.unsupportedSchema(currentVersion)
            }

            while currentVersion < Self.latestSchemaVersion {
                let targetVersion = currentVersion + 1
                try execute("BEGIN IMMEDIATE TRANSACTION;")
                do {
                    switch targetVersion {
                    case 1:
                        try migrateToVersion1Locked()
                    default:
                        throw LocalStoreError.unsupportedSchema(targetVersion)
                    }
                    try execute("PRAGMA user_version = \(targetVersion);")
                    try execute("COMMIT;")
                    currentVersion = targetVersion
                } catch {
                    _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                    throw error
                }
            }
        }
    }

    private func migrateToVersion1Locked() throws {
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
                schemaVersion INTEGER NOT NULL DEFAULT 1,
                payload BLOB,
                status TEXT,
                attemptCount INTEGER,
                lastAttemptAt REAL,
                nextRetryAt REAL,
                lastError TEXT
            );
            """
        ]
        for sql in statements {
            try execute(sql)
        }
        try ensureSyncQueueSchemaLocked()
    }
    
    private func databaseFileURL() -> URL {
        if let configuredDatabaseURL {
            return configuredDatabaseURL
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MatLogg", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("matlogg.sqlite")
    }
    
    private func bindBlob(_ stmt: OpaquePointer?, index: Int32, data: Data) {
        _ = data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(stmt, index, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    private func ensureSyncQueueSchemaLocked() throws {
        let expectedColumns: [String: String] = [
            "eventId": "TEXT",
            "type": "TEXT",
            "createdAt": "REAL",
            "entityId": "TEXT",
            "schemaVersion": "INTEGER NOT NULL DEFAULT 1",
            "payload": "BLOB",
            "status": "TEXT",
            "attemptCount": "INTEGER",
            "lastAttemptAt": "REAL",
            "nextRetryAt": "REAL",
            "lastError": "TEXT"
        ]
        let existing = columnNamesLocked(table: "sync_queue")
        
        if existing.contains("id"), !existing.contains("eventId") {
            try execute("ALTER TABLE sync_queue RENAME COLUMN id TO eventId;")
        }
        
        let refreshed = columnNamesLocked(table: "sync_queue")
        
        for (column, definition) in expectedColumns where !refreshed.contains(column) {
            try execute("ALTER TABLE sync_queue ADD COLUMN \(column) \(definition);")
        }
    }

    private func schemaVersionLocked() -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func columnNamesLocked(table: String) -> Set<String> {
        var columns = Set<String>()
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &stmt, nil) == SQLITE_OK else {
            return columns
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = sqlite3_column_text(stmt, 1) {
                columns.insert(String(cString: name))
            }
        }
        return columns
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
    
    private func performAtomicWrite(type: SyncEventType, entityId: String?, payload: Data, write: () throws -> Void) throws {
        try queue.sync {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try write()
                try enqueueSyncEventLocked(type: type, entityId: entityId, payload: payload)
                try execute("COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    private func enqueueSyncEventLocked(type: SyncEventType, entityId: String?, payload: Data) throws {
        let sql = """
        INSERT INTO sync_queue(eventId, type, createdAt, entityId, schemaVersion, payload, status, attemptCount)
        VALUES(?, ?, ?, ?, 1, ?, 'pending', 0);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, UUID().uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        if let entityId { sqlite3_bind_text(stmt, 4, entityId, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        bindBlob(stmt, index: 5, data: payload)
        try requireDone(sqlite3_step(stmt))
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw databaseError() }
    }

    private func requireDone(_ result: Int32) throws {
        guard result == SQLITE_DONE else { throw databaseError() }
    }

    private func databaseError() -> LocalStoreError {
        LocalStoreError.sqlite(db.flatMap(sqlite3_errmsg).map { String(cString: $0) } ?? "Ukjent SQLite-feil")
    }
}

private struct SyncEventIdPayload: Codable {
    let id: String
}

private struct GoalSyncPayload: Codable {
    let kcalTarget: Int
    let proteinTarget: Float
    let carbTarget: Float
    let fatTarget: Float

    init(goal: Goal) {
        kcalTarget = goal.dailyCalories
        proteinTarget = goal.proteinTargetG
        carbTarget = goal.carbsTargetG
        fatTarget = goal.fatTargetG
    }
}

private struct LogSyncPayload: Codable {
    let id: String
    let date: Date
    let meal: String
    let grams: Float
    let kcal: Int
    let protein: Float
    let carbs: Float
    let fat: Float
    let productRef: String?

    init(log: FoodLog) {
        id = log.id.uuidString
        date = log.loggedTime
        meal = log.mealType
        grams = log.amountG
        kcal = log.calories
        protein = log.proteinG
        carbs = log.carbsG
        fat = log.fatG
        productRef = log.productId.uuidString
    }
}

private struct FavoriteSyncPayload: Codable { let productId: String }
private struct WeightSyncPayload: Codable {
    let id: String
    let date: Date
    let weightKg: Double
    init(entry: WeightEntry) { id = entry.id.uuidString; date = entry.date; weightKg = entry.weightKg }
}

private struct ProductSyncPayload: Codable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let nutrientsPer100g: [String: Double]
    let imageUrl: String?
    let source: String

    init(product: Product) {
        id = product.id.uuidString
        name = product.name
        brand = product.brand
        barcode = product.barcodeEan
        nutrientsPer100g = [
            "kcal": Double(product.caloriesPer100g),
            "protein": Double(product.proteinGPer100g),
            "carbs": Double(product.carbsGPer100g),
            "fat": Double(product.fatGPer100g)
        ]
        imageUrl = product.imageUrl
        source = product.source
    }
}

private enum LocalStoreError: LocalizedError {
    case sqlite(String)
    case unsupportedSchema(Int)
    var errorDescription: String? {
        if case .sqlite(let message) = self { return "Lokal databasefeil: \(message)" }
        if case .unsupportedSchema(let version) = self { return "Databaseskjema \(version) er nyere enn appen støtter" }
        return nil
    }
}

private enum SyncEventType: String {
    case goalSet = "goal.set"
    case logUpsert = "log.upsert"
    case logDelete = "log.delete"
    case productUpsert = "product.upsert"
    case favoriteAdd = "favorite.add"
    case favoriteRemove = "favorite.remove"
    case weightUpsert = "weight.upsert"
    case weightDelete = "weight.delete"
}
