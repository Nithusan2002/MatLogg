import Foundation
import Testing
@testable import MatLogg

@Suite(.serialized)
@MainActor
struct NetworkHandlingTests {
    @Test func httpClientClassifiesOfflineTransportFailure() async throws {
        NetworkURLProtocolStub.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { NetworkURLProtocolStub.handler = nil }

        let client = URLSessionHTTPClient(session: makeSession())
        let request = URLRequest(url: try #require(URL(string: "https://example.test/data")))

        do {
            _ = try await client.send(request, timeout: 1)
            Issue.record("Kallet skulle ha feilet uten nett")
        } catch let error as HTTPClientError {
            #expect(error == .offline)
        }
    }

    @Test func httpClientClassifiesTimeout() async throws {
        NetworkURLProtocolStub.handler = { _ in
            throw URLError(.timedOut)
        }
        defer { NetworkURLProtocolStub.handler = nil }

        let client = URLSessionHTTPClient(session: makeSession())
        let request = URLRequest(url: try #require(URL(string: "https://example.test/data")))

        do {
            _ = try await client.send(request, timeout: 1)
            Issue.record("Kallet skulle ha timet ut")
        } catch let error as HTTPClientError {
            #expect(error == .timedOut)
        }
    }

    @Test func matvaretabellenRetriesFiveHundredAndThenSucceeds() async throws {
        var callCount = 0
        NetworkURLProtocolStub.handler = { request in
            callCount += 1
            let url = try #require(request.url)
            if callCount == 1 {
                return (
                    try #require(HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)),
                    Data()
                )
            }
            return (
                try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)),
                Data(#"[{"id":"1","name":"Banan","energy_kcal_100g":89}]"#.utf8)
            )
        }
        defer { NetworkURLProtocolStub.handler = nil }

        let service = MatvaretabellenService(
            session: makeSession(),
            retryLimit: 1,
            sleep: { _ in }
        )

        let products = try await service.searchProducts(query: "banan")

        #expect(products.first?.name == "Banan")
        #expect(callCount == 2)
    }

    @Test func matvaretabellenPreservesRateLimitRetryAfter() async throws {
        NetworkURLProtocolStub.handler = { request in
            let url = try #require(request.url)
            return (
                try #require(HTTPURLResponse(
                    url: url,
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: ["Retry-After": "45"]
                )),
                Data()
            )
        }
        defer { NetworkURLProtocolStub.handler = nil }

        let service = MatvaretabellenService(session: makeSession(), retryLimit: 0)

        do {
            _ = try await service.searchProducts(query: "banan")
            Issue.record("Rate limiting skulle ha blitt returnert som feil")
        } catch let error as APIService.APIError {
            guard case .rateLimited(let seconds) = error else {
                Issue.record("Forventet rateLimited, fikk \(error)")
                return
            }
            #expect(seconds == 45)
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NetworkURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class NetworkURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = Self.handler ?? { _ in throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
