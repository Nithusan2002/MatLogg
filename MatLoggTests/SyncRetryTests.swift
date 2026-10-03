import Foundation
import Testing
@testable import MatLogg

@MainActor
struct SyncRetryTests {
    @Test func pendingEventsAreFilteredByAuthenticatedOwner() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggOwnerFilter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try LocalStore(databaseURL: directory.appendingPathComponent("sync.sqlite"))
        let firstUser = UUID()
        let secondUser = UUID()
        try store.saveGoal(makeGoal(userId: firstUser))
        try store.saveGoal(makeGoal(userId: secondUser))

        let firstEvents = store.fetchPendingEvents(ownerUserId: firstUser, limit: 10)
        let secondEvents = store.fetchPendingEvents(ownerUserId: secondUser, limit: 10)

        #expect(firstEvents.count == 1)
        #expect(firstEvents.allSatisfy { $0.ownerUserId == firstUser })
        #expect(secondEvents.count == 1)
        #expect(secondEvents.allSatisfy { $0.ownerUserId == secondUser })
        #expect(Set(firstEvents.map(\.eventId)).isDisjoint(with: Set(secondEvents.map(\.eventId))))
    }

    @Test func deadLetterEventsRemainStoredAndCanBeRetriedManually() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggDeadLetter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try LocalStore(databaseURL: directory.appendingPathComponent("sync.sqlite"))
        try store.saveGoal(makeGoal())
        let event = try #require(store.fetchPendingEvents(limit: 1).first)

        store.markEventDeadLetter(event.eventId, error: "Permanent feil")

        #expect(store.pendingSyncCount() == 0)
        #expect(store.failedSyncCount() == 1)
        #expect(store.syncQueueStatus().failedCount == 1)
        #expect(store.syncQueueStatus().unsyncedCount == 1)
        #expect(store.failedSyncEvents(limit: 5) == [
            SyncFailureSummary(
                id: event.eventId,
                type: event.type,
                message: "Permanent feil",
                createdAt: event.createdAt
            )
        ])
        #expect(store.fetchPendingEvents(limit: 1).isEmpty)

        store.retryDeadLetterEvent(event.eventId, ownerUserId: try #require(event.ownerUserId))

        #expect(store.failedSyncCount() == 0)
        #expect(store.pendingSyncCount() == 1)
        #expect(store.fetchPendingEvents(limit: 1).first?.eventId == event.eventId)
    }

    @Test func statusIncludesInFlightEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggInFlightStatus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try LocalStore(databaseURL: directory.appendingPathComponent("sync.sqlite"))
        try store.saveGoal(makeGoal())
        let event = try #require(store.fetchPendingEvents(limit: 1).first)

        store.markEventsInFlight([event.eventId])

        #expect(store.syncQueueStatus().pendingCount == 0)
        #expect(store.syncQueueStatus().inFlightCount == 1)
        #expect(store.syncQueueStatus().unsyncedCount == 1)
    }

    @Test func syncProcessesMoreThanOneBatch() async {
        let events = (0..<55).map { _ in makeSyncEvent() }
        let store = SyncQueueStoreSpy(events: events)
        let api = BatchSyncAPIClientSpy()
        let engine = SyncEngine(
            databaseService: store,
            apiService: api,
            syncEnabled: { true }, uploadPolicy: .integrationTesting
        )
        let ownerUserId = UUID()
        engine.updateActiveOwner(ownerUserId)

        let result = await engine.syncPendingEvents(ownerUserId: ownerUserId)

        #expect(result.success)
        #expect(api.batchSizes == [50, 5])
    }

    @Test func retryDateIsPersistedAndExcludesEventUntilReady() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggRetryDate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try LocalStore(databaseURL: directory.appendingPathComponent("sync.sqlite"))
        try store.saveGoal(makeGoal())
        let event = try #require(store.fetchPendingEvents(limit: 1).first)

        store.markEventForRetry(event.eventId, error: "Midlertidig feil", backoffSeconds: 60)

        let retryDate = try #require(store.nextPendingRetryDate())
        #expect(retryDate.timeIntervalSinceNow > 50)
        #expect(store.fetchPendingEvents(limit: 1).isEmpty)
    }

    @Test func permanentClientFailureMovesEventToDeadLetterImmediately() async {
        let event = makeSyncEvent()
        let store = SyncQueueStoreSpy(events: [event])
        let api = SyncAPIClientSpy(result: .failure(
            APIService.APIError.backendError(statusCode: 422, code: "INVALID_EVENT", message: "Ugyldig hendelse")
        ))
        let engine = SyncEngine(
            databaseService: store,
            apiService: api,
            syncEnabled: { true }, uploadPolicy: .integrationTesting
        )
        let ownerUserId = UUID()
        engine.updateActiveOwner(ownerUserId)

        let result = await engine.syncPendingEvents(ownerUserId: ownerUserId)

        #expect(!result.success)
        #expect(store.deadLetterIds == [event.eventId])
        #expect(store.retryRequests.isEmpty)
    }

    @Test func rateLimitUsesRetryAfterWithoutDroppingEvent() async {
        let event = makeSyncEvent()
        let store = SyncQueueStoreSpy(events: [event])
        let api = SyncAPIClientSpy(result: .failure(
            APIService.APIError.rateLimited(retryAfterSeconds: 45)
        ))
        let engine = SyncEngine(
            databaseService: store,
            apiService: api,
            syncEnabled: { true }, uploadPolicy: .integrationTesting
        )
        let ownerUserId = UUID()
        engine.updateActiveOwner(ownerUserId)

        let result = await engine.syncPendingEvents(ownerUserId: ownerUserId)

        #expect(!result.success)
        #expect(store.deadLetterIds.isEmpty)
        #expect(store.retryRequests.first?.eventId == event.eventId)
        #expect(store.retryRequests.first?.delay == 45)
    }

    @Test(arguments: ["SERVER_ERROR", "SYNC_DISABLED"])
    func partialServerFailureRetriesOnlyUnacknowledgedEvent(code: String) async {
        let first = makeSyncEvent()
        let second = makeSyncEvent()
        let store = SyncQueueStoreSpy(events: [first, second])
        let api = SyncAPIClientSpy(result: .success(.init(
            ackedEventIds: [first.eventId],
            rejected: [.init(eventId: second.eventId, code: code, message: "Midlertidig serverfeil")]
        )))
        let engine = SyncEngine(databaseService: store, apiService: api, syncEnabled: { true }, uploadPolicy: .integrationTesting)
        let owner = UUID()
        engine.updateActiveOwner(owner)
        let result = await engine.syncPendingEvents(ownerUserId: owner)
        #expect(!result.success)
        #expect(store.deadLetterIds.isEmpty)
        #expect(store.retryRequests.map(\.eventId) == [second.eventId])
        #expect(store.ackedIds == [first.eventId])
    }

    @Test func responseCannotAcknowledgeEventsOutsideUploadedBatch() async {
        let event = makeSyncEvent()
        let foreignID = UUID()
        let store = SyncQueueStoreSpy(events: [event])
        let rejection = APIService.RejectedEvent(eventId: event.eventId, code: "VALIDATION_ERROR", message: "Ugyldig")
        let api = SyncAPIClientSpy(result: .success(.init(
            ackedEventIds: [foreignID], rejected: [rejection, rejection]
        )))
        let engine = SyncEngine(databaseService: store, apiService: api, syncEnabled: { true }, uploadPolicy: .integrationTesting)
        let owner = UUID()
        engine.updateActiveOwner(owner)
        let result = await engine.syncPendingEvents(ownerUserId: owner)
        #expect(!result.success)
        #expect(store.ackedIds.isEmpty)
        #expect(store.deadLetterIds == [event.eventId])
    }

    @Test func lostAcknowledgementKeepsOriginalEventForRetry() async {
        let event = makeSyncEvent()
        let store = SyncQueueStoreSpy(events: [event])
        let api = SyncAPIClientSpy(result: .failure(URLError(.timedOut)))
        let engine = SyncEngine(databaseService: store, apiService: api, syncEnabled: { true }, uploadPolicy: .integrationTesting)
        let owner = UUID()
        engine.updateActiveOwner(owner)
        let result = await engine.syncPendingEvents(ownerUserId: owner)
        #expect(!result.success)
        #expect(store.ackedIds.isEmpty)
        #expect(store.deadLetterIds.isEmpty)
        #expect(store.retryRequests.map(\.eventId) == [event.eventId])
    }

    @Test func dormantQueueSurvivesReopenWithoutLosingHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("dormant.sqlite")
        let owner = UUID()
        let store = try LocalStore(databaseURL: url)
        let goal = makeGoal(userId: owner)
        for _ in 0..<100 { try store.saveGoal(goal) }
        let original = store.fetchPendingEvents(ownerUserId: owner, limit: 1000)
        let reopened = try LocalStore(databaseURL: url)
        let retained = reopened.fetchPendingEvents(ownerUserId: owner, limit: 1000)
        #expect(retained.count == 100)
        #expect(Set(retained.map(\.eventId)) == Set(original.map(\.eventId)))
        #expect(retained.allSatisfy { $0.status == .pending && $0.attemptCount == 0 })
        #expect(retained.reduce(0) { $0 + $1.payload.count } > 0)
    }

    @Test func localOnlyBlocksAllTriggersEvenWithBackendEnabled() async throws {
        let event = makeSyncEvent()
        let owner = try #require(event.ownerUserId)
        let store = SyncQueueStoreSpy(events: [event])
        let api = BatchSyncAPIClientSpy()
        let engine = SyncEngine(databaseService: store, apiService: api, syncEnabled: { true })
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = DatabaseService(store: try LocalStore(databaseURL: directory.appendingPathComponent("local.sqlite")))
        let state = AppState(databaseService: database, syncEngine: engine, syncEnabled: { true })
        state.updateAuthenticatedUser(owner)
        for connected in [false, true] {
            state.updateNetworkAvailability(isConnected: connected)
            for reason in [SyncReason.appLaunch, .foreground, .networkRestored, .userInitiated] {
                await state.triggerSync(reason: reason)
            }
        }
        await state.retryFailedEvent(event.eventId)
        // The service boundary also rejects direct calls and account switches.
        let result = await engine.syncPendingEvents(ownerUserId: owner)
        state.updateAuthenticatedUser(UUID())
        state.updateAuthenticatedUser(owner)
        await state.triggerSync(reason: .foreground)
        #expect(!result.success)
        #expect(!state.isSyncAvailable)
        #expect(state.lastSyncError == nil)
        #expect(api.batchSizes.isEmpty)
        #expect(store.fetchCount == 0)
        #expect(store.retryDateReadCount == 0)
        #expect(store.inFlightIds.isEmpty)
        #expect(store.ackedIds.isEmpty)
        #expect(store.retryRequests.isEmpty)
        #expect(store.deadLetterIds.isEmpty)
    }

    private func makeGoal(userId: UUID = UUID()) -> Goal {
        Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2_000,
            proteinTargetG: 100,
            carbsTargetG: 250,
            fatTargetG: 70
        )
    }

    private func makeSyncEvent() -> SyncEvent {
        SyncEvent(
            eventId: UUID(),
            type: "goal.set",
            createdAt: Date(),
            entityId: UUID().uuidString,
            schemaVersion: 1,
            payload: Data("{}".utf8),
            status: .pending,
            attemptCount: 0,
            lastAttemptAt: nil,
            nextRetryAt: nil,
            lastError: nil,
            ownerUserId: UUID()
        )
    }
}

@MainActor
private final class SyncQueueStoreSpy: SyncQueueStore {
    struct RetryRequest {
        let eventId: UUID
        let delay: TimeInterval
    }

    private var events: [SyncEvent]
    private(set) var fetchCount = 0
    private(set) var retryDateReadCount = 0
    private(set) var inFlightIds: [UUID] = []
    private(set) var ackedIds: [UUID] = []
    private(set) var deadLetterIds: [UUID] = []
    private(set) var retryRequests: [RetryRequest] = []

    init(events: [SyncEvent]) {
        self.events = events
    }

    func fetchPendingEvents(ownerUserId: UUID, limit: Int) async -> [SyncEvent] {
        fetchCount += 1
        return Array(events.prefix(limit))
    }

    func markEventsInFlight(_ eventIds: [UUID]) async { inFlightIds.append(contentsOf: eventIds) }

    func markEventsAcked(_ eventIds: [UUID]) async {
        ackedIds.append(contentsOf: eventIds)
        events.removeAll { eventIds.contains($0.eventId) }
    }

    func markEventForRetry(_ eventId: UUID, error: String?, backoffSeconds: TimeInterval) async {
        retryRequests.append(RetryRequest(eventId: eventId, delay: backoffSeconds))
        events.removeAll { $0.eventId == eventId }
    }

    func markEventDeadLetter(_ eventId: UUID, error: String) async {
        deadLetterIds.append(eventId)
        events.removeAll { $0.eventId == eventId }
    }

    func nextPendingRetryDate(ownerUserId: UUID) async -> Date? {
        retryDateReadCount += 1
        return nil
    }
}

@MainActor
private struct SyncAPIClientSpy: SyncAPIClient {
    let result: Result<APIService.UploadResult, Error>

    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult {
        try result.get()
    }
}

@MainActor
private final class BatchSyncAPIClientSpy: SyncAPIClient {
    private(set) var batchSizes: [Int] = []

    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult {
        batchSizes.append(events.count)
        return APIService.UploadResult(ackedEventIds: events.map(\.eventId), rejected: [])
    }
}
