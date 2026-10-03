import Foundation
import SQLite3
import Testing
@testable import MatLogg

struct MealBatchStorageTests {
    @MainActor
    @Test func asynchronousStorageYieldsToUIAndCommitsBeforeReturning() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("async.sqlite"))
        let queue = DispatchQueue(label: "matlogg.test.io")
        let database = DatabaseService(store: store, ioQueue: queue)
        let owner = UUID()
        let logs = [makeLog(owner), makeLog(owner)]
        queue.suspend()
        var started = false
        let save = Task {
            started = true
            try await database.saveLogs(logs)
        }
        for _ in 0..<1_000 {
            if started { break }
            await Task.yield()
        }
        // MainActor can inspect state even while the database worker is paused.
        #expect(started)
        #expect(store.getAllLogs(userId: owner).isEmpty)
        queue.resume()
        try await save.value
        #expect(await database.getAllLogs(userId: owner).count == 2)
        #expect(await database.pendingSyncCount() == 2)
        #expect(store.fetchPendingEvents(limit: 10).allSatisfy { $0.type == "log.upsert" && $0.schemaVersion == 1 })
    }

    @MainActor
    @Test func asynchronousStoragePropagatesFailureAndRollsBackMeal() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("async-failure.sqlite")
        let store = try LocalStore(databaseURL: url)
        let database = DatabaseService(store: store)
        let owner = UUID()
        let logs = [makeLog(owner), makeLog(owner)]
        try installEventFailure(url, entityId: logs[1].id, type: "log.upsert")
        do {
            try await database.saveLogs(logs)
            Issue.record("Expected local save to fail")
        } catch {
            #expect(error is LocalStoreError)
        }
        #expect(await database.getAllLogs(userId: owner).isEmpty)
        #expect(await database.pendingSyncCount() == 0)
        try executeSQL("DROP TRIGGER fail_meal_event;", at: url)
        try await database.saveLogs(logs)
        #expect(await database.getAllLogs(userId: owner).count == 2)
        #expect(await database.pendingSyncCount() == 2)
    }

    @Test func savesMealAndUndoWithCanonicalEvents() throws {
        try withStore { store, _ in
            let userId = UUID()
            let logs = [makeLog(userId), makeLog(userId)]
            try store.saveLogs(logs)
            #expect(Set(store.getAllLogs(userId: userId).map(\.id)) == Set(logs.map(\.id)))
            let created = store.fetchPendingEvents(limit: 20)
            #expect(created.count == 2)
            #expect(created.allSatisfy { $0.type == "log.upsert" && $0.schemaVersion == 1 })
            #expect(Set(created.map(\.eventId)).count == 2)
            #expect(Set(created.compactMap(\.entityId)) == Set(logs.map { $0.id.uuidString }))
            let payload = try #require(JSONSerialization.jsonObject(with: created[0].payload) as? [String: Any])
            #expect(payload["unit"] as? String == "ml")

            try store.deleteLogs(logs.map(\.id))
            #expect(store.getAllLogs(userId: userId).isEmpty)
            let events = store.fetchPendingEvents(limit: 20)
            #expect(events.count == 4)
            #expect(events.filter { $0.type == "log.delete" && $0.schemaVersion == 1 }.count == 2)
            #expect(Set(created.map(\.eventId)).isSubset(of: Set(events.map(\.eventId))))
        }
    }

    @Test func secondSaveEventFailureRollsBackEntireMealAndCanRetry() throws {
        try withStore { store, url in
            let userId = UUID()
            let logs = [makeLog(userId), makeLog(userId)]
            try installEventFailure(url, entityId: logs[1].id, type: "log.upsert")
            #expect(throws: (any Error).self) { try store.saveLogs(logs) }
            #expect(store.getAllLogs(userId: userId).isEmpty)
            #expect(store.pendingSyncCount() == 0)

            try executeSQL("DROP TRIGGER fail_meal_event;", at: url)
            try store.saveLogs(logs)
            #expect(store.getAllLogs(userId: userId).count == 2)
            #expect(store.pendingSyncCount() == 2)
        }
    }

    @Test func secondDeleteEventFailureRestoresMealAndOriginalQueue() throws {
        try withStore { store, url in
            let userId = UUID()
            let logs = [makeLog(userId), makeLog(userId)]
            try store.saveLogs(logs)
            let originalEvents = Set(store.fetchPendingEvents(limit: 20).map(\.eventId))
            try installEventFailure(url, entityId: logs[1].id, type: "log.delete")
            #expect(throws: (any Error).self) { try store.deleteLogs(logs.map(\.id)) }
            #expect(Set(store.getAllLogs(userId: userId).map(\.id)) == Set(logs.map(\.id)))
            #expect(Set(store.fetchPendingEvents(limit: 20).map(\.eventId)) == originalEvents)

            try executeSQL("DROP TRIGGER fail_meal_event;", at: url)
            try store.deleteLogs(logs.map(\.id))
            #expect(store.getAllLogs(userId: userId).isEmpty)
            #expect(store.pendingSyncCount() == 4)
        }
    }

    @Test func emptyBatchesDoNotQueueEvents() throws {
        try withStore { store, _ in
            try store.saveLogs([])
            try store.deleteLogs([])
            #expect(store.pendingSyncCount() == 0)
        }
    }

    @Test func fractionalCaloriesSurviveLocalStorageSummaryAndSyncPayload() throws {
        try withStore { store, _ in
            let userId = UUID()
            let first = makeLog(userId, calories: 49.95)
            let second = makeLog(userId, calories: 49.95)

            try store.saveLogs([first, second])

            let stored = store.getAllLogs(userId: userId)
            #expect(stored.count == 2)
            #expect(stored.allSatisfy { abs($0.calories - 49.95) < 0.001 })
            let summary = store.getSummary(userId: userId, date: first.loggedDate)
            #expect(abs(summary.totalCalories - 99.9) < 0.001)
            let event = try #require(store.fetchPendingEvents(limit: 1).first)
            let payload = try #require(JSONSerialization.jsonObject(with: event.payload) as? [String: Any])
            #expect(abs((payload["kcal"] as? Double ?? 0) - 49.95) < 0.001)
        }
    }

    private func makeLog(_ userId: UUID, calories: Float = 210) -> FoodLog {
        FoodLog(userId: userId, productId: UUID(), mealType: "frokost", amountG: 60,
                amountUnit: .milliliters,
                loggedDate: Calendar.current.startOfDay(for: Date()), calories: calories,
                proteinG: 8, carbsG: 30, fatG: 6)
    }

    private func withStore(_ body: (LocalStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MealBatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        try body(try LocalStore(databaseURL: url), url)
    }

    private func installEventFailure(_ url: URL, entityId: UUID, type: String) throws {
        try executeSQL("""
            CREATE TRIGGER fail_meal_event BEFORE INSERT ON sync_queue
            WHEN NEW.entityId = '\(entityId.uuidString)' AND NEW.type = '\(type)'
            BEGIN SELECT RAISE(ABORT, 'Injected event failure'); END;
            """, at: url)
    }

    private func executeSQL(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        let opened = sqlite3_open(url.path, &db)
        defer { sqlite3_close(db) }
        #expect(opened == SQLITE_OK)
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        try #require(result == SQLITE_OK)
    }
}
