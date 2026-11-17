import Foundation
import Supabase
import Testing
@testable import MatLogg

/// Run each stage in a separate test host using scripts/run-live-sync-e2e.py.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MATLOGG_LIVE_SYNC_RUN"] != nil))
@MainActor
struct LiveSupabaseSyncTests {
    @Test func twoWayLogSyncConvergesAndRetainsConflicts() async throws {
        let context = try LiveSyncContext()
        let (_, client, owner) = try await context.signIn()
        let aURL = context.directory.appendingPathComponent("v2-a.sqlite")
        let a = try LocalStore(databaseURL:aURL)
        let b = try LocalStore(databaseURL:context.directory.appendingPathComponent("v2-b.sqlite"))
        let transport = SupabaseCloudLogTransport(client:client)
        let failing = FailOnceAfterCloudCommit(base:transport)
        let ca = CloudLogSyncCoordinator(store:a,transport:failing)
        let cb = CloudLogSyncCoordinator(store:b,transport:transport)
        await ca.setOwner(owner); await cb.setOwner(owner)
        try await ca.transferHistory(owner:owner,choice:.downloadOnly,device:UUID(),allowed:true)
        try await cb.transferHistory(owner:owner,choice:.downloadOnly,device:UUID(),allowed:true)
        let epoch = try #require(try a.cloudLogEpoch(owner:owner))
        a.configureCloudLogRouting(allowed: true)
        b.configureCloudLogRouting(allowed: true)
        try a.setCloudLogEnabled(true, owner: owner, device: UUID())
        try b.setCloudLogEnabled(true, owner: owner, device: UUID())
        let id = UUID(), deviceA = UUID(), deviceB = UUID()
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner:owner,id:id), store: a)
        await #expect(throws:(any Error).self) { try await ca.sync(owner:owner,allowed:true) }
        // A new store and coordinator replay the frozen event after servercommit/ACK loss.
        let reopened = try LocalStore(databaseURL:aURL)
        reopened.configureCloudLogRouting(allowed: true)
        let resumed = CloudLogSyncCoordinator(store:reopened,transport:transport)
        await resumed.setOwner(owner)
        try await resumed.sync(owner:owner,allowed:true)
        try await cb.sync(owner:owner,allowed:true)
        #expect(b.getAllLogs(userId:owner).count == 1)
        #expect(try b.cloudLogAggregates(owner:owner).first?.product.name == "Synthetic v2 product")
        #expect(try b.cloudLogAggregates(owner:owner).first?.product.localImageData == nil)
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner:owner,id:id,amount:200), store: b)
        try await cb.sync(owner:owner,allowed:true)
        try await resumed.sync(owner:owner,allowed:true)
        #expect(reopened.getAllLogs(userId:owner).first?.amountG == 200)
        // Concurrent edit candidates are retained; server does not overwrite B's local draft.
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner:owner,id:id,amount:300), store: reopened)
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner:owner,id:id,amount:400), store: b)
        try await resumed.sync(owner:owner,allowed:true)
        try await cb.sync(owner:owner,allowed:true)
        #expect(try b.cloudLogConflictCandidates(owner:owner).first?.local.payload?.log.amountG == 400)
        #expect(b.getAllLogs(userId:owner).first?.amountG == 400)
        // A tombstone hides even the conflicting local edit without deleting its candidate.
        try reopened.deleteLog(id)
        try await resumed.sync(owner:owner,allowed:true)
        try await cb.sync(owner:owner,allowed:true)
        #expect(b.getAllLogs(userId:owner).isEmpty)
        #expect(try b.cloudLogConflicts(owner:owner).count == 1)
        #expect(try b.cloudLogAggregates(owner:owner).isEmpty)
        let report = try await cb.sync(owner:owner,allowed:true)
        #expect(report.conflicts.count == 1 && report.conflicts.first?.current.deleted == true)
        // Stale offline upsert cannot revive the deleted entity.
        var stale = CloudLogMutation(eventId:UUID(),deviceId:deviceB,entityId:id,schemaVersion:2,type:"log.upsert",baseRevision:1,
            payload:try CloudLogSyncTests.aggregate(owner:owner,id:id,amount:500))
        stale.historyEpoch = epoch
        let receipt = try await transport.push(stale,owner:owner)
        #expect(receipt.status == "conflict" && receipt.change.deleted)
        let replay = try await transport.push(stale,owner:owner)
        #expect(replay.eventId == receipt.eventId && replay.change.revision == receipt.change.revision)
        // Explicit local choice copies a tombstoned log to a fresh identity.
        let deletedReview = try #require(try b.cloudLogReviews(owner: owner).first)
        let copyID = try b.resolveCloudLog(deletedReview, choice: .useLocal, owner: owner, device: deviceB)
        #expect(copyID != id)
        try await cb.sync(owner: owner, allowed: true)
        try await resumed.sync(owner: owner, allowed: true)
        #expect(reopened.getAllLogs(userId: owner).first { $0.id == copyID }?.amountG == 400)
        #expect(!reopened.getAllLogs(userId: owner).contains { $0.id == id })
        // A second conflict can explicitly accept the downloaded cloud version.
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner: owner, id: copyID, amount: 600), store: reopened)
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner: owner, id: copyID, amount: 500), store: b)
        try await resumed.sync(owner: owner, allowed: true)
        try await cb.sync(owner: owner, allowed: true)
        let cloudReview = try #require(try b.cloudLogReviews(owner: owner).first)
        try b.resolveCloudLog(cloudReview, choice: .useCloud, owner: owner, device: deviceB)
        try await cb.sync(owner: owner, allowed: true)
        #expect(b.getAllLogs(userId: owner).first { $0.id == copyID }?.amountG == 600)
        #expect(try b.cloudLogReviews(owner: owner).isEmpty)
        #expect(!reopened.fetchPendingEvents(ownerUserId: owner, limit: 100).contains { $0.type == "log.upsert" || $0.type == "log.delete" })
        // Concurrent independent transactions must allocate a gap-free committed cursor.
        let firstID = UUID(), secondID = UUID()
        let first = CloudLogMutation(eventId:UUID(),deviceId:deviceA,entityId:firstID,schemaVersion:2,type:"log.upsert",baseRevision:0,payload:try CloudLogSyncTests.aggregate(owner:owner,id:firstID),historyEpoch:epoch)
        let second = CloudLogMutation(eventId:UUID(),deviceId:deviceB,entityId:secondID,schemaVersion:2,type:"log.upsert",baseRevision:0,payload:try CloudLogSyncTests.aggregate(owner:owner,id:secondID),historyEpoch:epoch)
        async let firstAck = transport.push(first,owner:owner)
        async let secondAck = transport.push(second,owner:owner)
        let replies = try await [firstAck,secondAck]
        #expect(replies.allSatisfy { $0.status == "applied" })
        let revisions = replies.map(\.change.revision).sorted()
        #expect(revisions[1] == revisions[0]+1)
        try await resumed.sync(owner:owner,allowed:true)
        try await cb.sync(owner:owner,allowed:true)
        #expect(Set(reopened.getAllLogs(userId:owner).map(\.id)) == Set(b.getAllLogs(userId:owner).map(\.id)))
        // Deactivation blocks network work while ordinary offline changes retain deletion intent.
        let lifecycle = DevelopmentCloudLogRepository(store: b, transport: transport, uploadsAllowed: true)
        await lifecycle.selectOwner(owner)
        try await lifecycle.deactivate(owner: owner)
        try Self.saveOrdinaryAggregate(CloudLogSyncTests.aggregate(owner: owner, id: copyID, amount: 777), store: b)
        try b.deleteLog(copyID)
        await #expect(throws: CloudLogError.disabled) { try await lifecycle.sync(owner: owner) }
        try await lifecycle.prepare(owner: owner, choice: .downloadOnly)
        try await lifecycle.sync(owner: owner)
        let stoppedReview = try #require(try await lifecycle.reviews(owner: owner).first { $0.id == copyID })
        #expect(stoppedReview.local == nil && stoppedReview.server?.payload != nil)
        try await lifecycle.resolve(stoppedReview, choice: .useLocal, owner: owner)
        try await lifecycle.sync(owner: owner)
        try await resumed.sync(owner: owner, allowed: true)
        #expect(!reopened.getAllLogs(userId: owner).contains { $0.id == copyID })
        try FileManager.default.removeItem(at:context.directory)
    }

    private static func saveOrdinaryAggregate(_ value: CloudLogAggregate, store: LocalStore) throws {
        try store.saveProduct(value.product, ownerUserId: value.log.userId)
        try store.saveLog(value.log)
    }

    @Test func historyBootstrapResumesAndPreparesEpochRecovery() async throws {
        let context=try LiveSyncContext()
        let (_,client,owner)=try await context.signIn()
        let transport=SupabaseCloudLogTransport(client:client)
        let source=try LocalStore(databaseURL:context.directory.appendingPathComponent("history-source.sqlite"))
        let sync=CloudLogSyncCoordinator(store:source,transport:transport)
        await sync.setOwner(owner)
        try await sync.transferHistory(owner:owner,choice:.downloadOnly,device:UUID(),allowed:true)
        var seededIDs:Set<UUID>=[]
        for _ in 0..<101 {
            let value=try CloudLogSyncTests.aggregate(owner:owner)
            seededIDs.insert(value.log.id)
            try source.saveCloudLog(value,owner:owner,device:UUID())
        }
        try await sync.sync(owner:owner,allowed:true)
        let url=context.directory.appendingPathComponent("history-target.sqlite")
        let target=try LocalStore(databaseURL:url)
        let interrupted=CloudLogSyncCoordinator(store:target,transport:InterruptSecondBootstrapPage(base:transport))
        await interrupted.setOwner(owner)
        await #expect(throws:(any Error).self) {
            try await interrupted.transferHistory(owner:owner,choice:.downloadOnly,device:UUID(),allowed:true)
        }
        #expect(try target.cloudLogBootstrapPlan(owner:owner)?.offset == 100)
        #expect(target.getAllLogs(userId:owner).isEmpty)
        // Another process-style store resumes the persisted plan and offset.
        let resumedStore=try LocalStore(databaseURL:url)
        let resumed=CloudLogSyncCoordinator(store:resumedStore,transport:transport)
        await resumed.setOwner(owner)
        try await resumed.sync(owner:owner,allowed:true)
        #expect(seededIDs.isSubset(of:Set(resumedStore.getAllLogs(userId:owner).map(\.id))))
        #expect(try resumedStore.cloudLogBootstrapPlan(owner:owner) == nil)

        // Explicit history choice merges with existing cloud data using new events.
        let local=try LocalStore(databaseURL:context.directory.appendingPathComponent("history-existing.sqlite"))
        let collisionID=try #require(seededIDs.first)
        let edited=try CloudLogSyncTests.aggregate(owner:owner,id:collisionID,amount:666)
        try local.saveProduct(edited.product,ownerUserId:owner)
        try local.saveLog(edited.log)
        let localOnly=try CloudLogSyncTests.aggregate(owner:owner,amount:222)
        try local.saveProduct(localOnly.product,ownerUserId:owner)
        try local.saveLog(localOnly.log)
        let oldQueue=local.fetchPendingEvents(ownerUserId:owner,limit:50).map(\.eventId)
        let transfer=CloudLogSyncCoordinator(store:local,transport:transport)
        await transfer.setOwner(owner)
        try await transfer.transferHistory(owner:owner,choice:.includeLocalHistory,device:UUID(),allowed:true)
        let result=try await transfer.sync(owner:owner,allowed:true)
        #expect(result.conflicts.contains { $0.local.entityId == collisionID })
        #expect(local.getAllLogs(userId:owner).first(where:{$0.id==collisionID})?.amountG == 666)
        #expect(local.fetchPendingEvents(ownerUserId:owner,limit:50).map(\.eventId) == oldQueue)
        try await sync.sync(owner:owner,allowed:true)
        #expect(source.getAllLogs(userId:owner).contains { $0.id==localOnly.log.id })

        // Persist two unsent changes across the simulated server restore in the harness.
        let changed=try CloudLogSyncTests.aggregate(owner:owner,id:collisionID,amount:888)
        let unsent=try CloudLogSyncTests.aggregate(owner:owner,amount:999)
        try source.saveCloudLog(changed,owner:owner,device:UUID())
        try source.saveCloudLog(unsent,owner:owner,device:UUID())
        let event=try #require(try source.nextCloudLogMutation(owner:owner))
        let epoch=try #require(try source.cloudLogEpoch(owner:owner))
        let checkpoint=HistoryEpochCheckpoint(owner:owner,epoch:epoch,unsentID:unsent.log.id,changedID:changed.log.id,event:event)
        try JSONEncoder().encode(checkpoint).write(to:context.directory.appendingPathComponent("history-checkpoint.json"),options:[.atomic,.completeFileProtection])
    }

    @Test func restoredServerEpochDoesNotReplayUnsentHistory() async throws {
        let context=try LiveSyncContext()
        let (_,client,owner)=try await context.signIn()
        let checkpoint=try JSONDecoder().decode(HistoryEpochCheckpoint.self,from:Data(contentsOf:context.directory.appendingPathComponent("history-checkpoint.json")))
        #expect(checkpoint.owner == owner)
        let transport=SupabaseCloudLogTransport(client:client)
        let head=try await transport.head(owner:owner)
        #expect(head.historyEpoch != checkpoint.epoch)
        await #expect(throws:(any Error).self) { try await transport.push(checkpoint.event,owner:owner) }
        let source=try LocalStore(databaseURL:context.directory.appendingPathComponent("history-source.sqlite"))
        let sync=CloudLogSyncCoordinator(store:source,transport:transport)
        await sync.setOwner(owner)
        let result=try await sync.sync(owner:owner,allowed:true)
        #expect(try source.cloudLogEpoch(owner:owner) == head.historyEpoch)
        let unsent=try #require(result.recovery.first { $0.entityId==checkpoint.unsentID })
        #expect(unsent.local?.log.amountG == 999 && unsent.mutations.count == 1)
        let edit=try #require(result.recovery.first { $0.entityId==checkpoint.changedID })
        #expect(edit.local?.log.amountG == 888)
        #expect(edit.mutations.contains { $0.eventId==checkpoint.event.eventId })
        #expect(try source.nextCloudLogMutation(owner:owner) == nil)
        #expect(source.getAllLogs(userId:owner).contains { $0.id==checkpoint.unsentID && $0.amountG==999 })
        let clean=try LocalStore(databaseURL:context.directory.appendingPathComponent("history-clean.sqlite"))
        let restore=CloudLogSyncCoordinator(store:clean,transport:transport)
        await restore.setOwner(owner)
        try await restore.sync(owner:owner,allowed:true)
        #expect(!clean.getAllLogs(userId:owner).contains { $0.id==checkpoint.unsentID })
        #expect(clean.syncQueueStatus().unsyncedCount == 0)
        // Recovery choices are new, epoch-bound actions rather than replay.
        let reviews = try source.cloudLogReviews(owner: owner)
        let localReview = try #require(reviews.first { $0.id == checkpoint.unsentID })
        let cloudReview = try #require(reviews.first { $0.id == checkpoint.changedID })
        try source.resolveCloudLog(localReview, choice: .useLocal, owner: owner, device: UUID())
        try source.resolveCloudLog(cloudReview, choice: .useCloud, owner: owner, device: UUID())
        let reviewedEvent = try #require(try source.nextCloudLogMutation(owner: owner))
        #expect(reviewedEvent.historyEpoch == head.historyEpoch && !localReview.mutations.contains { $0.eventId == reviewedEvent.eventId })
        try await sync.sync(owner: owner, allowed: true)
        try await restore.sync(owner: owner, allowed: true)
        #expect(clean.getAllLogs(userId: owner).contains { $0.id == checkpoint.unsentID && $0.amountG == 999 })
        #expect(source.getAllLogs(userId: owner).first { $0.id == checkpoint.changedID }?.amountG == cloudReview.server?.payload?.log.amountG)
        try FileManager.default.removeItem(at:context.directory)
    }

    @Test func completeLogRoundtripToCleanDatabase() async throws {
        let context = try LiveSyncContext()
        let (_, client, owner) = try await context.signIn()
        let source = try LocalStore(databaseURL: context.directory.appendingPathComponent("source.sqlite"))
        let destinationURL = context.directory.appendingPathComponent("destination.sqlite")
        let destination = try LocalStore(databaseURL: destinationURL)
        let log = LogSnapshotRestoreTests.log(owner: owner)
        try source.saveLog(log)
        let persisted = try #require(source.getAllLogs(userId: owner).first)
        let row = RecoverySpikeRow(owner_id: owner, id: log.id, schema_version: 1, snapshot: persisted)
        try await client.from("qa_log_snapshots").insert(row).execute()
        // Immutable fixture rejects duplicate writes rather than silently overwriting.
        await #expect(throws: (any Error).self) {
            try await client.from("qa_log_snapshots").insert(row).execute()
        }
        let rows: [RecoverySpikeRow] = try await client.from("qa_log_snapshots")
            .select().eq("id", value: log.id.uuidString).execute().value
        let received = try #require(rows.first)
        #expect(rows.count == 1 && received.schema_version == 1 && received.owner_id == owner)
        try destination.restoreLogSnapshotForTesting(received.snapshot, authenticatedOwner: owner)
        try destination.restoreLogSnapshotForTesting(received.snapshot, authenticatedOwner: owner)
        let reopened = try LocalStore(databaseURL: destinationURL)
        let restored = try #require(reopened.getAllLogs(userId: owner).first)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(restored) == encoder.encode(persisted))
        #expect(reopened.getAllLogs(userId: owner).count == 1)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
        #expect(source.syncQueueStatus().unsyncedCount == 1)
        // Server constraints reject a payload that falsely claims another owner.
        let forged = RecoverySpikeRow(owner_id: UUID(), id: UUID(), schema_version: 1, snapshot: persisted)
        await #expect(throws: (any Error).self) {
            try await client.from("qa_log_snapshots").insert(forged).execute()
        }
        let env = ProcessInfo.processInfo.environment
        let secondEmail = try #require(env["MATLOGG_LIVE_SYNC_SECOND_EMAIL"])
        let secondPassword = try #require(env["MATLOGG_LIVE_SYNC_SECOND_PASSWORD"])
        try await client.auth.signOut(scope: .local)
        try await client.auth.signIn(email: secondEmail, password: secondPassword)
        let foreign: [RecoverySpikeRow] = try await client.from("qa_log_snapshots")
            .select().eq("id", value: log.id.uuidString).execute().value
        #expect(foreign.isEmpty)
        await #expect(throws: (any Error).self) {
            try await client.from("qa_log_snapshots").insert(row).execute()
        }
        try FileManager.default.removeItem(at: context.directory)
    }

    @Test func uploadStopsAfterServerCommitBeforeLocalAck() async throws {
        let context = try LiveSyncContext()
        let (service, client, owner) = try await context.signIn()
        let store = try LocalStore(databaseURL: context.databaseURL)
        let product = Product(name: "Synthetic live sync product", caloriesPer100g: 99,
                              proteinGPer100g: 8, carbsGPer100g: 9.6, fatGPer100g: 1.6)
        let log = FoodLog(userId: owner, productId: product.id, mealType: "lunsj", amountG: 125,
                          loggedDate: Date(), loggedTime: Date(), calories: 123.75,
                          proteinG: 10, carbsG: 12, fatG: 2)
        // Domain records and events exist before the first network upload.
        try store.saveProduct(product, ownerUserId: owner)
        try store.saveLog(log)
        let queued = store.fetchPendingEvents(ownerUserId: owner, limit: 50)
        #expect(queued.count == 2)
        #expect(store.getAllLogs(userId: owner).map(\.id) == [log.id])
        #expect(try await context.rows(client, table: "food_logs", owner: owner).isEmpty)

        let checkpoint = LiveSyncCheckpoint(owner: owner, logID: log.id, eventIDs: queued.map(\.eventId),
                                            payloads: queued.map(\.payload), processID: ProcessInfo.processInfo.processIdentifier)
        try JSONEncoder().encode(checkpoint).write(to: context.checkpointURL, options: .atomic)
        let boundary = HoldAfterServerCommit(service: service)
        let engine = SyncEngine(databaseService: DatabaseService(store: store), apiService: boundary,
                                syncEnabled: { true }, uploadPolicy: .integrationTesting)
        engine.updateActiveOwner(owner)
        // Deliberately leave this task suspended. The test host ends without recording ACKs.
        Task { _ = await engine.syncPendingEvents(ownerUserId: owner) }
        let deadline = Date().addingTimeInterval(30)
        while boundary.response == nil && boundary.failure == nil && Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        if let failure = boundary.failure { throw failure }
        let response = try #require(boundary.response)
        #expect(Set(response.ackedEventIds) == Set(checkpoint.eventIDs))
        #expect(response.rejected.isEmpty)
        #expect(store.syncQueueStatus().inFlightCount == 2)
        #expect(store.syncQueueStatus().unsyncedCount == 2)
        #expect(try await context.rows(client, table: "food_logs", owner: owner).count == 1)
        #expect(try await context.rows(client, table: "event_inbox", owner: owner).count == 2)
    }

    @Test func newProcessReplaysSameEventsWithoutDuplicates() async throws {
        let context = try LiveSyncContext()
        let checkpoint = try JSONDecoder().decode(LiveSyncCheckpoint.self, from: Data(contentsOf: context.checkpointURL))
        #expect(ProcessInfo.processInfo.processIdentifier != checkpoint.processID)
        let (service, client, owner) = try await context.signIn()
        #expect(owner == checkpoint.owner)
        let store = try LocalStore(databaseURL: context.databaseURL)
        let recovered = store.fetchPendingEvents(ownerUserId: owner, limit: 50)
        #expect(recovered.map(\.eventId) == checkpoint.eventIDs)
        #expect(recovered.map(\.payload) == checkpoint.payloads)
        #expect(recovered.allSatisfy { $0.status == .pending && $0.attemptCount == 1 })
        #expect(store.getAllLogs(userId: owner).map(\.id) == [checkpoint.logID])
        let engine = SyncEngine(databaseService: DatabaseService(store: store), apiService: service,
                                syncEnabled: { true }, uploadPolicy: .integrationTesting)
        engine.updateActiveOwner(owner)
        #expect((await engine.syncPendingEvents(ownerUserId: owner)).success)
        #expect(store.syncQueueStatus().unsyncedCount == 0)
        let logs = try await context.rows(client, table: "food_logs", owner: owner)
        #expect(logs.count == 1)
        #expect(logs.first?["id"] as? String == checkpoint.logID.uuidString.lowercased())
        #expect(logs.first?["kcal"] as? Double == 123.75)
        #expect(logs.first?["amount"] as? Double == 125)
        #expect(logs.first?["unit"] as? String == "g")
        let inbox = try await context.rows(client, table: "event_inbox", owner: owner)
        #expect(inbox.count == 2)
        #expect(Set(inbox.compactMap { ($0["event_id"] as? String).flatMap(UUID.init(uuidString:)) }) == Set(checkpoint.eventIDs))
        let reopened = try LocalStore(databaseURL: context.databaseURL)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
        #expect(reopened.getAllLogs(userId: owner).map(\.id) == [checkpoint.logID])
        try FileManager.default.removeItem(at: context.directory)
    }
}

nonisolated private struct LiveSyncCheckpoint: Codable {
    let owner: UUID
    let logID: UUID
    let eventIDs: [UUID]
    let payloads: [Data]
    let processID: Int32
}

@MainActor
private struct LiveSyncContext {
    let url: URL
    let key: String
    let email: String
    let password: String
    let directory: URL
    var databaseURL: URL { directory.appendingPathComponent("queue.sqlite") }
    var checkpointURL: URL { directory.appendingPathComponent("checkpoint.json") }

    init() throws {
        let env = ProcessInfo.processInfo.environment
        let urlText = try #require(env["MATLOGG_LIVE_SYNC_URL"])
        url = try #require(URL(string: urlText))
        #expect(url.scheme == "http" && ["127.0.0.1", "localhost"].contains(url.host ?? ""))
        guard url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") else {
            throw URLError(.unsupportedURL)
        }
        key = try #require(env["MATLOGG_LIVE_SYNC_KEY"])
        email = try #require(env["MATLOGG_LIVE_SYNC_EMAIL"])
        password = try #require(env["MATLOGG_LIVE_SYNC_PASSWORD"])
        let runIDText = try #require(env["MATLOGG_LIVE_SYNC_RUN"])
        let runID = try #require(UUID(uuidString: runIDText))
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
        directory = documents.appendingPathComponent("live-sync-\(runID)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func signIn() async throws -> (SupabaseService, SupabaseClient, UUID) {
        let client = SupabaseClient(supabaseURL: url, supabaseKey: key,
            options: .init(auth: .init(storage: LiveSyncAuthStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: .ephemeral))))
        let callback = try #require(URL(string: "matlogg://auth/callback"))
        let service = SupabaseService(client: client, callbackURL: callback)
        let owner = try await service.signIn(email: email, password: password).id
        let session = try await client.auth.session
        #expect(session.user.id == owner && !session.isExpired)
        return (service, client, owner)
    }

    func rows(_ client: SupabaseClient, table: String, owner: UUID) async throws -> [[String: Any]] {
        let response = try await client.from(table).select().eq("owner_id", value: owner.uuidString).execute()
        return try #require(JSONSerialization.jsonObject(with: response.data) as? [[String: Any]])
    }
}

nonisolated private final class LiveSyncAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { lock.withLock { values[key] = nil } }
}

@MainActor
private final class HoldAfterServerCommit: SyncAPIClient {
    let service: SupabaseService
    private(set) var response: APIService.UploadResult?
    private(set) var failure: Error?
    init(service: SupabaseService) { self.service = service }
    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult {
        do { response = try await service.uploadEvents(events) }
        catch { failure = error; throw error }
        // A real server ACK exists, but SyncEngine must never receive it in this host.
        while true { try await Task.sleep(for: .seconds(3600)) }
    }
}

nonisolated private struct RecoverySpikeRow: Codable {
    let owner_id: UUID
    let id: UUID
    let schema_version: Int
    let snapshot: FoodLog
}

private actor FailOnceAfterCloudCommit: CloudLogTransport {
    let base: SupabaseCloudLogTransport
    var fail = true
    init(base:SupabaseCloudLogTransport) { self.base=base }
    func push(_ mutation:CloudLogMutation,owner:UUID) async throws -> CloudLogReceipt {
        let result = try await base.push(mutation,owner:owner)
        if fail { fail=false; throw URLError(.networkConnectionLost) }
        return result
    }
    func pull(after cursor:Int64,epoch:UUID,owner:UUID) async throws -> CloudLogPage { try await base.pull(after:cursor,epoch:epoch,owner:owner) }
    func head(owner:UUID) async throws -> CloudLogHead { try await base.head(owner:owner) }
    func beginBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapManifest { try await base.beginBootstrap(plan) }
    func readBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapPage { try await base.readBootstrap(plan) }
}

nonisolated private struct HistoryEpochCheckpoint: Codable {
    let owner:UUID
    let epoch:UUID
    let unsentID:UUID
    let changedID:UUID
    let event:CloudLogMutation
}
private actor InterruptSecondBootstrapPage: CloudLogTransport {
    let base:SupabaseCloudLogTransport
    init(base:SupabaseCloudLogTransport) { self.base=base }
    func push(_ mutation:CloudLogMutation,owner:UUID) async throws -> CloudLogReceipt { try await base.push(mutation,owner:owner) }
    func pull(after cursor:Int64,epoch:UUID,owner:UUID) async throws -> CloudLogPage { try await base.pull(after:cursor,epoch:epoch,owner:owner) }
    func head(owner:UUID) async throws -> CloudLogHead { try await base.head(owner:owner) }
    func beginBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapManifest { try await base.beginBootstrap(plan) }
    func readBootstrap(_ plan:CloudLogBootstrapPlan) async throws -> CloudLogBootstrapPage {
        if plan.offset>=100 { throw URLError(.networkConnectionLost) }
        return try await base.readBootstrap(plan)
    }
}
