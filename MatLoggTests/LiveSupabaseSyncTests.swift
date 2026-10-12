import Foundation
import Supabase
import Testing
@testable import MatLogg

/// Run each stage in a separate test host using scripts/run-live-sync-e2e.py.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["MATLOGG_LIVE_SYNC_RUN"] != nil))
@MainActor
struct LiveSupabaseSyncTests {
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
