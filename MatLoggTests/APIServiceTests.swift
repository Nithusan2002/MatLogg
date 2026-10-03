import Foundation
import UIKit
import Testing
@testable import MatLogg

@MainActor
struct APIServiceTests {
    @Test func officialNutriScoreArtworkMatchesGradeAndKnownAlgorithm() throws {
        for grade in ["A", "B", "C", "D", "E"] {
            for version in ["2021", "2023"] {
                let info = try #require(ProductNutriScoreInfo(grade: grade, version: version))
                let name = try #require(info.imageAssetName)
                #expect(name == "NutriScore-\(version)-\(grade)")
                #expect(UIImage(named: name) != nil)
            }
        }
        #expect(ProductNutriScoreInfo(grade: "C", version: nil)?.imageAssetName == nil)
        #expect(ProductNutriScoreInfo(grade: "C", version: "future")?.imageAssetName == nil)
    }

    @Test func nutriScoreMappingWorksForBarcodeAndNameSearch() async throws {
        for grade in ["a", "B", "c", "D", "e", "unknown", "", "not-applicable"] {
            let client = HTTPClientStub { request, _ in
                let url = try #require(request.url)
                #expect(url.absoluteString.contains("nutriscore_grade"))
                let product = """
                {"code":"7039010081320","product_name":"Tomatketchup","nutriscore_grade":"\(grade)","nutriscore_version":"2023","nutriments":{"energy-kcal_100g":95,"proteins_100g":1.7,"carbohydrates_100g":21,"fat_100g":0}}
                """
                let body = url.path.contains("search.pl") ? "{\"products\":[\(product)]}" : "{\"status\":\"success\",\"product\":\(product)}"
                return (try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data(body.utf8))
            }
            let service = APIService(httpClient: client)
            let barcode = try await service.searchProductByBarcodeOpenFoodFacts("7039010081320")
            let search = try #require(try await service.searchProductsByNameOpenFoodFacts("Idun").first)
            let expected = ProductNutriScoreInfo(grade: grade, version: "2023")
            #expect(barcode.nutriScoreInfo == expected)
            #expect(search.nutriScoreInfo == expected)
        }
    }

    @Test func nutriScoreMissingOrMalformedEnrichmentDoesNotBlockLookup() async throws {
        for fields in [#""nutriscore_grade":null"#, #""nutriscore_grade":42"#, #""nutriscore_grade":"c","nutriscore_version":42"#] {
            let client = HTTPClientStub { request, _ in
                let url = try #require(request.url)
                let body = """
                {"status":"success","product":{"product_name":"Vare",\(fields),"nutriments":{"energy-kcal_100g":95,"proteins_100g":1.7,"carbohydrates_100g":21,"fat_100g":0}}}
                """
                return (try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data(body.utf8))
            }
            let item = try await APIService(httpClient: client).searchProductByBarcodeOpenFoodFacts("7039010081320")
            #expect(item.nutriScoreInfo?.version == nil)
            #expect(item.nutriScoreInfo?.grade == (fields.contains("\"c\"") ? "C" : nil))
        }
        #expect(ProductNutriScoreInfo(grade: "C", version: "future")?.version == "future")
    }

    @Test func processingEnrichmentUsesNorwegianAndToleratesMalformedFields() async throws {
        for enrichment in [
            #""nova_group":3,"nova_groups_markers":{"3":[["ingredients","en:salt"],["ingredients","en:sugar"]]},"ingredients_text":"Original","ingredients_text_nb":"Tomatpuré 80 %, sukker, eddik, salt, krydderekstrakt""#,
            #""nova_group":9,"nova_groups_markers":"invalid","ingredients_text_nb":42"#,
            #""nova_group":null"#
        ] {
            let client = HTTPClientStub { request, _ in
                let url = try #require(request.url)
                #expect(url.absoluteString.contains("nova_group"))
                let body = """
                {"status":"success","product":{"code":"7039010081320","product_name":"Tomatketchup","nutriments":{"energy-kcal_100g":95,"proteins_100g":1.7,"carbohydrates_100g":21,"fat_100g":0},\(enrichment)}}
                """
                return (try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), Data(body.utf8))
            }
            let product = try await APIService(httpClient: client).searchProductByBarcodeOpenFoodFacts("7039010081320")
            #expect(product.caloriesPer100g == 95)
            let info = try #require(product.processingInfo)
            if enrichment.contains("Tomatpuré") {
                #expect(info.novaGroup == 3)
                #expect(info.ingredients?.hasPrefix("Tomatpuré") == true)
                #expect(info.markerNames == ["salt", "sukker"])
            } else {
                #expect(info.novaGroup == nil)
            }
        }
    }

    @Test func partialProcessingMarkersAreExplicitWithoutExposingRawTags() {
        let info = ProductProcessingInfo(novaGroup: 4,
            markers: ["4": [["ingredients", "en:salt"], ["ingredients", "en:unknown"]]], ingredients: nil)
        #expect(info.markerNames == ["salt"])
        #expect(info.hasUntranslatedMarkers)
        #expect(ProductProcessingInfo(novaGroup: nil, markers: [:], ingredients: nil).classificationText == nil)
    }

    @Test func processingPresentationAndLegacyProductDecoding() throws {
        for group in 1...4 {
            let info = ProductProcessingInfo(novaGroup: group, markers: [String(group): [["ingredients", "en:unknown"]]], ingredients: nil)
            #expect(info.groupTitle.contains("NOVA \(group)"))
            #expect(info.markerNames.isEmpty)
            #expect(info.classificationText?.hasPrefix(group == 4 ? "Klassifisert" : "Ikke klassifisert") == true)
        }
        let product = Product(name: "Vare", caloriesPer100g: 95, proteinGPer100g: 1.7, carbsGPer100g: 21, fatGPer100g: 0,
                              nutriScoreInfo: ProductNutriScoreInfo(grade: "c", version: "2023"),
                              processingInfo: ProductProcessingInfo(novaGroup: 3, markers: [:], ingredients: "Tomat"))
        let encoded = try JSONEncoder().encode(product)
        #expect(try JSONDecoder().decode(Product.self, from: encoded).processingInfo == product.processingInfo)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(try JSONDecoder().decode(Product.self, from: encoded).nutriScoreInfo == product.nutriScoreInfo)
        json.removeValue(forKey: "nutriScoreInfo")
        json.removeValue(forKey: "processingInfo")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(Product.self, from: legacy).processingInfo == nil)
        #expect(try JSONDecoder().decode(Product.self, from: legacy).nutriScoreInfo == nil)
    }

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
