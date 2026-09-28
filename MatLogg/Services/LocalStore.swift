import Foundation
import OSLog
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LocalStore {
    static let sharedResult: Result<LocalStore, Error> = Result {
        try LocalStore(databaseURL: nil)
    }
    static let latestSchemaVersion = 4

    private nonisolated static let logger = Logger(subsystem: "com.nithusan.MatLogg", category: "LocalStore")
    
    private let queue = DispatchQueue(label: "matlogg.localstore.queue")
    private let configuredDatabaseURL: URL?
    private let diagnosticHandler: (LocalStoreDiagnostic) -> Void
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let syncEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    init(
        databaseURL: URL?,
        diagnosticHandler: @escaping (LocalStoreDiagnostic) -> Void = LocalStore.logDiagnostic
    ) throws {
        configuredDatabaseURL = databaseURL
        self.diagnosticHandler = diagnosticHandler
        do {
            try openDatabase()
            try migrateDatabase()
        } catch {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
            throw error
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
                for table in ["favorites", "scans", "logs", "saved_meals", "goals", "weights", "match_mappings", "matvare_cache", "sync_queue", "products"] {
                    try execute("DELETE FROM \(table);")
                }
                try execute("COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    func localDataSummary(ownerId: UUID) -> LocalDataSummary {
        queue.sync {
            LocalDataSummary(
                logs: countLocked(table: "logs", ownerId: ownerId),
                goals: countLocked(table: "goals", ownerId: ownerId),
                favorites: countLocked(table: "favorites", ownerId: ownerId),
                scans: countLocked(table: "scans", ownerId: ownerId),
                weights: countLocked(table: "weights", ownerId: ownerId),
                savedMeals: countLocked(table: "saved_meals", ownerId: ownerId)
            )
        }
    }

    func claimLocalData(from localOwnerId: UUID, to accountOwnerId: UUID) throws {
        guard localOwnerId != accountOwnerId else { return }
        try queue.sync {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                for table in ["goals", "logs", "weights", "saved_meals"] {
                    try rewriteUserIdInJSONLocked(table: table, from: localOwnerId, to: accountOwnerId)
                }
                for table in ["goals", "logs", "favorites", "scans", "weights", "saved_meals"] {
                    try updateOwnerLocked(table: table, column: "userId", from: localOwnerId, to: accountOwnerId)
                }
                try updateOwnerLocked(table: "sync_queue", column: "ownerUserId", from: localOwnerId, to: accountOwnerId)
                try execute("COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    func deleteLocalData(ownerId: UUID) throws {
        try queue.sync {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                for table in ["favorites", "scans", "logs", "saved_meals", "goals", "weights"] {
                    try deleteOwnerRowsLocked(table: table, column: "userId", ownerId: ownerId)
                }
                try deleteOwnerRowsLocked(table: "sync_queue", column: "ownerUserId", ownerId: ownerId)
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
        try performAtomicWrite(ownerUserId: goal.userId, type: .goalSet, entityId: goal.id.uuidString, payload: payload) {
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
                    return decode(Goal.self, from: data, entity: "goal")
                }
            }
            return nil
        }
    }
    
    // MARK: - Logs
    
    func saveLog(_ log: FoodLog) throws {
        try saveLogs([log])
    }

    /// A meal and every corresponding sync event commit together.
    func saveLogs(_ logs: [FoodLog]) throws {
        guard !logs.isEmpty else { return }
        try performTransaction {
            for log in logs {
                let data = try encoder.encode(log)
                let payload = try syncEncoder.encode(LogSyncPayload(log: log))
                try saveLogLocked(log, data: data)
                try enqueueSyncEventLocked(ownerUserId: log.userId, type: .logUpsert, entityId: log.id.uuidString, payload: payload)
            }
        }
    }

    private func saveLogLocked(_ log: FoodLog, data: Data) throws {
        let sql = """
        INSERT OR REPLACE INTO logs(id, userId, productId, mealType, loggedDate, loggedTime, calories, protein, carbs, fat, json)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, log.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, log.userId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, log.productId.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, log.mealType, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 5, log.loggedDate.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 6, log.loggedTime.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 7, Double(log.calories))
        sqlite3_bind_double(stmt, 8, Double(log.proteinG))
        sqlite3_bind_double(stmt, 9, Double(log.carbsG))
        sqlite3_bind_double(stmt, 10, Double(log.fatG))
        bindBlob(stmt, index: 11, data: data)
        try requireDone(sqlite3_step(stmt))
    }

    func deleteLog(_ id: UUID) throws {
        try deleteLogs([id])
    }

    func deleteLogs(_ ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        try performTransaction {
            for id in ids {
                guard let ownerUserId = ownerUserIdLocked(table: "logs", id: id) else { continue }
                let payload = try syncEncoder.encode(SyncEventIdPayload(id: id.uuidString))
                try deleteLogLocked(id)
                try enqueueSyncEventLocked(ownerUserId: ownerUserId, type: .logDelete, entityId: id.uuidString, payload: payload)
            }
        }
    }

    private func deleteLogLocked(_ id: UUID) throws {
        let sql = "DELETE FROM logs WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        try requireDone(sqlite3_step(stmt))
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
                   let log = decode(FoodLog.self, from: data, entity: "food_log") {
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
                   let log = decode(FoodLog.self, from: data, entity: "food_log") {
                    results.append(log)
                }
            }
            return results
        }
        
        let totals = NutritionCalculator.totals(for: logs)
        
        return DailySummary(
            date: dayStart,
            totalCalories: totals.calories,
            totalProtein: totals.protein,
            totalCarbs: totals.carbs,
            totalFat: totals.fat,
            logs: logs
        )
    }

    // MARK: - Saved Meals

    func saveSavedMeal(_ meal: SavedMeal) throws {
        let data = try encoder.encode(meal)
        let payload = try syncEncoder.encode(SavedMealSyncPayload(meal: meal))
        try performAtomicWrite(ownerUserId: meal.userId, type: .savedMealUpsert, entityId: meal.id.uuidString, payload: payload) {
            let sql = """
            INSERT INTO saved_meals(id, userId, name, updatedAt, json)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                updatedAt = excluded.updatedAt,
                json = excluded.json
            WHERE saved_meals.userId = excluded.userId;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, meal.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, meal.userId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, meal.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 4, meal.updatedAt.timeIntervalSince1970)
            bindBlob(stmt, index: 5, data: data)
            try requireDone(sqlite3_step(stmt))
            guard sqlite3_changes(db) == 1 else { throw LocalStoreError.ownershipMismatch }
        }
    }

    func deleteSavedMeal(_ id: UUID, userId: UUID) throws {
        let payload = try syncEncoder.encode(SyncEventIdPayload(id: id.uuidString))
        try performAtomicWrite(ownerUserId: userId, type: .savedMealDelete, entityId: id.uuidString, payload: payload) {
            let sql = "DELETE FROM saved_meals WHERE id = ? AND userId = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, userId.uuidString, -1, SQLITE_TRANSIENT)
            try requireDone(sqlite3_step(stmt))
        }
    }

    func getSavedMeals(userId: UUID) -> [SavedMeal] {
        queue.sync {
            let sql = "SELECT json FROM saved_meals WHERE userId = ? ORDER BY updatedAt DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, userId.uuidString, -1, SQLITE_TRANSIENT)
            var meals: [SavedMeal] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let data = readBlob(stmt, index: 0),
                   let meal = decode(SavedMeal.self, from: data, entity: "saved_meal") {
                    meals.append(meal)
                }
            }
            return meals
        }
    }
    
    // MARK: - Products
    
    func saveProduct(_ product: Product, ownerUserId: UUID) throws {
        let data = try encoder.encode(product)
        let payload = try syncEncoder.encode(ProductSyncPayload(product: product))
        try performAtomicWrite(ownerUserId: ownerUserId, type: .productUpsert, entityId: product.id.uuidString, payload: payload) {
            try saveProductLocked(product, data: data)
        }
    }

    /// Read-only catalog rows are cache state, not user-authored domain writes,
    /// and must therefore never create `product.upsert` sync events.
    func cacheCatalogProduct(_ product: Product) throws {
        let data = try encoder.encode(product)
        try queue.sync {
            try saveProductLocked(product, data: data)
        }
    }

    private func saveProductLocked(_ product: Product, data: Data) throws {
        let sql = """
        INSERT INTO products(id, barcode, json)
        VALUES(?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            barcode = excluded.barcode,
            json = excluded.json;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, product.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, product.barcodeEan ?? "", -1, SQLITE_TRANSIENT)
        bindBlob(stmt, index: 3, data: data)
        try requireDone(sqlite3_step(stmt))
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
                    return decode(Product.self, from: data, entity: "product")
                }
            }
            return nil
        }
    }

    func getProducts(_ ids: Set<UUID>) -> [UUID: Product] {
        guard !ids.isEmpty else { return [:] }
        return queue.sync {
            let orderedIDs = Array(ids)
            let placeholders = Array(repeating: "?", count: orderedIDs.count).joined(separator: ",")
            let sql = "SELECT id, json FROM products WHERE id IN (\(placeholders));"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
            defer { sqlite3_finalize(stmt) }

            for (index, id) in orderedIDs.enumerated() {
                sqlite3_bind_text(stmt, Int32(index + 1), id.uuidString, -1, SQLITE_TRANSIENT)
            }

            var products: [UUID: Product] = [:]
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idText = sqlite3_column_text(stmt, 0),
                      let id = UUID(uuidString: String(cString: idText)),
                      let data = readBlob(stmt, index: 1),
                      let product = decode(Product.self, from: data, entity: "product") else { continue }
                products[id] = product
            }
            return products
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
                    return decode(Product.self, from: data, entity: "product")
                }
            }
            return nil
        }
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(userId: UUID, productId: UUID) throws {
        if let existingId = favoriteId(userId: userId, productId: productId) {
            let payload = try syncEncoder.encode(FavoriteSyncPayload(productId: productId.uuidString))
            try performAtomicWrite(ownerUserId: userId, type: .favoriteRemove, entityId: existingId, payload: payload) {
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
        try performAtomicWrite(ownerUserId: userId, type: .favoriteAdd, entityId: favorite.id.uuidString, payload: payload) {
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
        try performAtomicWrite(ownerUserId: entry.userId, type: .weightUpsert, entityId: entry.id.uuidString, payload: payload) {
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
        try performTransaction {
            guard let ownerUserId = ownerUserIdLocked(table: "weights", id: id) else { return }
            let payload = try syncEncoder.encode(SyncEventIdPayload(id: id.uuidString))
            let sql = "DELETE FROM weights WHERE id = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            try requireDone(sqlite3_step(stmt))
            sqlite3_finalize(stmt)
            try enqueueSyncEventLocked(ownerUserId: ownerUserId, type: .weightDelete, entityId: id.uuidString, payload: payload)
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
                   let entry = decode(WeightEntry.self, from: data, entity: "weight_entry") {
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
                return decode(ProductMatchMapping.self, from: data, entity: "product_match_mapping")
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
                return decode([MatvaretabellenProduct].self, from: data, entity: "matvaretabellen_cache")
            }
            return nil
        }
    }
    
    // MARK: - Sync Queue
    
    func pendingSyncCount() -> Int {
        syncQueueStatus().pendingCount
    }

    func failedSyncCount() -> Int {
        syncQueueStatus().failedCount
    }

    func syncQueueStatus() -> SyncQueueStatus {
        syncQueueStatus(ownerUserId: nil)
    }

    func syncQueueStatus(ownerUserId: UUID?) -> SyncQueueStatus {
        queue.sync {
            let ownerClause = ownerUserId == nil ? "" : "WHERE ownerUserId = ?"
            let sql = """
            SELECT
                SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END),
                SUM(CASE WHEN status = 'inFlight' THEN 1 ELSE 0 END),
                SUM(CASE WHEN status = 'deadLetter' THEN 1 ELSE 0 END),
                MIN(CASE WHEN status = 'pending' THEN nextRetryAt END)
            FROM sync_queue
            \(ownerClause);
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            if let ownerUserId {
                sqlite3_bind_text(stmt, 1, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
            }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return .empty }
            let nextRetryAt = sqlite3_column_type(stmt, 3) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
            return SyncQueueStatus(
                pendingCount: Int(sqlite3_column_int(stmt, 0)),
                inFlightCount: Int(sqlite3_column_int(stmt, 1)),
                failedCount: Int(sqlite3_column_int(stmt, 2)),
                nextRetryAt: nextRetryAt
            )
        }
    }

    func failedSyncEvents(limit: Int) -> [SyncFailureSummary] {
        failedSyncEvents(ownerUserId: nil, limit: limit)
    }

    func failedSyncEvents(ownerUserId: UUID?, limit: Int) -> [SyncFailureSummary] {
        queue.sync {
            let ownerClause = ownerUserId == nil ? "" : "AND ownerUserId = ?"
            let sql = """
            SELECT eventId, type, lastError, createdAt
            FROM sync_queue
            WHERE status = 'deadLetter'
            \(ownerClause)
            ORDER BY createdAt ASC, rowid ASC
            LIMIT ?;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            var index: Int32 = 1
            if let ownerUserId {
                sqlite3_bind_text(stmt, index, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
                index += 1
            }
            sqlite3_bind_int(stmt, index, Int32(limit))
            defer { sqlite3_finalize(stmt) }
            var results: [SyncFailureSummary] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idText = sqlite3_column_text(stmt, 0),
                      let id = UUID(uuidString: String(cString: idText)),
                      let typeText = sqlite3_column_text(stmt, 1) else { continue }
                let message = sqlite3_column_text(stmt, 2).map(String.init(cString:))
                    ?? "Hendelsen ble avvist av serveren."
                results.append(SyncFailureSummary(
                    id: id,
                    type: String(cString: typeText),
                    message: message,
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
                ))
            }
            return results
        }
    }

    func nextPendingRetryDate() -> Date? {
        nextPendingRetryDate(ownerUserId: nil)
    }

    func nextPendingRetryDate(ownerUserId: UUID?) -> Date? {
        queue.sync {
            let ownerClause = ownerUserId == nil ? "" : "AND ownerUserId = ?"
            let sql = "SELECT MIN(nextRetryAt) FROM sync_queue WHERE status = 'pending' AND nextRetryAt IS NOT NULL \(ownerClause);"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            if let ownerUserId {
                sqlite3_bind_text(stmt, 1, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
            }
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW,
                  sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return nil }
            return Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
        }
    }
    
    func fetchPendingEvents(limit: Int) -> [SyncEvent] {
        fetchPendingEvents(ownerUserId: nil, limit: limit)
    }

    func fetchPendingEvents(ownerUserId: UUID?, limit: Int) -> [SyncEvent] {
        let now = Date().timeIntervalSince1970
        return queue.sync {
            let ownerClause = ownerUserId == nil ? "" : "AND ownerUserId = ?"
            let sql = """
            SELECT eventId, type, createdAt, entityId, schemaVersion, payload, status, attemptCount, lastAttemptAt, nextRetryAt, lastError, ownerUserId
            FROM sync_queue
            WHERE status = 'pending' AND (nextRetryAt IS NULL OR nextRetryAt <= ?)
            \(ownerClause)
            ORDER BY createdAt ASC, rowid ASC
            LIMIT ?;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            sqlite3_bind_double(stmt, 1, now)
            var index: Int32 = 2
            if let ownerUserId {
                sqlite3_bind_text(stmt, index, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
                index += 1
            }
            sqlite3_bind_int(stmt, index, Int32(limit))
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
                let storedOwnerUserId = sqlite3_column_text(stmt, 11)
                    .flatMap { UUID(uuidString: String(cString: $0)) }
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
                    lastError: lastError,
                    ownerUserId: storedOwnerUserId
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

    func markEventDeadLetter(_ eventId: UUID, error: String) {
        queue.sync {
            let sql = "UPDATE sync_queue SET status = 'deadLetter', nextRetryAt = NULL, lastError = ? WHERE eventId = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, error, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, eventId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    func retryDeadLetterEvents(ownerUserId: UUID) {
        queue.sync {
            let sql = "UPDATE sync_queue SET status = 'pending', nextRetryAt = NULL WHERE status = 'deadLetter' AND ownerUserId = ?;"
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    func retryDeadLetterEvent(_ eventId: UUID, ownerUserId: UUID) {
        queue.sync {
            let sql = """
            UPDATE sync_queue
            SET status = 'pending', nextRetryAt = NULL
            WHERE status = 'deadLetter' AND eventId = ? AND ownerUserId = ?;
            """
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, eventId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    func quarantinedSyncCount() -> Int {
        queue.sync {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM sync_queue WHERE status = 'quarantined';", -1, &stmt, nil)
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
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
    
    private func openDatabase() throws {
        let url = databaseFileURL()
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw databaseError()
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
                    case 2:
                        try migrateToVersion2Locked()
                    case 3:
                        try migrateToVersion3Locked()
                    case 4:
                        try migrateToVersion4Locked()
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
                calories REAL,
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
                lastError TEXT,
                ownerUserId TEXT
            );
            """
        ]
        for sql in statements {
            try execute(sql)
        }
        try ensureSyncQueueSchemaLocked()
    }

    private func migrateToVersion2Locked() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS saved_meals(
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            name TEXT NOT NULL,
            updatedAt REAL NOT NULL,
            json BLOB NOT NULL
        );
        """)
        try execute("CREATE INDEX IF NOT EXISTS saved_meals_user_updated_idx ON saved_meals(userId, updatedAt DESC);")
    }

    private func migrateToVersion3Locked() throws {
        try execute("CREATE INDEX IF NOT EXISTS products_barcode_idx ON products(barcode);")
    }

    private func migrateToVersion4Locked() throws {
        try ensureSyncQueueSchemaLocked()
        try execute("""
        UPDATE sync_queue
        SET status = 'quarantined',
            nextRetryAt = NULL,
            lastError = 'Mangler sikker lokal brukerbinding etter migrering'
        WHERE ownerUserId IS NULL
          AND COALESCE(status, 'pending') != 'acked';
        """)
        try execute("CREATE INDEX IF NOT EXISTS sync_queue_owner_status_created_idx ON sync_queue(ownerUserId, status, createdAt);")
    }
    
    private func databaseFileURL() -> URL {
        if let configuredDatabaseURL {
            return configuredDatabaseURL
        }
        let fileManager = FileManager.default
        // iOS normally always provides Application Support. Keep a deterministic
        // path inside the app sandbox if the directory lookup unexpectedly fails.
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        let dir = base.appendingPathComponent("MatLogg", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("matlogg.sqlite")
    }
    
    private func bindBlob(_ stmt: OpaquePointer?, index: Int32, data: Data) {
        _ = data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(stmt, index, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data, entity: String) -> T? {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            diagnosticHandler(.decodingFailed(entity: entity, reason: error.localizedDescription))
            return nil
        }
    }

    private nonisolated static func logDiagnostic(_ diagnostic: LocalStoreDiagnostic) {
        switch diagnostic {
        case .decodingFailed(let entity, let reason):
            logger.error("Kunne ikke dekode lokal \(entity, privacy: .public): \(reason, privacy: .public)")
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
            "lastError": "TEXT",
            "ownerUserId": "TEXT"
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
    
    private func performAtomicWrite(ownerUserId: UUID, type: SyncEventType, entityId: String?, payload: Data, write: () throws -> Void) throws {
        try performTransaction {
            try write()
            try enqueueSyncEventLocked(ownerUserId: ownerUserId, type: type, entityId: entityId, payload: payload)
        }
    }

    private func performTransaction(_ write: () throws -> Void) throws {
        try queue.sync {
            try execute("BEGIN IMMEDIATE TRANSACTION;")
            do {
                try write()
                try execute("COMMIT;")
            } catch {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    private func enqueueSyncEventLocked(ownerUserId: UUID, type: SyncEventType, entityId: String?, payload: Data) throws {
        let sql = """
        INSERT INTO sync_queue(eventId, type, createdAt, entityId, schemaVersion, payload, status, attemptCount, ownerUserId)
        VALUES(?, ?, ?, ?, 1, ?, 'pending', 0, ?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, UUID().uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, type.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        if let entityId { sqlite3_bind_text(stmt, 4, entityId, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        bindBlob(stmt, index: 5, data: payload)
        sqlite3_bind_text(stmt, 6, ownerUserId.uuidString, -1, SQLITE_TRANSIENT)
        try requireDone(sqlite3_step(stmt))
    }

    private func ownerUserIdLocked(table: String, id: UUID) -> UUID? {
        precondition(table == "logs" || table == "weights")
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT userId FROM \(table) WHERE id = ? LIMIT 1;", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let value = sqlite3_column_text(stmt, 0) else { return nil }
        return UUID(uuidString: String(cString: value))
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw databaseError() }
    }

    private func countLocked(table: String, ownerId: UUID) -> Int {
        precondition(["logs", "goals", "favorites", "scans", "weights", "saved_meals"].contains(table))
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table) WHERE userId = ?;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, ownerId.uuidString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func updateOwnerLocked(table: String, column: String, from: UUID, to: UUID) throws {
        let allowedTables = ["goals", "logs", "favorites", "scans", "weights", "saved_meals", "sync_queue"]
        precondition(allowedTables.contains(table))
        precondition(column == "userId" || column == "ownerUserId")
        var stmt: OpaquePointer?
        let sql = "UPDATE \(table) SET \(column) = ? WHERE \(column) = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, to.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, from.uuidString, -1, SQLITE_TRANSIENT)
        try requireDone(sqlite3_step(stmt))
    }

    private func deleteOwnerRowsLocked(table: String, column: String, ownerId: UUID) throws {
        let allowedTables = ["goals", "logs", "favorites", "scans", "weights", "saved_meals", "sync_queue"]
        precondition(allowedTables.contains(table))
        precondition(column == "userId" || column == "ownerUserId")
        var stmt: OpaquePointer?
        let sql = "DELETE FROM \(table) WHERE \(column) = ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, ownerId.uuidString, -1, SQLITE_TRANSIENT)
        try requireDone(sqlite3_step(stmt))
    }

    private func rewriteUserIdInJSONLocked(table: String, from: UUID, to: UUID) throws {
        precondition(["goals", "logs", "weights", "saved_meals"].contains(table))
        var select: OpaquePointer?
        let selectSQL = "SELECT id, json FROM \(table) WHERE userId = ?;"
        guard sqlite3_prepare_v2(db, selectSQL, -1, &select, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(select) }
        sqlite3_bind_text(select, 1, from.uuidString, -1, SQLITE_TRANSIENT)

        var rewritten: [(String, Data)] = []
        while sqlite3_step(select) == SQLITE_ROW {
            guard let idValue = sqlite3_column_text(select, 0),
                  let data = readBlob(select, index: 1),
                  var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LocalStoreError.invalidStoredData("Kunne ikke oppdatere lokal eier i \(table)")
            }
            object["userId"] = to.uuidString
            rewritten.append((String(cString: idValue), try JSONSerialization.data(withJSONObject: object)))
        }

        for (id, data) in rewritten {
            var update: OpaquePointer?
            let updateSQL = "UPDATE \(table) SET json = ? WHERE id = ?;"
            guard sqlite3_prepare_v2(db, updateSQL, -1, &update, nil) == SQLITE_OK else { throw databaseError() }
            bindBlob(update, index: 1, data: data)
            sqlite3_bind_text(update, 2, id, -1, SQLITE_TRANSIENT)
            let result = sqlite3_step(update)
            sqlite3_finalize(update)
            try requireDone(result)
        }
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
    let unit: String
    let kcal: Float
    let protein: Float
    let carbs: Float
    let fat: Float
    let productRef: String?

    init(log: FoodLog) {
        id = log.id.uuidString
        date = log.loggedTime
        meal = log.mealType
        grams = log.amountG
        unit = log.resolvedAmountUnit.rawValue
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

private struct SavedMealSyncPayload: Codable {
    let id: String
    let name: String
    let suggestedMealType: String?
    let items: [SavedMealItemSyncPayload]
    let updatedAt: Date

    nonisolated init(meal: SavedMeal) {
        id = meal.id.uuidString
        name = meal.name
        suggestedMealType = meal.suggestedMealType
        items = meal.items.sorted { $0.sortIndex < $1.sortIndex }.map(SavedMealItemSyncPayload.init)
        updatedAt = meal.updatedAt
    }
}

private struct SavedMealItemSyncPayload: Codable {
    let id: String
    let productId: String
    let productName: String
    let amountG: Float
    let amountUnit: String
    let calories: Float
    let protein: Float
    let carbs: Float
    let fat: Float
    let nutritionSource: String
    let sortIndex: Int

    nonisolated init(item: SavedMealItem) {
        id = item.id.uuidString
        productId = item.productId.uuidString
        productName = item.productName
        amountG = item.amountG
        amountUnit = item.resolvedAmountUnit.rawValue
        calories = item.calories
        protein = item.proteinG
        carbs = item.carbsG
        fat = item.fatG
        nutritionSource = item.nutritionSource.rawValue
        sortIndex = item.sortIndex
    }
}

enum LocalStoreDiagnostic: Equatable {
    case decodingFailed(entity: String, reason: String)
}

enum LocalStoreError: LocalizedError {
    case sqlite(String)
    case unsupportedSchema(Int)
    case ownershipMismatch
    case invalidStoredData(String)
    var errorDescription: String? {
        if case .sqlite(let message) = self { return "Lokal databasefeil: \(message)" }
        if case .unsupportedSchema(let version) = self { return "Databaseskjema \(version) er nyere enn appen støtter" }
        if case .ownershipMismatch = self { return "Dataene tilhører en annen bruker" }
        if case .invalidStoredData(let message) = self { return message }
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
    case savedMealUpsert = "saved_meal.upsert"
    case savedMealDelete = "saved_meal.delete"
}
