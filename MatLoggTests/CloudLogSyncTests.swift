import Foundation
import Testing
@testable import MatLogg

@MainActor
struct CloudLogSyncTests {
    @Test func localWritesFreezeEventsAndSurviveRestart() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("v2.sqlite"), owner = UUID(), device = UUID(), id = UUID()
        let store = try LocalStore(databaseURL: url)
        let epoch = UUID()
        try Self.installEmptyHistory(store:store,owner:owner,epoch:epoch)
        let one = try Self.aggregate(owner: owner, id: id, amount: 100)
        try store.saveCloudLog(one, owner: owner, device: device)
        let event = try #require(try store.nextCloudLogMutation(owner: owner))
        try store.saveCloudLog(Self.aggregate(owner: owner, id: id, amount: 200), owner: owner, device: device)
        let reopened = try LocalStore(databaseURL: url)
        let replay = try #require(try reopened.nextCloudLogMutation(owner: owner))
        #expect(replay.eventId == event.eventId && replay.baseRevision == 0)
        #expect(replay.payload?.log.amountG == 100)
        #expect(reopened.getAllLogs(userId: owner).first?.amountG == 200)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
        try reopened.applyCloudLogReceipt(CloudLogReceipt(eventId: event.eventId, status: "applied", change: CloudLogChange(entityId: id, revision: 1, deleted: false, payload: one), historyEpoch:epoch), mutation: event, owner: owner)
        #expect(reopened.getAllLogs(userId: owner).first?.amountG == 200)
        let remote = try Self.aggregate(owner:owner,id:id,amount:333)
        try reopened.applyCloudLogPage(CloudLogPage(owner:owner,changes:[CloudLogChange(entityId:id,revision:1,deleted:false,payload:one),CloudLogChange(entityId:id,revision:2,deleted:false,payload:remote)],cursor:2,historyEpoch:epoch),after:0,owner:owner)
        #expect(try reopened.nextCloudLogMutation(owner: owner)?.baseRevision == 1)
        #expect(reopened.getAllLogs(userId:owner).first?.amountG == 200)
    }

    @Test func badPageRollsBackDomainAndCursor() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try LocalStore(databaseURL: dir.appendingPathComponent("v2.sqlite"))
        let owner = UUID(), id = UUID(), epoch = UUID()
        try Self.installEmptyHistory(store:store,owner:owner,epoch:epoch)
        let good = CloudLogChange(entityId: id, revision: 1, deleted: false, payload: try Self.aggregate(owner: owner,id:id))
        let bad = CloudLogChange(entityId: UUID(), revision: 2, deleted: false, payload: try Self.aggregate(owner: UUID(),id:UUID()))
        #expect(throws: (any Error).self) { try store.applyCloudLogPage(CloudLogPage(owner:owner, changes:[good,bad],cursor:2,historyEpoch:epoch),after:0,owner:owner) }
        #expect(store.getAllLogs(userId:owner).isEmpty)
        #expect(try store.cloudLogCursor(owner:owner) == 0)
        #expect(try store.cloudLogAggregates(owner:owner).isEmpty)
        #expect(throws: (any Error).self) { try store.applyCloudLogPage(CloudLogPage(owner:UUID(),changes:[good],cursor:1,historyEpoch:epoch),after:0,owner:owner) }
    }

    @Test func accountChangeDiscardsInFlightPage() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let store = try LocalStore(databaseURL:dir.appendingPathComponent("v2.sqlite")), owner = UUID()
        let transport = SuspendedCloudPull(owner:owner)
        try Self.installEmptyHistory(store:store,owner:owner,epoch:await transport.epoch)
        let coordinator = CloudLogSyncCoordinator(store:store,transport:transport)
        await coordinator.setOwner(owner)
        let task = Task { try await coordinator.sync(owner:owner,allowed:true) }
        while !(await transport.waiting) { await Task.yield() }
        await coordinator.setOwner(UUID())
        await transport.release()
        await #expect(throws:(any Error).self) { try await task.value }
        #expect(try store.cloudLogCursor(owner:owner) == 0)
    }

    static func installEmptyHistory(store:LocalStore,owner:UUID,epoch:UUID) throws {
        let id=UUID()
        try store.beginCloudLogBootstrap(CloudLogBootstrapPlan(owner:owner,snapshotId:id,historyEpoch:epoch,deviceId:UUID(),choice:.downloadOnly))
        try store.saveCloudLogManifest(CloudLogBootstrapManifest(owner:owner,snapshotId:id,historyEpoch:epoch,upperCursor:0,totalCount:0),owner:owner)
        try store.finishCloudLogBootstrap(owner:owner)
    }

    static func aggregate(owner: UUID, id: UUID = UUID(), amount: Float = 125) throws -> CloudLogAggregate {
        let product = Product(name:"Synthetic v2 product", caloriesPer100g:98.5, proteinGPer100g:1.25, carbsGPer100g:2.5, fatGPer100g:3.75,
                              localImageData:Data([1,2,3]), imageUrl:"https://example.invalid/private.jpg", nutritionSource:.user)
        let log = FoodLog(id:id,userId:owner,productId:product.id,mealType:"lunsj",amountG:amount,amountUnit:.milliliters,
                          nutritionPreparation:.asSold,nutritionSource:.user,loggedDate:Date(timeIntervalSince1970:1700000000),
                          loggedTime:Date(timeIntervalSince1970:1700000123),calories:123.75,proteinG:1.25,carbsG:2.5,fatG:3.75)
        return try CloudLogAggregate(log:log,product:product)
    }
}

private actor SuspendedCloudPull: CloudLogTransport {
    let owner: UUID
    let epoch = UUID()
    var waiting = false
    var continuation: CheckedContinuation<Void,Never>?
    init(owner:UUID) { self.owner=owner }
    func push(_ mutation:CloudLogMutation,owner:UUID) async throws -> CloudLogReceipt { throw CloudLogError.invalidData }
    func pull(after cursor:Int64,epoch:UUID,owner:UUID) async throws -> CloudLogPage {
        await withCheckedContinuation { continuation=$0; waiting=true }
        return CloudLogPage(owner:self.owner,changes:[],cursor:0,historyEpoch:epoch)
    }
    func head(owner:UUID) async throws -> CloudLogHead { CloudLogHead(owner:owner,historyEpoch:epoch,cursor:0) }
    func beginBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapManifest { throw CloudLogError.invalidData }
    func readBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapPage { throw CloudLogError.invalidData }
    func release() { continuation?.resume(); continuation=nil }
}
