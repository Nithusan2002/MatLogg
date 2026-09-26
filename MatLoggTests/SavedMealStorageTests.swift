import Foundation
import SQLite3
import Testing
@testable import MatLogg

struct SavedMealStorageTests {
    @Test func migrationPersistsMealAndCanonicalEventsAcrossReopen() throws {
        try withStore { store, url in
            let userId = UUID()
            let meal = makeMeal(userId: userId)
            #expect(store.schemaVersion() == 2)
            try store.saveSavedMeal(meal)
            let event = try #require(store.fetchPendingEvents(limit: 10).first)
            #expect(event.type == "saved_meal.upsert")
            #expect(event.entityId == meal.id.uuidString)
            #expect(event.schemaVersion == 1)
            let payload = try #require(JSONSerialization.jsonObject(with: event.payload) as? [String: Any])
            let items = try #require(payload["items"] as? [[String: Any]])
            #expect(items.first?["amountUnit"] as? String == "ml")

            let reopened = LocalStore(databaseURL: url)
            #expect(reopened.getSavedMeals(userId: userId) == [meal])
            try reopened.deleteSavedMeal(meal.id, userId: userId)
            #expect(reopened.getSavedMeals(userId: userId).isEmpty)
            #expect(reopened.fetchPendingEvents(limit: 10).map(\.type) == ["saved_meal.upsert", "saved_meal.delete"])
        }
    }

    @Test func failedEventInsertRollsBackTemplateWrite() throws {
        try withStore { store, url in
            let meal = makeMeal(userId: UUID())
            try executeSQL("""
                CREATE TRIGGER fail_saved_meal_event BEFORE INSERT ON sync_queue
                WHEN NEW.type = 'saved_meal.upsert'
                BEGIN SELECT RAISE(ABORT, 'Injected event failure'); END;
                """, at: url)

            #expect(throws: (any Error).self) { try store.saveSavedMeal(meal) }
            #expect(store.getSavedMeals(userId: meal.userId).isEmpty)
            #expect(store.pendingSyncCount() == 0)
        }
    }

    private func makeMeal(userId: UUID) -> SavedMeal {
        SavedMeal(
            userId: userId, name: "Vanlig frokost", suggestedMealType: "frokost",
            items: [SavedMealItem(
                productId: UUID(), productName: "Havregryn", amountG: 80,
                amountUnit: .milliliters,
                calories: 300, proteinG: 10, carbsG: 50, fatG: 5,
                nutritionSource: .matvaretabellen, sortIndex: 0
            )]
        )
    }

    private func withStore(_ body: (LocalStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedMeal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        try body(LocalStore(databaseURL: url), url)
    }

    private func executeSQL(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        let opened = sqlite3_open(url.path, &db)
        defer { sqlite3_close(db) }
        #expect(opened == SQLITE_OK)
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
}
