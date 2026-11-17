import Foundation
import Testing
@testable import MatLogg

@MainActor
struct CloudLogBootstrapTests {
    @Test func stagedPagesResumeWithoutExposingPartialHistoryOrLosingLocalEdits() throws {
        let directory = try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let url = directory.appendingPathComponent("history.sqlite"), owner=UUID(), epoch=UUID()
        let store = try LocalStore(databaseURL:url)
        let changes = try (1...101).map { revision -> CloudLogChange in
            let value = try CloudLogSyncTests.aggregate(owner:owner)
            return CloudLogChange(entityId:value.log.id,revision:Int64(revision),deleted:false,payload:value)
        }
        let plan = CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:epoch,deviceId:UUID(),choice:.downloadOnly)
        try store.beginCloudLogBootstrap(plan)
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:plan.snapshotId,historyEpoch:epoch,upperCursor:101,totalCount:101),owner:owner)
        try store.stageCloudLogBootstrap(Self.page(plan:plan,offset:0,changes:Array(changes.prefix(100)),total:101,upper:101),owner:owner)
        #expect(store.getAllLogs(userId:owner).isEmpty)
        #expect(try store.cloudLogEpoch(owner:owner) == nil)
        let reopened = try LocalStore(databaseURL:url)
        #expect(try reopened.cloudLogBootstrapPlan(owner:owner)?.offset == 100)
        let id = try #require(changes.first?.entityId)
        try reopened.saveCloudLog(CloudLogSyncTests.aggregate(owner:owner,id:id,amount:777),owner:owner,device:UUID())
        try reopened.stageCloudLogBootstrap(Self.page(plan:plan,offset:100,changes:Array(changes.suffix(1)),total:101,upper:101),owner:owner)
        #expect(reopened.getAllLogs(userId:owner).count == 1)
        try reopened.finishCloudLogBootstrap(owner:owner)
        #expect(reopened.getAllLogs(userId:owner).count == 101)
        #expect(reopened.getAllLogs(userId:owner).first(where:{$0.id==id})?.amountG == 777)
        #expect(try reopened.cloudLogCursor(owner:owner) == 101)
        #expect(try reopened.cloudLogEpoch(owner:owner) == epoch)
        #expect(try reopened.cloudLogBootstrapPlan(owner:owner) == nil)
        let recovery = try reopened.cloudLogRecovery(owner:owner)
        #expect(recovery.count == 1 && recovery.first?.local?.log.amountG == 777)
        #expect(recovery.first?.mutations.count == 1)
        #expect(try reopened.nextCloudLogMutation(owner:owner) == nil)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
    }

    @Test func explicitHistoryUsesCurrentSnapshotInsteadOfReplayingV1Queue() throws {
        let directory=try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try LocalStore(databaseURL:directory.appendingPathComponent("history.sqlite")), owner=UUID(), epoch=UUID()
        let local=try CloudLogSyncTests.aggregate(owner:owner,amount:321)
        try store.saveProduct(local.product,ownerUserId:owner)
        try store.saveLog(local.log)
        let oldIDs=store.fetchPendingEvents(ownerUserId:owner,limit:50).map(\.eventId)
        let server=try CloudLogSyncTests.aggregate(owner:owner,id:local.log.id,amount:123)
        let plan=CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:epoch,deviceId:UUID(),choice:.includeLocalHistory)
        try store.beginCloudLogBootstrap(plan)
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:plan.snapshotId,historyEpoch:epoch,upperCursor:1,totalCount:1),owner:owner)
        try store.stageCloudLogBootstrap(Self.page(plan:plan,offset:0,changes:[CloudLogChange(entityId:local.log.id,revision:1,deleted:false,payload:server)],total:1,upper:1),owner:owner)
        try store.finishCloudLogBootstrap(owner:owner)
        let event=try #require(try store.nextCloudLogMutation(owner:owner))
        #expect(!oldIDs.contains(event.eventId))
        #expect(event.baseRevision == 0 && event.historyEpoch == epoch && event.payload?.log.amountG == 321)
        #expect(store.getAllLogs(userId:owner).first?.amountG == 321)
        #expect(store.fetchPendingEvents(ownerUserId:owner,limit:50).map(\.eventId) == oldIDs)
    }

    @Test func newEpochPreservesOriginalQueueAndDoesNotReplayIt() throws {
        let directory=try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try LocalStore(databaseURL:directory.appendingPathComponent("history.sqlite")), owner=UUID(), oldEpoch=UUID(), newEpoch=UUID()
        try CloudLogSyncTests.installEmptyHistory(store:store,owner:owner,epoch:oldEpoch)
        let local=try CloudLogSyncTests.aggregate(owner:owner,amount:456)
        try store.saveCloudLog(local,owner:owner,device:UUID())
        let frozen=try #require(try store.nextCloudLogMutation(owner:owner))
        let plan=CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:newEpoch,deviceId:UUID(),choice:.downloadOnly)
        try store.beginCloudLogBootstrap(plan)
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:plan.snapshotId,historyEpoch:newEpoch,upperCursor:0,totalCount:0),owner:owner)
        try store.finishCloudLogBootstrap(owner:owner)
        let recovery=try #require(try store.cloudLogRecovery(owner:owner).first)
        #expect(recovery.mutations.first?.eventId == frozen.eventId)
        #expect(recovery.mutations.first?.historyEpoch == oldEpoch)
        #expect(recovery.local?.log.amountG == 456)
        #expect(try store.nextCloudLogMutation(owner:owner) == nil)
        #expect(store.getAllLogs(userId:owner).first?.amountG == 456)
        #expect(try store.cloudLogEpoch(owner:owner) == newEpoch)
        #expect(throws:CloudLogError.historyReviewRequired) { try store.saveCloudLog(local,owner:owner,device:UUID()) }
        #expect(throws:CloudLogError.historyReviewRequired) { try store.deleteCloudLog(id:local.log.id,owner:owner,device:UUID()) }
    }

    @Test func malformedPageAndCancellationLeaveDomainAndSessionConsistent() throws {
        let directory=try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try LocalStore(databaseURL:directory.appendingPathComponent("history.sqlite")), owner=UUID(), epoch=UUID()
        let plan=CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:epoch,deviceId:UUID(),choice:.downloadOnly)
        try store.beginCloudLogBootstrap(plan)
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:plan.snapshotId,historyEpoch:epoch,upperCursor:2,totalCount:2),owner:owner)
        let good=try CloudLogSyncTests.aggregate(owner:owner)
        let bad=try CloudLogSyncTests.aggregate(owner:UUID())
        let page=Self.page(plan:plan,offset:0,changes:[CloudLogChange(entityId:good.log.id,revision:1,deleted:false,payload:good),CloudLogChange(entityId:bad.log.id,revision:2,deleted:false,payload:bad)],total:2,upper:2)
        #expect(throws:(any Error).self) { try store.stageCloudLogBootstrap(page,owner:owner) }
        #expect(try store.cloudLogBootstrapPlan(owner:owner)?.offset == 0)
        #expect(store.getAllLogs(userId:owner).isEmpty)
        #expect(throws:(any Error).self) { try store.finishCloudLogBootstrap(owner:owner) }
        try store.cancelCloudLogBootstrap(owner:owner)
        #expect(try store.cloudLogBootstrapPlan(owner:owner) == nil)
        #expect(try store.cloudLogCursor(owner:owner) == 0)
    }

    @Test func historyCanBeIncludedLaterWithoutGuessingLegacyNutrition() throws {
        let directory=try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try LocalStore(databaseURL:directory.appendingPathComponent("history.sqlite")), owner=UUID(), epoch=UUID()
        let value=try CloudLogSyncTests.aggregate(owner:owner)
        var raw=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(value.log)) as? [String:Any])
        raw.removeValue(forKey:"amountUnit"); raw.removeValue(forKey:"nutritionSource")
        let legacy=try JSONDecoder().decode(FoodLog.self,from:JSONSerialization.data(withJSONObject:raw))
        try store.saveProduct(value.product,ownerUserId:owner)
        try store.saveLog(legacy)
        for choice in [CloudLogHistoryChoice.downloadOnly,.includeLocalHistory] {
            let plan=CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:epoch,deviceId:UUID(),choice:choice)
            try store.beginCloudLogBootstrap(plan)
            try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:plan.snapshotId,historyEpoch:epoch,upperCursor:0,totalCount:0),owner:owner)
            try store.finishCloudLogBootstrap(owner:owner)
            if choice == .downloadOnly {
                #expect(try store.nextCloudLogMutation(owner:owner) == nil)
                #expect(try store.cloudLogRecovery(owner:owner).count == 1)
            }
        }
        let event=try #require(try store.nextCloudLogMutation(owner:owner))
        #expect(event.payload?.log.amountUnit == .grams)
        #expect(event.payload?.log.nutritionSource == nil)
        #expect(try store.cloudLogRecovery(owner:owner).isEmpty)
        #expect(store.syncQueueStatus().unsyncedCount == 2)
    }

    @Test func changedHistoryChoiceCannotSilentlyResumePriorUploadChoice() async throws {
        let directory=try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try LocalStore(databaseURL:directory.appendingPathComponent("history.sqlite")), owner=UUID(), epoch=UUID()
        let plan=CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:epoch,deviceId:UUID(),choice:.includeLocalHistory)
        try store.beginCloudLogBootstrap(plan)
        let sync=CloudLogSyncCoordinator(store:store,transport:HistoryHeadOnly(owner:owner,epoch:epoch))
        await sync.setOwner(owner)
        await #expect(throws:CloudLogError.historyChoiceMismatch) {
            try await sync.transferHistory(owner:owner,choice:.downloadOnly,device:UUID(),allowed:true)
        }
        #expect(try store.cloudLogBootstrapPlan(owner:owner)?.choice == .includeLocalHistory)
    }

    @Test func unsentDeletionIsRetainedInsteadOfAppliedToRestoredServer() throws {
        let directory=try Self.directory()
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=try LocalStore(databaseURL:directory.appendingPathComponent("history.sqlite")), owner=UUID(), oldEpoch=UUID(), newEpoch=UUID()
        try CloudLogSyncTests.installEmptyHistory(store:store,owner:owner,epoch:oldEpoch)
        let value=try CloudLogSyncTests.aggregate(owner:owner)
        try store.applyCloudLogPage(CloudLogPage(owner:owner,changes:[CloudLogChange(entityId:value.log.id,revision:1,deleted:false,payload:value)],cursor:1,historyEpoch:oldEpoch),after:0,owner:owner)
        try store.deleteCloudLog(id:value.log.id,owner:owner,device:UUID())
        let original=try #require(try store.nextCloudLogMutation(owner:owner))
        let plan=CloudLogBootstrapPlan(owner:owner,snapshotId:UUID(),historyEpoch:newEpoch,deviceId:UUID(),choice:.downloadOnly)
        try store.beginCloudLogBootstrap(plan)
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:plan.snapshotId,historyEpoch:newEpoch,upperCursor:1,totalCount:1),owner:owner)
        try store.stageCloudLogBootstrap(Self.page(plan:plan,offset:0,changes:[CloudLogChange(entityId:value.log.id,revision:1,deleted:false,payload:value)],total:1,upper:1),owner:owner)
        try store.finishCloudLogBootstrap(owner:owner)
        let recovery=try #require(try store.cloudLogRecovery(owner:owner).first)
        #expect(recovery.mutations.first?.eventId == original.eventId && recovery.mutations.first?.type == "log.delete")
        #expect(recovery.server?.payload?.log.id == value.log.id)
        #expect(try store.nextCloudLogMutation(owner:owner) == nil)
    }

    static func directory() throws -> URL {
        let value=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:value,withIntermediateDirectories:true)
        return value
    }
    static func page(plan:CloudLogBootstrapPlan,offset:Int,changes:[CloudLogChange],total:Int,upper:Int64) -> CloudLogBootstrapPage {
        CloudLogBootstrapPage(owner:plan.owner,snapshotId:plan.snapshotId,historyEpoch:plan.historyEpoch,upperCursor:upper,totalCount:total,offset:offset,changes:changes,complete:offset+changes.count==total)
    }
}

nonisolated private struct HistoryHeadOnly: CloudLogTransport {
    let owner:UUID
    let epoch:UUID
    func head(owner:UUID) async throws -> CloudLogHead { CloudLogHead(owner:self.owner,historyEpoch:epoch,cursor:0) }
    func push(_ mutation:CloudLogMutation,owner:UUID) async throws -> CloudLogReceipt { throw CloudLogError.invalidData }
    func pull(after cursor:Int64,epoch:UUID,owner:UUID) async throws -> CloudLogPage { throw CloudLogError.invalidData }
    func beginBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapManifest { throw CloudLogError.invalidData }
    func readBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapPage { throw CloudLogError.invalidData }
}
