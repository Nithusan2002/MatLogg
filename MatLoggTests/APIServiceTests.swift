import Foundation
import Testing
@testable import MatLogg

@Suite(.serialized)
@MainActor
struct APIServiceTests {
    @Test func loginPreservesBackendErrorCodeAndMessage() async throws {
        APIURLProtocolStub.handler = { request in
            #expect(request.url?.path == "/v1/auth/login")
            let body = #"{"code":"INVALID_CREDENTIALS","message":"E-post eller passord er feil"}"#
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { APIURLProtocolStub.handler = nil }

        let service = makeService()
        do {
            _ = try await service.loginEmail(email: "test@matlogg.no", password: "feil")
            Issue.record("Innlogging skulle ha feilet")
        } catch let error as APIService.APIError {
            guard case .backendError(let statusCode, let code, let message) = error else {
                Issue.record("Forventet en strukturert backend-feil")
                return
            }
            #expect(statusCode == 401)
            #expect(code == "INVALID_CREDENTIALS")
            #expect(message == "E-post eller passord er feil")
        }
    }

    @Test func loginUsesServerAuthMetadata() async throws {
        let userId = UUID()
        APIURLProtocolStub.handler = { request in
            let body = """
            {
              "user_id": "\(userId.uuidString)",
              "email": "test@matlogg.no",
              "first_name": "Test",
              "last_name": "Bruker",
              "auth_provider": "email",
              "created_at": "2026-09-24T10:00:00.000Z",
              "token": "token"
            }
            """
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { APIURLProtocolStub.handler = nil }

        let (user, token) = try await makeService().loginEmail(email: "test@matlogg.no", password: "hemmelig")
        #expect(user.id == userId)
        #expect(user.authProvider == "email")
        #expect(user.createdAt == Date(timeIntervalSince1970: 1_790_244_000))
        #expect(token == "token")
    }

    private func makeService() -> APIService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIURLProtocolStub.self]
        return APIService(session: URLSession(configuration: configuration), baseURL: "https://api.test/v1")
    }
}

private final class APIURLProtocolStub: URLProtocol, @unchecked Sendable {
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
