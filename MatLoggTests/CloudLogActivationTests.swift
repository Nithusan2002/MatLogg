import Foundation
import Testing
@testable import MatLogg

@MainActor
struct CloudLogActivationTests {
    @Test func undoOfSyncedDeletionRetainsPrivateProductAndUsesNewIdentity() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let value = try CloudLogSyncTests.aggregate(owner: owner)
        try store.applyCloudLogPage(CloudLogPage(owner: owner, changes: [CloudLogChange(entityId: value.log.id, revision: 1, deleted: false, payload: value)], cursor: 1, historyEpoch: epoch), after: 0, owner: owner)
        try store.deleteLog(value.log.id)
        let deletion = try #require(try store.nextCloudLogMutation(owner: owner))
        try store.applyCloudLogReceipt(CloudLogReceipt(eventId: deletion.eventId, status: "applied", change: CloudLogChange(entityId: value.log.id, revision: 2, deleted: true, payload: nil), historyEpoch: epoch), mutation: deletion, owner: owner)
        // LogViewModel's existing undo creates a fresh log ID with the original product ID.
        let restored = try value.copiedLog(id: UUID())
        try store.saveLog(restored.log)
        let event = try #require(try store.nextCloudLogMutation(owner: owner))
        #expect(event.entityId != value.log.id && event.entityId == restored.log.id && event.baseRevision == 0)
        #expect(event.payload?.product.id == value.product.id)
        #expect(store.getAllLogs(userId: owner).map(\.id) == [restored.log.id])
        store.selectCloudLogReadOwner(owner)
        #expect(store.getProduct(value.product.id)?.name == value.product.name)
        store.selectCloudLogReadOwner(UUID())
        #expect(store.getProduct(value.product.id) == nil)
    }
    private func setup() throws -> (LocalStore, URL, UUID, UUID) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("activation.sqlite"))
        let owner = UUID(), epoch = UUID()
        store.configureCloudLogRouting(allowed: true)
        try CloudLogSyncTests.installEmptyHistory(store: store, owner: owner, epoch: epoch)
        try store.setCloudLogEnabled(true, owner: owner, device: UUID())
        return (store, directory, owner, epoch)
    }
    @Test func ordinaryCreateEditDeleteUseOnlyAtomicV2AndReplaySurvivesRestart() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let value = try CloudLogSyncTests.aggregate(owner: owner)
        try store.saveProduct(value.product, ownerUserId: owner)
        let baseline = store.fetchPendingEvents(ownerUserId: owner, limit: 100).map(\.eventId)
        try store.saveLog(value.log)
        let first = try #require(try store.nextCloudLogMutation(owner: owner))
        let edited = try CloudLogSyncTests.aggregate(owner: owner, id: value.log.id, amount: 222)
        try store.saveProduct(edited.product, ownerUserId: owner)
        try store.saveLog(edited.log)
        try store.deleteLog(value.log.id)
        #expect(store.getAllLogs(userId: owner).isEmpty)
        #expect(store.fetchPendingEvents(ownerUserId: owner, limit: 100).filter { $0.type == "log.upsert" || $0.type == "log.delete" }.isEmpty)
        #expect(!baseline.isEmpty)
        let reopened = try LocalStore(databaseURL: directory.appendingPathComponent("activation.sqlite"))
        reopened.configureCloudLogRouting(allowed: true)
        #expect(try reopened.cloudLogConnection(owner: owner)?.enabled == true)
        #expect(try reopened.nextCloudLogMutation(owner: owner)?.eventId == first.eventId)
        var revisions: Int64 = 0
        var amounts: [Float] = []
        while let event = try reopened.nextCloudLogMutation(owner: owner) {
            revisions += 1
            if let amount = event.payload?.log.amountG { amounts.append(amount) }
            try reopened.applyCloudLogReceipt(CloudLogReceipt(eventId: event.eventId, status: "applied", change: CloudLogChange(entityId: event.entityId, revision: revisions, deleted: event.payload == nil, payload: event.payload), historyEpoch: epoch), mutation: event, owner: owner)
        }
        #expect(revisions == 3 && amounts == [125, 222])
        #expect(reopened.getAllLogs(userId: owner).isEmpty)
    }
    @Test func disabledLocalChangesRemainEditableAndDeletionRequiresReviewOnReactivation() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let value = try CloudLogSyncTests.aggregate(owner: owner)
        try store.saveProduct(value.product, ownerUserId: owner)
        try store.saveLog(value.log)
        try store.setCloudLogEnabled(false, owner: owner, device: UUID())
        let edited = try CloudLogSyncTests.aggregate(owner: owner, id: value.log.id, amount: 333)
        try store.saveProduct(edited.product, ownerUserId: owner)
        try store.saveLog(edited.log)
        try store.deleteLog(value.log.id)
        #expect(try store.nextCloudLogMutation(owner: owner) == nil)
        let snapshot = CloudLogBootstrapPlan(owner: owner, snapshotId: UUID(), historyEpoch: epoch, deviceId: UUID(), choice: .downloadOnly)
        try store.beginCloudLogBootstrap(snapshot)
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner: owner, snapshotId: snapshot.snapshotId, historyEpoch: epoch, upperCursor: 1, totalCount: 1), owner: owner)
        try store.stageCloudLogBootstrap(CloudLogBootstrapPage(owner: owner, snapshotId: snapshot.snapshotId, historyEpoch: epoch, upperCursor: 1, totalCount: 1, offset: 0, changes: [CloudLogChange(entityId: value.log.id, revision: 1, deleted: false, payload: value)], complete: true), owner: owner)
        try store.finishCloudLogBootstrap(owner: owner)
        try store.setCloudLogEnabled(true, owner: owner, device: UUID())
        #expect(store.getAllLogs(userId: owner).isEmpty)
        let review = try #require(try store.cloudLogReviews(owner: owner).first)
        #expect(review.local == nil && review.server?.payload != nil)
        #expect(try store.nextCloudLogMutation(owner: owner) == nil)
        try store.resolveCloudLog(review, choice: .useLocal, owner: owner, device: UUID())
        #expect(try store.nextCloudLogMutation(owner: owner)?.type == "log.delete")
    }
    @Test func failedBatchRollsBackLogsAndOutboxAndOtherAccountsStayLocal() throws {
        let (store, directory, owner, _) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let good = try CloudLogSyncTests.aggregate(owner: owner)
        try store.saveProduct(good.product, ownerUserId: owner)
        let missing = try CloudLogSyncTests.aggregate(owner: owner)
        #expect(throws: CloudLogError.invalidData) { try store.saveLogs([good.log, missing.log]) }
        #expect(store.getAllLogs(userId: owner).isEmpty)
        #expect(try store.nextCloudLogMutation(owner: owner) == nil)
        let other = try CloudLogSyncTests.aggregate(owner: UUID())
        try store.saveLog(other.log)
        #expect(try store.nextCloudLogMutation(owner: other.log.userId) == nil)
        #expect(store.fetchPendingEvents(ownerUserId: other.log.userId, limit: 10).count == 1)
    }
    @Test func releaseGateIgnoresPersistedEnabledChoice() throws {
        let (store, directory, owner, _) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        store.configureCloudLogRouting(allowed: false)
        let value = try CloudLogSyncTests.aggregate(owner: owner)
        try store.saveLog(value.log)
        #expect(try store.nextCloudLogMutation(owner: owner) == nil)
        #expect(store.fetchPendingEvents(ownerUserId: owner, limit: 10).count == 1)
        #expect(throws: CloudLogError.disabled) { try store.setCloudLogEnabled(true, owner: owner, device: UUID()) }
    }
    @Test func downloadedProductIsVisibleOnlyForSelectedAccountWithoutCatalogMutation() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let value = try CloudLogSyncTests.aggregate(owner: owner)
        try store.applyCloudLogPage(CloudLogPage(owner: owner, changes: [CloudLogChange(entityId: value.log.id, revision: 1, deleted: false, payload: value)], cursor: 1, historyEpoch: epoch), after: 0, owner: owner)
        #expect(store.getProduct(value.product.id) == nil)
        store.selectCloudLogReadOwner(owner)
        #expect(store.getProduct(value.product.id)?.name == value.product.name)
        #expect(store.getProducts([value.product.id])[value.product.id]?.id == value.product.id)
        store.selectCloudLogReadOwner(UUID())
        #expect(store.getProduct(value.product.id) == nil)
        store.selectCloudLogReadOwner(nil)
        #expect(store.getProducts([value.product.id]).isEmpty)
    }
}
