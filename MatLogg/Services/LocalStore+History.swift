import Foundation

// Read-only domain operations; connection, queue and transactions remain owned by LocalStore.
extension LocalStore {
    func loadAllLogs(userId: UUID) throws -> [FoodLog] {
        try readRows(sql: "SELECT json FROM logs WHERE userId = ? ORDER BY loggedTime DESC;", values: [.text(userId.uuidString)]) { try $0.decode(FoodLog.self) }
    }

    func loadLogs(userId: UUID, from start: Date, before end: Date) throws -> [FoodLog] {
        try readRows(sql: "SELECT json FROM logs WHERE userId = ? AND loggedDate >= ? AND loggedDate < ? ORDER BY loggedTime DESC;", values: [.text(userId.uuidString), .number(start.timeIntervalSince1970), .number(end.timeIntervalSince1970)]) { try $0.decode(FoodLog.self) }
    }

    func loadLoggingDates(userId: UUID) throws -> [Date] {
        try readRows(sql: "SELECT DISTINCT loggedDate FROM logs WHERE userId = ?;", values: [.text(userId.uuidString)]) { Date(timeIntervalSince1970: try $0.number(0)) }
    }

    func loadSummary(userId: UUID, date: Date) throws -> DailySummary {
        guard let summary = try loadSummaries(userId: userId, dates: [date]).first else {
            throw LocalStoreError.invalidStoredData("Kunne ikke lese dagsoversikten.")
        }
        return summary
    }

    func loadSummaries(userId: UUID, dates: [Date]) throws -> [DailySummary] {
        let calendar = Calendar.current
        let days = dates.map { calendar.startOfDay(for: $0) }
        guard let first = days.min(), let last = days.max(),
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return [] }
        let logs = try loadLogs(userId: userId, from: first, before: end)
        return DailySummary.summaries(userId: userId, dates: dates, logs: logs, calendar: calendar)
    }

    func getLoggedProductTimes(owner: UUID, before: Date) throws -> [UUID: Date] {
        let rows = try readRows(sql: "SELECT l.productId, MAX(l.loggedTime) FROM logs l JOIN products p ON p.id = l.productId WHERE l.userId = ? AND l.loggedDate <= ? AND l.loggedTime <= ? AND (p.storageKind = 'catalog' OR p.ownerUserId = ?) GROUP BY l.productId;", values: [.text(owner.uuidString), .number(Calendar.current.startOfDay(for: before).timeIntervalSince1970), .number(before.timeIntervalSince1970), .text(owner.uuidString)]) { row in
            (try row.uuid(0), Date(timeIntervalSince1970: try row.number(1)))
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    func getRecentFoods(owner: UUID, before: Date, limit: Int) throws -> [RecentFood] {
        guard limit > 0 else { return [] }
        let sql = """
        WITH ranked AS (
            SELECT json, productId, loggedTime, id, json_extract(json, '$.createdAt') AS createdAt,
                   ROW_NUMBER() OVER (PARTITION BY productId ORDER BY loggedTime DESC, json_extract(json, '$.createdAt') DESC, id DESC) AS rank
            FROM logs WHERE userId = ? AND loggedDate <= ? AND loggedTime <= ?
        )
        SELECT p.json, r.json FROM ranked r JOIN products p ON p.id = r.productId
        WHERE r.rank = 1 AND (p.storageKind = 'catalog' OR p.ownerUserId = ?)
        ORDER BY r.loggedTime DESC, r.createdAt DESC, r.id DESC LIMIT ?;
        """
        return try readRows(sql: sql, values: [.text(owner.uuidString), .number(Calendar.current.startOfDay(for: before).timeIntervalSince1970), .number(before.timeIntervalSince1970), .text(owner.uuidString), .integer(min(limit, 100))]) { row in
            let log = try row.decode(FoodLog.self, column: 1)
            guard log.userId == owner else { throw LocalStoreError.ownershipMismatch }
            return RecentFood(product: try row.decode(Product.self), log: log)
        }
    }

    func getWaterGlasses(userId: UUID) throws -> [WaterGlass] {
        try readRows(sql: "SELECT json FROM water_logs WHERE userId = ?;", values: [.text(userId.uuidString)]) { try $0.decode(WaterGlass.self) }.sorted { $0.createdAt < $1.createdAt }
    }

    func getRecentScans(userId: UUID, limit: Int) throws -> [ScanHistory] {
        try loadRecentScans(userId: userId, limit: limit)
    }

    func loadRecentScans(userId: UUID, limit: Int) throws -> [ScanHistory] {
        try readRows(sql: "SELECT id, userId, productId, scannedAt FROM scans WHERE userId = ? ORDER BY scannedAt DESC LIMIT ?;", values: [.text(userId.uuidString), .integer(max(0, limit))]) { row in
            ScanHistory(id: try row.uuid(0), userId: try row.uuid(1), productId: try row.uuid(2), scannedAt: Date(timeIntervalSince1970: try row.number(3)))
        }
    }
}
