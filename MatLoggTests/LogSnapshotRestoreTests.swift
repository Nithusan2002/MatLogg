import Foundation
import Testing
@testable import MatLogg

@MainActor
struct LogSnapshotRestoreTests {
    @Test func restorePersistsWithoutEchoAndRejectsOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("restore.sqlite")
        let store = try LocalStore(databaseURL: url)
        let owner = UUID()
        let log = Self.log(owner: owner)
        try store.restoreLogSnapshotForTesting(log, authenticatedOwner: owner)
        try store.restoreLogSnapshotForTesting(log, authenticatedOwner: owner)
        let reopened = try LocalStore(databaseURL: url)
        let recovered = try #require(reopened.getAllLogs(userId: owner).first)
        #expect(reopened.getAllLogs(userId: owner).count == 1)
        #expect(recovered.id == log.id && recovered.loggedDate == log.loggedDate)
        #expect(recovered.loggedTime == log.loggedTime && recovered.createdAt == log.createdAt)
        #expect(recovered.nutritionSource == log.nutritionSource)
        #expect(recovered.resolvedAmountUnit == .milliliters && recovered.calories == 123.75)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
        #expect(throws: (any Error).self) {
            try reopened.restoreLogSnapshotForTesting(Self.log(owner: owner, id: log.id, amount: 99), authenticatedOwner: owner)
        }
        #expect(reopened.getAllLogs(userId: owner).first?.amountG == log.amountG)
    }

    @Test func wrongOwnerAndInvalidAmountDoNotWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("restore.sqlite"))
        let owner = UUID()
        #expect(throws: (any Error).self) { try store.restoreLogSnapshotForTesting(Self.log(owner: owner), authenticatedOwner: UUID()) }
        #expect(throws: (any Error).self) { try store.restoreLogSnapshotForTesting(Self.log(owner: owner, amount: -1), authenticatedOwner: owner) }
        #expect(store.getAllLogs(userId: owner).isEmpty)
        #expect(store.syncQueueStatus().unsyncedCount == 0)
    }

    static func log(owner: UUID, id: UUID = UUID(), amount: Float = 125) -> FoodLog {
        FoodLog(id: id, userId: owner, productId: UUID(), mealType: "lunsj", amountG: amount,
                amountUnit: .milliliters, nutritionPreparation: .asSold, nutritionSource: .user,
                loggedDate: Date(timeIntervalSince1970: 1_700_000_000),
                loggedTime: Date(timeIntervalSince1970: 1_700_000_123),
                calories: 123.75, proteinG: 10.5, carbsG: 12.25, fatG: 2.125,
                createdAt: Date(timeIntervalSince1970: 1_700_000_456))
    }
}
