import Foundation
import Testing
@testable import MatLogg

@MainActor
struct APIServiceTests {
    @Test func invalidBaseURLReturnsTypedErrorWithoutStartingRequest() async {
        let service = APIService(baseURL: "://ugyldig")

        do {
            _ = try await service.loginEmail(email: "test@matlogg.no", password: "hemmelig")
            Issue.record("Ugyldig URL skulle ha feilet før nettverkskallet")
        } catch let error as APIService.APIError {
            guard case .invalidURL = error else {
                Issue.record("Forventet APIError.invalidURL")
                return
            }
        } catch {
            Issue.record("Forventet en typet API-feil, fikk \(error)")
        }
    }

    @Test func loginPreservesBackendErrorCodeAndMessage() async throws {
        let httpClient = HTTPClientStub { request, _ in
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
        let service = makeService(httpClient: httpClient)
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
        let httpClient = HTTPClientStub { request, timeout in
            #expect(request.url?.path == "/v1/auth/login")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(timeout == 30)
            let requestData = try #require(request.httpBody)
            let requestBody = try #require(
                JSONSerialization.jsonObject(with: requestData) as? [String: String]
            )
            #expect(requestBody == [
                "email": "test@matlogg.no",
                "password": "hemmelig"
            ])
            let body = """
            {
              "user_id": "\(userId.uuidString)",
              "email": "test@matlogg.no",
              "first_name": "Test",
              "last_name": "Bruker",
              "auth_provider": "email",
              "created_at": "2026-09-24T10:00:00.000Z",
              "token": "token",
              "refresh_token": "refresh-token"
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
        let (user, tokens) = try await makeService(httpClient: httpClient)
            .loginEmail(email: "test@matlogg.no", password: "hemmelig")
        #expect(user.id == userId)
        #expect(user.authProvider == "email")
        #expect(user.createdAt == Date(timeIntervalSince1970: 1_790_244_000))
        #expect(tokens == AuthTokens(accessToken: "token", refreshToken: "refresh-token"))
    }

    @Test func signupSendsOnlyEmailAndPassword() async throws {
        let userId = UUID()
        let httpClient = HTTPClientStub { request, _ in
            #expect(request.url?.path == "/v1/auth/register")
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
            #expect(body == ["email": "ny@matlogg.no", "password": "hemmelig-passord"])
            let responseBody = """
            {"user_id":"\(userId.uuidString)","email":"ny@matlogg.no","first_name":"","last_name":"","auth_provider":"email","created_at":"2026-09-27T10:00:00Z","token":"token","refresh_token":"refresh"}
            """
            let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil))
            return (response, Data(responseBody.utf8))
        }

        let (user, _) = try await makeService(httpClient: httpClient).signupEmail(email: "ny@matlogg.no", password: "hemmelig-passord")
        #expect(user.firstName.isEmpty)
        #expect(user.lastName.isEmpty)
    }

    @Test func appleLoginSendsCredentialAndNonce() async throws {
        let userId = UUID()
        let httpClient = HTTPClientStub { request, _ in
            #expect(request.url?.path == "/v1/auth/apple")
            let data = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
            #expect(body["identity_token"] == "identity")
            #expect(body["authorization_code"] == "code")
            #expect(body["nonce"] == "raw-nonce")
            let responseBody = """
            {"user_id":"\(userId.uuidString)","email":"relay@privaterelay.appleid.com","first_name":"","last_name":"","auth_provider":"apple","created_at":"2026-09-27T10:00:00Z","token":"token","refresh_token":"refresh"}
            """
            let response = try #require(HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil))
            return (response, Data(responseBody.utf8))
        }

        let (user, _) = try await makeService(httpClient: httpClient)
            .loginApple(identityToken: "identity", authorizationCode: "code", nonce: "raw-nonce")
        #expect(user.authProvider == "apple")
    }

    @Test func protectedRequestRefreshesOnceAfterUnauthorizedResponse() async throws {
        let store = APIAuthSessionStore(
            tokens: AuthTokens(accessToken: "expired-access", refreshToken: "valid-refresh")
        )
        var requestNumber = 0
        let httpClient = HTTPClientStub { request, _ in
            requestNumber += 1
            let url = try #require(request.url)
            switch requestNumber {
            case 1:
                #expect(request.httpMethod == "DELETE")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-access")
                return (try #require(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)), Data())
            case 2:
                #expect(request.url?.path == "/v1/auth/refresh")
                let body = #"{"token":"new-access","refresh_token":"new-refresh","expires_in":900}"#
                return (try #require(HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)), Data(body.utf8))
            default:
                #expect(request.httpMethod == "DELETE")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer new-access")
                let body = #"{"code":"ACCOUNT_PENDING_DELETION","message":"Kontoen er markert for sletting","permanentDeletionAt":"2026-10-27T10:00:00Z"}"#
                return (try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data(body.utf8))
            }
        }
        let service = APIService(
            httpClient: httpClient,
            baseURL: "https://api.test/v1",
            authSessionStore: store
        )

        _ = try await service.deleteAccount()

        #expect(requestNumber == 3)
        #expect(store.tokens == AuthTokens(accessToken: "new-access", refreshToken: "new-refresh"))
    }

    @Test func rejectedRefreshClearsSessionWithoutRetryingDomainRequest() async throws {
        let store = APIAuthSessionStore(
            tokens: AuthTokens(accessToken: "expired-access", refreshToken: "invalid-refresh")
        )
        var requestNumber = 0
        let httpClient = HTTPClientStub { request, _ in
            requestNumber += 1
            let url = try #require(request.url)
            if requestNumber == 1 {
                return (try #require(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)), Data())
            }
            #expect(request.url?.path == "/v1/auth/refresh")
            let body = #"{"code":"INVALID_REFRESH_TOKEN","message":"Sesjonen er utløpt"}"#
            return (try #require(HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)), Data(body.utf8))
        }
        let service = APIService(
            httpClient: httpClient,
            baseURL: "https://api.test/v1",
            authSessionStore: store
        )

        do {
            _ = try await service.deleteAccount()
            Issue.record("Ugyldig refresh-token skulle ha avsluttet sesjonen")
        } catch let error as APIService.APIError {
            guard case .sessionExpired = error else {
                Issue.record("Forventet APIError.sessionExpired")
                return
            }
        }
        #expect(requestNumber == 2)
        #expect(store.tokens == nil)
    }

    private func makeService(httpClient: any HTTPClientProtocol) -> APIService {
        APIService(httpClient: httpClient, baseURL: "https://api.test/v1")
    }
}

private final class APIAuthSessionStore: AuthSessionStore {
    var tokens: AuthTokens?
    private var user: User?

    init(tokens: AuthTokens?) {
        self.tokens = tokens
    }

    func storeUser(_ user: User) { self.user = user }
    func getStoredUser() -> User? { user }
    func storeToken(_ token: String) -> Bool {
        tokens = AuthTokens(accessToken: token, refreshToken: nil)
        return true
    }
    func getStoredToken() -> String? { tokens?.accessToken }
    func storeTokens(_ tokens: AuthTokens) -> Bool {
        self.tokens = tokens
        return true
    }
    func getStoredRefreshToken() -> String? { tokens?.refreshToken }
    func clearStoredCredentials() -> Bool {
        user = nil
        tokens = nil
        return true
    }
    func activateLocalProfile() -> User { .local(id: UUID()) }
    func getActiveLocalProfile() -> User? { nil }
    func consumeLocalProfile() {}
    func deactivateLocalMode() {}
    func hasCompletedOnboarding(userId: UUID) -> Bool { true }
    func onboardingCompletion(userId: UUID) -> Bool? { true }
    func setOnboardingCompleted(_ completed: Bool, userId: UUID) {}
}

private final class HTTPClientStub: HTTPClientProtocol {
    private let handler: (URLRequest, TimeInterval) throws -> (HTTPURLResponse, Data)

    init(handler: @escaping (URLRequest, TimeInterval) throws -> (HTTPURLResponse, Data)) {
        self.handler = handler
    }

    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        let (response, data) = try handler(request, timeout)
        return HTTPClientResponse(data: data, response: response)
    }
}
