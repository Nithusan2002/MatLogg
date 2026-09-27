import Foundation
import Testing
@testable import MatLogg

@MainActor
struct SyncRetryTests {
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
        #expect(store.fetchPendingEvents(limit: 1).isEmpty)

        store.retryDeadLetterEvents()

        #expect(store.failedSyncCount() == 0)
        #expect(store.pendingSyncCount() == 1)
        #expect(store.fetchPendingEvents(limit: 1).first?.eventId == event.eventId)
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
            syncEnabled: { true }
        )

        let result = await engine.syncPendingEvents()

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
            syncEnabled: { true }
        )

        let result = await engine.syncPendingEvents()

        #expect(!result.success)
        #expect(store.deadLetterIds.isEmpty)
        #expect(store.retryRequests.first?.eventId == event.eventId)
        #expect(store.retryRequests.first?.delay == 45)
    }

    private func makeGoal() -> Goal {
        Goal(
            userId: UUID(),
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
            lastError: nil
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
    private(set) var deadLetterIds: [UUID] = []
    private(set) var retryRequests: [RetryRequest] = []

    init(events: [SyncEvent]) {
        self.events = events
    }

    func fetchPendingEvents(limit: Int) async -> [SyncEvent] {
        Array(events.prefix(limit))
    }

    func markEventsInFlight(_ eventIds: [UUID]) async {}

    func markEventsAcked(_ eventIds: [UUID]) async {
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

    func nextPendingRetryDate() async -> Date? { nil }
}

@MainActor
private struct SyncAPIClientSpy: SyncAPIClient {
    let result: Result<APIService.UploadResult, Error>

    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult {
        try result.get()
    }
}
