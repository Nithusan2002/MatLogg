import Foundation
import Testing
@testable import MatLogg

@MainActor
struct CloudLogReviewTests {
    @Test func previouslyDownloadedProductSnapshotSurvivesLossFromRestoredServer() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let downloaded = try CloudLogSyncTests.aggregate(owner: owner, amount: 321)
        try store.applyCloudLogPage(CloudLogPage(owner: owner, changes: [CloudLogChange(entityId: downloaded.log.id, revision: 1, deleted: false, payload: downloaded)], cursor: 1, historyEpoch: epoch), after: 0, owner: owner)
        // A remote product exists only in the aggregate, not the mutable catalog.
        try CloudLogSyncTests.installEmptyHistory(store: store, owner: owner, epoch: UUID())
        let review = try #require(try store.cloudLogReviews(owner: owner).first)
        #expect(review.local?.log.amountG == 321 && review.local?.product.id == downloaded.product.id)
        try store.resolveCloudLog(review, choice: .useLocal, owner: owner, device: UUID())
        #expect(try store.nextCloudLogMutation(owner: owner)?.payload?.product.id == downloaded.product.id)
    }
    private func setup() throws -> (LocalStore, URL, UUID, UUID) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("review.sqlite"))
        let owner = UUID(), epoch = UUID()
        try CloudLogSyncTests.installEmptyHistory(store: store, owner: owner, epoch: epoch)
        return (store, directory, owner, epoch)
    }
    private func conflict(_ store: LocalStore, owner: UUID, epoch: UUID, deleted: Bool = false) throws -> CloudLogReview {
        let local = try CloudLogSyncTests.aggregate(owner: owner, amount: 123)
        try store.saveCloudLog(local, owner: owner, device: UUID())
        let mutation = try #require(try store.nextCloudLogMutation(owner: owner))
        // A later edit must be included in the eventual user decision.
        try store.saveCloudLog(CloudLogSyncTests.aggregate(owner: owner, id: local.log.id, amount: 456), owner: owner, device: UUID())
        let remote = deleted ? nil : try CloudLogSyncTests.aggregate(owner: owner, id: local.log.id, amount: 789)
        try store.applyCloudLogReceipt(CloudLogReceipt(eventId: mutation.eventId, status: "conflict", change: CloudLogChange(entityId: local.log.id, revision: 1, deleted: deleted, payload: remote), historyEpoch: epoch), mutation: mutation, owner: owner)
        return try #require(try store.cloudLogReviews(owner: owner).first)
    }
    @Test func localChoiceUsesLatestEditAndFreshEventAgainstReviewedRevision() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let review = try conflict(store, owner: owner, epoch: epoch)
        #expect(review.local?.log.amountG == 456)
        try store.resolveCloudLog(review, choice: .useLocal, owner: owner, device: UUID())
        let event = try #require(try store.nextCloudLogMutation(owner: owner))
        #expect(event.baseRevision == 1 && event.historyEpoch == epoch)
        #expect(event.payload?.log.amountG == 456)
        #expect(!review.mutations.contains { $0.eventId == event.eventId })
        #expect(try store.cloudLogReviews(owner: owner).isEmpty)
        #expect(throws: CloudLogError.historyReviewRequired) { try store.resolveCloudLog(review, choice: .useCloud, owner: owner, device: UUID()) }
        #expect(try store.nextCloudLogMutation(owner: owner)?.eventId == event.eventId)
    }
    @Test func staleConfirmationCannotDiscardNewLocalOrRemoteChanges() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let review = try conflict(store, owner: owner, epoch: epoch)
        try store.saveCloudLog(CloudLogSyncTests.aggregate(owner: owner, id: review.id, amount: 999), owner: owner, device: UUID())
        #expect(throws: CloudLogError.historyReviewRequired) { try store.resolveCloudLog(review, choice: .useCloud, owner: owner, device: UUID()) }
        let refreshed = try #require(try store.cloudLogReviews(owner: owner).first)
        let remote = CloudLogChange(entityId: review.id, revision: 2, deleted: true, payload: nil)
        try store.applyCloudLogPage(CloudLogPage(owner: owner, changes: [remote], cursor: 2, historyEpoch: epoch), after: 0, owner: owner)
        #expect(throws: CloudLogError.historyReviewRequired) { try store.resolveCloudLog(refreshed, choice: .useLocal, owner: owner, device: UUID()) }
        #expect(try store.cloudLogReviews(owner: owner).count == 1)
    }
    @Test func tombstoneCreatesSeparateLogAndCloudChoiceRetainsDeletion() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let review = try conflict(store, owner: owner, epoch: epoch, deleted: true)
        let newID = try store.resolveCloudLog(review, choice: .useLocal, owner: owner, device: UUID())
        #expect(newID != review.id)
        #expect(store.getAllLogs(userId: owner).map(\.id) == [newID])
        let pending = try #require(try store.nextCloudLogMutation(owner: owner))
        #expect(pending.entityId == newID && pending.baseRevision == 0 && pending.payload?.log.amountG == 456)
        try store.applyCloudLogReceipt(CloudLogReceipt(eventId: pending.eventId, status: "applied", change: CloudLogChange(entityId: newID, revision: 2, deleted: false, payload: pending.payload), historyEpoch: epoch), mutation: pending, owner: owner)
        let other = try conflict(store, owner: owner, epoch: epoch, deleted: true)
        try store.resolveCloudLog(other, choice: .useCloud, owner: owner, device: UUID())
        #expect(!store.getAllLogs(userId: owner).contains { $0.id == other.id })
        #expect(try store.cloudLogReviews(owner: owner).isEmpty)
    }
    @Test func cloudChoiceForMissingHistoryRemovesOnlyExplicitlyReviewedLocalLog() throws {
        let (store, directory, owner, _) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let value = try CloudLogSyncTests.aggregate(owner: owner)
        try store.saveCloudLog(value, owner: owner, device: UUID())
        try CloudLogSyncTests.installEmptyHistory(store: store, owner: owner, epoch: UUID())
        let review = try #require(try store.cloudLogReviews(owner: owner).first)
        #expect(review.server == nil && review.local != nil)
        try store.resolveCloudLog(review, choice: .useCloud, owner: owner, device: UUID())
        #expect(store.getAllLogs(userId: owner).isEmpty)
        #expect(try store.nextCloudLogMutation(owner: owner) == nil)
        #expect(try store.cloudLogReviews(owner: owner).isEmpty)
    }
    @Test func cloudChoiceDiscardsOnlyChosenOwnersResource() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let review = try conflict(store, owner: owner, epoch: epoch)
        let independent = try CloudLogSyncTests.aggregate(owner: owner)
        try store.saveCloudLog(independent, owner: owner, device: UUID())
        #expect(throws: (any Error).self) { try store.resolveCloudLog(review, choice: .useCloud, owner: UUID(), device: UUID()) }
        try store.resolveCloudLog(review, choice: .useCloud, owner: owner, device: UUID())
        #expect(store.getAllLogs(userId: owner).first { $0.id == review.id }?.amountG == 789)
        #expect(try store.nextCloudLogMutation(owner: owner)?.entityId == independent.log.id)
    }
    @Test func ordinaryLocalWriterAlsoInvalidatesAnOpenConfirmation() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let review = try conflict(store, owner: owner, epoch: epoch)
        let changed = try CloudLogSyncTests.aggregate(owner: owner, id: review.id, amount: 987)
        try store.saveProduct(changed.product, ownerUserId: owner)
        try store.saveLog(changed.log)
        #expect(throws: CloudLogError.historyReviewRequired) { try store.resolveCloudLog(review, choice: .useCloud, owner: owner, device: UUID()) }
        #expect(store.getAllLogs(userId: owner).first?.amountG == 987)
        #expect(try store.cloudLogReviews(owner: owner).first?.local?.log.amountG == 987)
    }
    @Test func recoveredOldEpochRequiresFreshConfirmationAndEvent() throws {
        let (store, directory, owner, epoch) = try setup()
        defer { try? FileManager.default.removeItem(at: directory) }
        let review = try conflict(store, owner: owner, epoch: epoch)
        try CloudLogSyncTests.installEmptyHistory(store: store, owner: owner, epoch: UUID())
        #expect(throws: CloudLogError.historyReviewRequired) { try store.resolveCloudLog(review, choice: .useLocal, owner: owner, device: UUID()) }
        let recovered = try #require(try store.cloudLogReviews(owner: owner).first)
        try store.resolveCloudLog(recovered, choice: .useLocal, owner: owner, device: UUID())
        let next = try #require(try store.nextCloudLogMutation(owner: owner))
        #expect(next.historyEpoch == recovered.epoch && next.historyEpoch != epoch && next.baseRevision == 0)
        #expect(next.payload?.log.amountG == 456)
    }
}
