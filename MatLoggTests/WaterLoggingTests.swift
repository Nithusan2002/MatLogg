import Foundation
import SQLite3
import Testing
@testable import MatLogg

struct WaterLoggingTests {
    @Test func persistsCanonicalEventsAndOwnerIsolation() throws {
        try withStore { store, url in
            let owner = UUID()
            let other = UUID()
            let glass = WaterGlass(userId: owner, date: Date())
            try store.saveWaterGlass(glass)
            let reopened = try LocalStore(databaseURL: url)
            #expect(try reopened.getWaterGlasses(userId: owner) == [glass])
            #expect(try reopened.getWaterGlasses(userId: other).isEmpty)
            #expect(reopened.localDataSummary(ownerId: owner).waterGlasses == 1)
            #expect(throws: (any Error).self) { try reopened.deleteWaterGlass(glass.id, userId: other) }
            let event = try #require(reopened.fetchPendingEvents(limit: 10).first)
            #expect(event.type == "water.upsert")
            #expect(event.schemaVersion == 1)
            #expect(event.entityId == glass.id.uuidString)
            try reopened.deleteWaterGlass(glass.id, userId: owner)
            #expect(try reopened.getWaterGlasses(userId: owner).isEmpty)
            #expect(reopened.fetchPendingEvents(limit: 10).map(\.type) == ["water.upsert", "water.delete"])
        }
    }

    @Test func eventFailureRollsBackGlass() throws {
        try withStore { store, url in
            let glass = WaterGlass(userId: UUID(), date: Date())
            try executeSQL("CREATE TRIGGER fail_water BEFORE INSERT ON sync_queue WHEN NEW.type = 'water.upsert' BEGIN SELECT RAISE(ABORT, 'Injected failure'); END;", at: url)
            #expect(throws: (any Error).self) { try store.saveWaterGlass(glass) }
            #expect(try store.getWaterGlasses(userId: glass.userId).isEmpty)
            #expect(store.pendingSyncCount() == 0)
        }
    }

    @Test func claimAndDeleteIncludeWater() throws {
        try withStore { store, _ in
            let local = UUID()
            let account = UUID()
            try store.saveWaterGlass(WaterGlass(userId: local, date: Date()))
            try store.claimLocalData(from: local, to: account)
            #expect(try store.getWaterGlasses(userId: local).isEmpty)
            #expect(try store.getWaterGlasses(userId: account).first?.userId == account)
            #expect(store.fetchPendingEvents(limit: 10).first?.ownerUserId == account)
            try store.deleteLocalData(ownerId: account)
            #expect(try store.getWaterGlasses(userId: account).isEmpty)
            #expect(store.pendingSyncCount() == 0)
        }
    }

    @Test @MainActor func dayChangesAndUndo() async throws {
        try await withAsyncStore { store in
            let repository = DatabaseService(store: store)
            let vm = WaterViewModel(repository: repository)
            let owner = UUID()
            let today = Date()
            let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
            await vm.load(userId: owner, date: today)
            await vm.add()
            await vm.add()
            #expect(vm.glasses.count == 2)
            await vm.remove(undo: true)
            #expect(vm.glasses.count == 1)
            await vm.load(userId: owner, date: yesterday)
            #expect(vm.glasses.isEmpty)
            await vm.add()
            await vm.load(userId: owner, date: today)
            #expect(vm.glasses.count == 1)
            await vm.load(userId: UUID(), date: today)
            #expect(vm.glasses.isEmpty)
        }
    }

    @Test @MainActor func failedWriteDoesNotIncrement() async throws {
        try await withAsyncStore { store in
            let vm = WaterViewModel(repository: FailingWaterRepository())
            await vm.load(userId: UUID(), date: Date())
            await vm.add()
            #expect(vm.glasses.isEmpty)
            #expect(vm.errorMessage != nil)
            #expect(!vm.isBusy)
            _ = store
        }
    }

    @MainActor private func withAsyncStore(_ body: (LocalStore) async throws -> Void) async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Water-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        try await body(LocalStore(databaseURL: url))
    }

    private func withStore(_ body: (LocalStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Water-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        try body(try LocalStore(databaseURL: url), url)
    }

    private func executeSQL(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        let opened = sqlite3_open(url.path, &db)
        defer { sqlite3_close(db) }
        #expect(opened == SQLITE_OK)
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
}

private struct FailingWaterRepository: WaterRepository {
    func getWaterGlasses(userId: UUID) async throws -> [WaterGlass] { [] }
    func saveWaterGlass(_ glass: WaterGlass) async throws { throw DatabaseServiceError.unavailable }
    func deleteWaterGlass(_ id: UUID, userId: UUID) async throws { throw DatabaseServiceError.unavailable }
}
