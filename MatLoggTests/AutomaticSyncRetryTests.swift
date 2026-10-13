import Foundation
import Testing
@testable import MatLogg

@MainActor
struct AutomaticSyncRetryTests {
    @Test(arguments: ["config", "quota", "apply"])
    func transientServerFailureRecoversAfterRealBackoff(failure: String) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("retry.sqlite"))
        let owner = UUID()
        let log = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 125,
                          loggedDate: Date(), loggedTime: Date(), calories: 123.75,
                          proteinG: 10, carbsG: 12, fatG: 2)
        try store.saveLog(log)
        let original = try #require(store.fetchPendingEvents(ownerUserId: owner, limit: 50).first)
        let failedBody = failure == "apply" ? """
        {"ackedEventIds":[],"rejected":[{"eventId":"\(original.eventId)","code":"SERVER_ERROR","message":"Midlertidig serverfeil"}]}
        """ : "{\"code\":\"SERVER_ERROR\",\"message\":\"Temporary \(failure) failure\"}"
        let harness = TransportHarness(status: failure == "apply" ? 201 : 500, body: failedBody,
            recoveryBody: "{\"ackedEventIds\":[\"\(original.eventId)\"],\"rejected\":[]}")
        let engine = SyncEngine(databaseService: DatabaseService(store: store), apiService: harness.service,
                                syncEnabled: { true }, uploadPolicy: .integrationTesting)
        engine.updateActiveOwner(owner)
        defer { engine.updateActiveOwner(nil) }
        #expect(!(await engine.syncPendingEvents(ownerUserId: owner)).success)
        #expect(harness.stub.requests.count == 1)
        #expect(store.syncQueueStatus().unsyncedCount == 1)
        #expect(store.failedSyncCount() == 0)
        #expect(store.getAllLogs(userId: owner).map(\.id) == [log.id])
        let retryDate = try #require(store.nextPendingRetryDate(ownerUserId: owner))
        #expect(retryDate.timeIntervalSinceNow > 9)
        #expect(store.fetchPendingEvents(ownerUserId: owner, limit: 50).isEmpty)
        // No manual retry, queue edits or clock acceleration: wait for the production timer.
        let deadline = retryDate.addingTimeInterval(5)
        while store.syncQueueStatus().unsyncedCount != 0 && Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        let requests = harness.stub.requests
        #expect(requests.count == 2)
        let times = harness.stub.requestTimes
        #expect(times.count == 2)
        if times.count == 2 { #expect(times[1] >= retryDate.addingTimeInterval(-0.1)) }
        for request in requests {
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let events = try #require(body["events"] as? [[String: Any]])
            #expect(events.count == 1)
            #expect(events.first?["eventId"] as? String == original.eventId.uuidString)
            #expect(events.first?["payload"] as? String == original.payload.base64EncodedString())
        }
        #expect(store.syncQueueStatus().unsyncedCount == 0)
        let reopened = try LocalStore(databaseURL: directory.appendingPathComponent("retry.sqlite"))
        #expect(reopened.syncQueueStatus().unsyncedCount == 0)
        #expect(reopened.getAllLogs(userId: owner).count == 1)
        #expect(reopened.getAllLogs(userId: owner).first?.calories == log.calories)
    }
}
