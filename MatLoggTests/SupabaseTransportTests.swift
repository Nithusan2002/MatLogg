import Foundation
import Supabase
import Testing
@testable import MatLogg

@MainActor
struct SupabaseTransportTests {
    @Test func uploadPreservesWireContractAndPartialResponse() async throws {
        let first = event(payload: Data("{\"label\":\"Blåbær\"}".utf8))
        let second = event()
        let harness = TransportHarness(body: """
        {"ackedEventIds":["\(first.eventId)"],"rejected":[{"eventId":"\(second.eventId)","code":"SERVER_ERROR","message":"Prøv igjen"}]}
        """)
        let result = try await harness.service.uploadEvents([first, second])
        #expect(result.ackedEventIds == [first.eventId])
        #expect(result.rejected.first?.eventId == second.eventId)
        #expect(result.rejected.first?.code == "SERVER_ERROR")
        let request = try #require(harness.stub.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/functions/v1/sync-events")
        #expect(request.value(forHTTPHeaderField: "apikey") == "synthetic-publishable-key")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(UUID(uuidString: try #require(json["deviceId"] as? String)) != nil)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(formatter.date(from: try #require(json["clientTime"] as? String)) != nil)
        let events = try #require(json["events"] as? [[String: Any]])
        #expect(events.count == 2)
        #expect(events[0]["eventId"] as? String == first.eventId.uuidString)
        #expect(events[0]["entityId"] as? String == first.entityId)
        #expect(events[0]["type"] as? String == "goal.set")
        #expect(events[0]["schemaVersion"] as? Int == 1)
        #expect(Data(base64Encoded: try #require(events[0]["payload"] as? String)) == first.payload)
        #expect(events[0]["ownerUserId"] == nil)
        let createdAtString = try #require(events[0]["createdAt"] as? String)
        let createdAt = try #require(formatter.date(from: createdAtString))
        #expect(abs(createdAt.timeIntervalSince(first.createdAt)) < 0.001)
    }

    @Test func batchLimitRejectsBeforeNetwork() async {
        let harness = TransportHarness()
        do {
            _ = try await harness.service.uploadEvents((0..<51).map { _ in event() })
            Issue.record("Oversized batch accepted")
        } catch APIService.APIError.batchLimitExceeded(let limit) { #expect(limit == 50) }
        catch { Issue.record("Unexpected error: \(error)") }
        #expect(harness.stub.requests.isEmpty)
    }

    @Test func payloadLimitIsMeasuredBeforeBase64() async throws {
        let harness = TransportHarness()
        _ = try await harness.service.uploadEvents([event(payload: Data(repeating: 65, count: 64 * 1024))])
        do {
            _ = try await harness.service.uploadEvents([event(payload: Data(repeating: 65, count: 64 * 1024 + 1))])
            Issue.record("Oversized payload accepted")
        } catch APIService.APIError.payloadTooLarge(let limit) { #expect(limit == 64 * 1024) }
        catch { Issue.record("Unexpected error: \(error)") }
        #expect(harness.stub.requests.count == 1)
    }

    @Test(arguments: [401, 503])
    func authAndDisabledErrorsKeepServerCode(status: Int) async {
        let code = status == 401 ? "UNAUTHORIZED" : "SYNC_DISABLED"
        let harness = TransportHarness(status: status, body: "{\"code\":\"\(code)\",\"message\":\"Prøv igjen\"}")
        do {
            _ = try await harness.service.uploadEvents([event()])
            Issue.record("HTTP failure accepted")
        } catch APIService.APIError.backendError(let actualStatus, let actualCode, let message) {
            #expect(actualStatus == status)
            #expect(actualCode == code)
            #expect(message == "Prøv igjen")
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func nonJSONServerErrorUsesControlledFallback() async {
        let harness = TransportHarness(status: 502, body: "bad gateway")
        do {
            _ = try await harness.service.uploadEvents([event()])
            Issue.record("HTTP failure accepted")
        } catch APIService.APIError.backendError(let status, let code, let message) {
            #expect(status == 502 && code == nil && message == "Serverfeil (502)")
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func rateLimitReturnsRetryDelay() async {
        let harness = TransportHarness(status: 429, body: "{}")
        do {
            _ = try await harness.service.uploadEvents([event()])
            Issue.record("Rate limit accepted")
        } catch APIService.APIError.rateLimited(let seconds) { #expect(seconds == 60) }
        catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func relayErrorIsMappedToNetworkError() async {
        let harness = TransportHarness(headers: ["x-relay-error": "true"])
        do {
            _ = try await harness.service.uploadEvents([event()])
            Issue.record("Relay failure accepted")
        } catch APIService.APIError.networkError(let message) {
            #expect(message == "Kunne ikke kontakte synktjenesten")
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test(arguments: ["not-json", "{\"ackedEventIds\":[\"not-a-uuid\"],\"rejected\":[]}", "{}"])
    func malformedSuccessCannotAcknowledgeEvents(body: String) async {
        let harness = TransportHarness(body: body)
        do {
            _ = try await harness.service.uploadEvents([event()])
            Issue.record("Malformed success accepted")
        } catch is DecodingError {} catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test func timeoutIsPropagated() async {
        let harness = TransportHarness(error: URLError(.timedOut))
        do {
            _ = try await harness.service.uploadEvents([event()])
            Issue.record("Timeout accepted")
        } catch let error as URLError { #expect(error.code == .timedOut) }
        catch { Issue.record("Unexpected error: \(error)") }
    }

    private func event(payload: Data = Data("{}".utf8)) -> SyncEvent {
        SyncEvent(eventId: UUID(), type: "goal.set", createdAt: Date(), entityId: UUID().uuidString,
                  schemaVersion: 1, payload: payload, status: .pending, attemptCount: 0,
                  lastAttemptAt: nil, nextRetryAt: nil, lastError: nil, ownerUserId: UUID())
    }
}

/// A distinct host routes each concurrent test to its own HTTP stub.
@MainActor
struct TransportHarness {
    let service: SupabaseService
    let stub: TransportStub

    init(status: Int = 201, body: String = "{\"ackedEventIds\":[],\"rejected\":[]}",
         headers: [String: String] = [:], error: URLError? = nil) {
        let host = "\(UUID().uuidString.lowercased()).example.test"
        stub = TransportStub(status: status, body: Data(body.utf8), headers: headers, error: error)
        SyncURLProtocol.registry.install(stub, host: host)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SyncURLProtocol.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://\(host)")!, supabaseKey: "synthetic-publishable-key",
            options: .init(auth: .init(storage: EmptyTestAuthStorage(), autoRefreshToken: false),
                           global: .init(session: URLSession(configuration: config))))
        service = SupabaseService(client: client, callbackURL: URL(string: "matlogg://auth/callback")!)
    }
}

nonisolated private struct EmptyTestAuthStorage: AuthLocalStorage {
    func store(key: String, value: Data) throws {}
    func retrieve(key: String) throws -> Data? { nil }
    func remove(key: String) throws {}
}

nonisolated final class TransportStub: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { recorded } }
    let status: Int
    let body: Data
    let headers: [String: String]
    let error: URLError?

    init(status: Int, body: Data, headers: [String: String], error: URLError?) {
        self.status = status; self.body = body; self.headers = headers; self.error = error
    }
    func record(_ request: URLRequest) { lock.withLock { recorded.append(request) } }
}

nonisolated private final class TransportRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var stubs: [String: TransportStub] = [:]
    func install(_ stub: TransportStub, host: String) { lock.withLock { stubs[host] = stub } }
    func stub(for host: String) -> TransportStub? { lock.withLock { stubs[host] } }
}

nonisolated private final class SyncURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = TransportRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let stub = Self.registry.stub(for: url.host ?? "") else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
        }
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = data
        }
        stub.record(captured)
        if let error = stub.error { client?.urlProtocol(self, didFailWithError: error); return }
        guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: stub.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct SupabaseQueueIntegrationTests {
    @Test func partialAckSurvivesRestartAndRetriesOnlyRemainingEvent() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.sqlite")
        let owner = UUID()
        let store = try LocalStore(databaseURL: url)
        let logs = [log(owner), log(owner)]
        try store.saveLogs(logs)
        let events = store.fetchPendingEvents(ownerUserId: owner, limit: 50)
        #expect(events.count == 2)
        let first = try #require(events.first)
        let second = try #require(events.last)
        let harness = TransportHarness(body: """
        {"ackedEventIds":["\(first.eventId)"],"rejected":[{"eventId":"\(second.eventId)","code":"SERVER_ERROR","message":"Transient"}]}
        """)
        let engine = makeEngine(store: store, service: harness.service, owner: owner)
        #expect(!(await engine.syncPendingEvents(ownerUserId: owner)).success)
        engine.updateActiveOwner(nil) // Cancel the scheduled retry before simulating restart.
        let reopened = try LocalStore(databaseURL: url)
        #expect(reopened.getAllLogs(userId: owner).map(\.id).sorted(by: uuidOrder) == logs.map(\.id).sorted(by: uuidOrder))
        #expect(reopened.syncQueueStatus().unsyncedCount == 1)
        #expect(reopened.fetchPendingEvents(ownerUserId: owner, limit: 50).isEmpty)
        reopened.markEventForRetry(second.eventId, error: nil, backoffSeconds: 0)
        let remaining = try #require(reopened.fetchPendingEvents(ownerUserId: owner, limit: 50).first)
        #expect(remaining.eventId == second.eventId && remaining.payload == second.payload)
        #expect(remaining.attemptCount == 1)
        let retry = TransportHarness(body: "{\"ackedEventIds\":[\"\(second.eventId)\"],\"rejected\":[]}")
        let retryEngine = makeEngine(store: reopened, service: retry.service, owner: owner)
        #expect((await retryEngine.syncPendingEvents(ownerUserId: owner)).success)
        let uploaded = try wireEventIDs(retry.stub)
        #expect(uploaded == [second.eventId])
        let final = try LocalStore(databaseURL: url)
        #expect(final.syncQueueStatus().unsyncedCount == 0)
        #expect(final.getAllLogs(userId: owner).count == 2)
    }

    @Test(arguments: [false, true])
    func timeoutOrInvalidResponseKeepsLocalLogAndStableEvent(malformedResponse: Bool) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.sqlite")
        let owner = UUID()
        let store = try LocalStore(databaseURL: url)
        let entry = log(owner)
        try store.saveLog(entry) // Offline: no transport has been created yet.
        let original = try #require(store.fetchPendingEvents(ownerUserId: owner, limit: 50).first)
        let harness = TransportHarness(body: "invalid-json", error: malformedResponse ? nil : URLError(.timedOut))
        let engine = makeEngine(store: store, service: harness.service, owner: owner)
        #expect(!(await engine.syncPendingEvents(ownerUserId: owner)).success)
        engine.updateActiveOwner(nil)
        let reopened = try LocalStore(databaseURL: url)
        #expect(reopened.getAllLogs(userId: owner).first?.id == entry.id)
        #expect(reopened.getAllLogs(userId: owner).first?.calories == entry.calories)
        #expect(reopened.syncQueueStatus().unsyncedCount == 1)
        reopened.markEventForRetry(original.eventId, error: nil, backoffSeconds: 0)
        let retained = try #require(reopened.fetchPendingEvents(ownerUserId: owner, limit: 50).first)
        #expect(retained.payload == original.payload && retained.eventId == original.eventId)
        let online = TransportHarness(body: "{\"ackedEventIds\":[\"\(original.eventId)\"],\"rejected\":[]}")
        let resumed = makeEngine(store: reopened, service: online.service, owner: owner)
        #expect((await resumed.syncPendingEvents(ownerUserId: owner)).success)
        let firstUpload = try wireEventIDs(harness.stub)
        let secondUpload = try wireEventIDs(online.stub)
        #expect(firstUpload == secondUpload)
        #expect(reopened.getAllLogs(userId: owner).count == 1)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
    }

    @Test func interruptedInFlightUploadIsRecoveredOnReopen() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.sqlite")
        let owner = UUID()
        let store = try LocalStore(databaseURL: url)
        try store.saveLog(log(owner))
        let original = try #require(store.fetchPendingEvents(ownerUserId: owner, limit: 50).first)
        store.markEventsInFlight([original.eventId]) // Process ends before recording the ACK.
        #expect(store.syncQueueStatus().inFlightCount == 1)
        let reopened = try LocalStore(databaseURL: url)
        let recovered = try #require(reopened.fetchPendingEvents(ownerUserId: owner, limit: 50).first)
        #expect(recovered.eventId == original.eventId && recovered.payload == original.payload)
        #expect(recovered.attemptCount == 1)
        let harness = TransportHarness(body: "{\"ackedEventIds\":[\"\(original.eventId)\"],\"rejected\":[]}")
        let engine = makeEngine(store: reopened, service: harness.service, owner: owner)
        #expect((await engine.syncPendingEvents(ownerUserId: owner)).success)
        #expect(try wireEventIDs(harness.stub) == [original.eventId])
        #expect(reopened.getAllLogs(userId: owner).count == 1)
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
    }

    private func makeEngine(store: LocalStore, service: SupabaseService, owner: UUID) -> SyncEngine {
        let engine = SyncEngine(databaseService: DatabaseService(store: store), apiService: service,
                                syncEnabled: { true }, uploadPolicy: .integrationTesting)
        engine.updateActiveOwner(owner)
        return engine
    }
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func log(_ owner: UUID) -> FoodLog {
        FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 125,
                loggedDate: Date(), loggedTime: Date(), calories: 123.75, proteinG: 10, carbsG: 12, fatG: 2)
    }
    private func uuidOrder(_ left: UUID, _ right: UUID) -> Bool { left.uuidString < right.uuidString }
    private func wireEventIDs(_ stub: TransportStub) throws -> [UUID] {
        let request = try #require(stub.requests.first)
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let events = try #require(json["events"] as? [[String: Any]])
        return try events.map { event in
            let id = try #require(event["eventId"] as? String)
            return try #require(UUID(uuidString: id))
        }
    }
}
