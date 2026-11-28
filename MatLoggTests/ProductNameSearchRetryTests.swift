import Foundation
import Testing
@testable import MatLogg

@MainActor
struct ProductNameSearchRetryTests {
    @Test func transientFailuresRecoverOnThirdAttempt() async throws {
        let client = NameSearchHTTPStub(statuses: [503, 502, 200])
        var waits: [TimeInterval] = []
        let result = try await ProductNameSearchRequest.send(request(), client: client) { waits.append($0) }
        #expect(result.response.statusCode == 200)
        #expect(client.calls == 3)
        #expect(waits == [1, 3])
        #expect(client.timeouts.allSatisfy { $0 > 0 && $0 <= 10 })
    }

    @Test func persistentFailureStopsAfterThreeRequests() async throws {
        let client = NameSearchHTTPStub(statuses: [503])
        let result = try await ProductNameSearchRequest.send(request(), client: client, sleep: { _ in })
        #expect(result.response.statusCode == 503)
        #expect(client.calls == 3)
    }

    @Test(arguments: [400, 401, 404, 501, 200])
    func permanentErrorsAndSuccessfulEmptyResponsesAreNotRetried(status: Int) async throws {
        let client = NameSearchHTTPStub(statuses: [status])
        let result = try await ProductNameSearchRequest.send(request(), client: client) { _ in Issue.record("Unexpected retry") }
        #expect(result.response.statusCode == status)
        #expect(client.calls == 1)
    }

    @Test func retryAfterIsRespectedForRateLimitAndServerErrors() async throws {
        for status in [429, 503] {
            let client = NameSearchHTTPStub(statuses: [status, 200], retryAfter: "2")
            var waits: [TimeInterval] = []
            _ = try await ProductNameSearchRequest.send(request(), client: client) { waits.append($0) }
            #expect(waits == [2])
            #expect(client.calls == 2)
        }
    }

    @Test(arguments: ["30", "invalid", "99999999999999999999999999999999999999999999999999999999"])
    func longOrInvalidRetryAfterDoesNotCauseAnotherRequest(header: String) async throws {
        let client = NameSearchHTTPStub(statuses: [429], retryAfter: header)
        let result = try await ProductNameSearchRequest.send(request(), client: client) { _ in Issue.record("Unexpected retry") }
        #expect(result.response.statusCode == 429)
        #expect(client.calls == 1)
    }

    @Test func httpDateRetryAfterIsParsed() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(ProductNameSearchRequest.retryDelay("Thu, 01 Jan 1970 00:00:05 GMT", now: now) == 5)
        #expect(ProductNameSearchRequest.retryDelay("Wed, 31 Dec 1969 23:59:59 GMT", now: now) == 0)
    }

    @Test(arguments: [HTTPClientError.timedOut, .connectionLost, .offline, .invalidResponse, .transport("synthetic")])
    func onlyTransientTransportErrorsAreRetried(error: HTTPClientError) async {
        let client = NameSearchHTTPStub(statuses: [200])
        client.error = error
        await #expect(throws: HTTPClientError.self) {
            _ = try await ProductNameSearchRequest.send(request(), client: client, sleep: { _ in })
        }
        #expect(client.calls == ((error == .timedOut || error == .connectionLost) ? 3 : 1))
    }

    @Test func deadlineCancelsAnUnfinishedRequest() async {
        let client = NameSearchHTTPStub(statuses: [200])
        client.delay = .seconds(60)
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: HTTPClientError.timedOut) {
            _ = try await ProductNameSearchRequest.send(request(), client: client, budget: .milliseconds(30), sleep: { _ in })
        }
        #expect(start.duration(to: clock.now) < .seconds(2))
        #expect(client.calls == 1)
        #expect(client.cancelled)
    }

    @Test func cancellationDuringBackoffStopsFurtherRequests() async {
        let client = NameSearchHTTPStub(statuses: [503])
        var waiting = false
        let task = Task {
            try await ProductNameSearchRequest.send(request(), client: client) { _ in
                waiting = true
                try await Task.sleep(for: .seconds(60))
            }
        }
        while !waiting { await Task.yield() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(client.calls == 1)
    }

    private func request() -> URLRequest { URLRequest(url: URL(string: "https://example.test/search")!) }
}

@MainActor
private final class NameSearchHTTPStub: HTTPClientProtocol {
    var calls = 0
    var timeouts: [TimeInterval] = []
    var error: HTTPClientError?
    var delay: Duration?
    var cancelled = false
    let statuses: [Int]
    let retryAfter: String?

    init(statuses: [Int], retryAfter: String? = nil) {
        self.statuses = statuses
        self.retryAfter = retryAfter
    }

    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        calls += 1
        timeouts.append(timeout)
        if let delay {
            do { try await Task.sleep(for: delay) }
            catch { cancelled = true; throw error }
        }
        if let error { throw error }
        let response = HTTPURLResponse(url: request.url!, statusCode: statuses[min(calls - 1, statuses.count - 1)],
            httpVersion: nil, headerFields: retryAfter.map { ["Retry-After": $0] })!
        return HTTPClientResponse(data: Data(#"{"products":[]}"#.utf8), response: response)
    }
}
