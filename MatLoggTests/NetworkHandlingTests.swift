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
