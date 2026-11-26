import Foundation
import SQLite3
import Testing
@testable import MatLogg

struct HistoryReadFailureTests {
    @Test func successfulEmptyReadIsDistinctFromSQLFailure() throws {
        try withStore { store, url in
            let owner = UUID(), now = Date()
            #expect(try store.loadAllLogs(userId: owner).isEmpty)
            #expect(try store.loadLogs(userId: owner, from: .distantPast, before: .distantFuture).isEmpty)
            try execute("DROP TABLE logs", at: url)
            #expect(throws: LocalStoreError.self) { try store.loadAllLogs(userId: owner) }
            #expect(throws: LocalStoreError.self) {
                try store.loadLogs(userId: owner, from: .distantPast, before: .distantFuture)
            }
            #expect(throws: LocalStoreError.self) { try store.loadSummaries(userId: owner, dates: [now]) }
        }
    }

    @Test func corruptRowCannotProducePartialHistoryOrNutritionTotals() throws {
        try withStore { store, url in
            let owner = UUID(), now = Date()
            let valid = log(owner: owner, date: now)
            let corrupt = log(owner: owner, date: now.addingTimeInterval(-1))
            try store.saveLogs([valid, corrupt])
            try execute("UPDATE logs SET json = X'7B' WHERE id = '\(corrupt.id.uuidString)'", at: url)
            #expect(throws: LocalStoreError.self) { try store.loadAllLogs(userId: owner) }
            #expect(throws: LocalStoreError.self) {
                try store.loadLogs(userId: owner, from: now.addingTimeInterval(-60), before: now.addingTimeInterval(60))
            }
            #expect(throws: LocalStoreError.self) { try store.loadSummaries(userId: owner, dates: [now]) }
        }
    }

    @Test func sqliteStepFailureIsNotAnEmptyResult() throws {
        try withStore { store, url in
            let owner = UUID(), now = Date()
            try store.saveLog(log(owner: owner, date: now))
            // Preparation succeeds, but evaluating this SQLite expression overflows.
            try execute("""
                ALTER TABLE logs RENAME TO stored_logs;
                CREATE VIEW logs AS SELECT userId, loggedDate, loggedTime,
                    abs(-9223372036854775808) AS json FROM stored_logs;
                """, at: url)
            #expect(throws: LocalStoreError.self) { try store.loadAllLogs(userId: owner) }
            #expect(throws: LocalStoreError.self) {
                try store.loadLogs(userId: owner, from: .distantPast, before: .distantFuture)
            }
        }
    }

    @Test func successfulReadPreservesOwnerDateAndOrder() throws {
        try withStore { store, _ in
            let owner = UUID(), date = Date()
            let older = log(owner: owner, date: date.addingTimeInterval(-60))
            let newer = log(owner: owner, date: date)
            try store.saveLogs([older, log(owner: UUID(), date: date), newer])
            #expect(try store.loadAllLogs(userId: owner).map(\.id) == [newer.id, older.id])
            #expect(try store.loadLogs(userId: owner, from: date, before: date.addingTimeInterval(1)).map(\.id) == [newer.id])
        }
    }

    private func log(owner: UUID, date: Date) -> FoodLog {
        FoodLog(userId: owner, productId: UUID(), mealType: "frokost", amountG: 100,
                loggedDate: date, loggedTime: date, calories: 100, proteinG: 10, carbsG: 10, fatG: 2)
    }

    private func withStore(_ body: (LocalStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history-qa.sqlite")
        try body(LocalStore(databaseURL: url, healthWritesEnabled: false, diagnosticHandler: { _ in }), url)
    }

    private func execute(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
}

struct SyncDiagnosticsReadTests {
    @Test func missingQueueMustNotLookEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-read-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try LocalStore(databaseURL: url)
        #expect(try store.syncQueueStatus().pendingCount == 0)
        #expect(try store.failedSyncEvents(limit: 5).isEmpty)
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        #expect(sqlite3_exec(db, "ALTER TABLE sync_queue RENAME TO hidden_queue", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try store.syncQueueStatus() }
        #expect(throws: (any Error).self) { try store.failedSyncEvents(limit: 5) }
        #expect(throws: (any Error).self) { try store.quarantinedSyncCount() }
        #expect(sqlite3_exec(db, "ALTER TABLE hidden_queue RENAME TO sync_queue", nil, nil, nil) == SQLITE_OK)
        #expect(try store.syncQueueStatus().pendingCount == 0)
    }
}


extension SyncDiagnosticsReadTests {
    @MainActor @Test func databaseBoundaryPropagatesFailureAndRetryRecovers() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-service-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try LocalStore(databaseURL: url)
        let service = DatabaseService(store: store)
        let owner = UUID()
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, "ALTER TABLE sync_queue RENAME TO hidden_queue", nil, nil, nil) == SQLITE_OK)
        await #expect(throws: (any Error).self) { try await service.syncQueueStatus(ownerUserId: owner) }
        await #expect(throws: (any Error).self) { try await service.failedSyncEvents(ownerUserId: owner) }
        await #expect(throws: (any Error).self) { try await service.quarantinedSyncCount() }
        try #require(sqlite3_exec(db, "ALTER TABLE hidden_queue RENAME TO sync_queue", nil, nil, nil) == SQLITE_OK)
        #expect(try await service.syncQueueStatus(ownerUserId: owner).unsyncedCount == 0)
    }

    @Test func corruptFailureRowRejectsWholeListAndPreservesRows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("queue-corrupt-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try LocalStore(databaseURL: url)
        let owner = UUID()
        let food = Product(name: "QA", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        try store.saveProduct(food, ownerUserId: owner)
        let event = try #require(store.fetchPendingEvents(ownerUserId: owner, limit: 1).first)
        store.markEventDeadLetter(event.eventId, error: "QA")
        #expect(try store.failedSyncEvents(ownerUserId: owner, limit: 5).count == 1)
        #expect(try store.failedSyncEvents(ownerUserId: UUID(), limit: 5).isEmpty)
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, "UPDATE sync_queue SET eventId = 'invalid'", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try store.failedSyncEvents(ownerUserId: owner, limit: 5) }
        try #require(sqlite3_exec(db, "UPDATE sync_queue SET eventId = '\(event.eventId.uuidString)'", nil, nil, nil) == SQLITE_OK)
        #expect(try store.failedSyncEvents(ownerUserId: owner, limit: 5).first?.id == event.eventId)
    }
}
