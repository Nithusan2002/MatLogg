import Foundation
import Testing
@testable import MatLogg

@Suite(.serialized)
@MainActor
struct ProductSearchTests {
    @Test func searchFiltersUnrelatedCatalogRowsAndRanksExactProductFirst() {
        let unrelatedNames = [
            "Adzukibønner, tørr",
            "Agavesirup",
            "Agurk, norsk, rå",
            "Aioli"
        ]
        for name in unrelatedNames {
            #expect(!ProductViewModel.searchMatches(query: "Monster Ultra White", name: name))
        }

        let exact = Product(
            name: "Monster Ultra White",
            brand: "Monster",
            source: "openfoodfacts",
            caloriesPer100g: 2,
            proteinGPer100g: 0,
            carbsGPer100g: 0.9,
            fatGPer100g: 0,
            nutritionSource: .openFoodFacts
        )
        let brandMatch = Product(
            name: "Ultra White, Zero Sugar",
            brand: "Monster Energy",
            source: "openfoodfacts",
            caloriesPer100g: 2,
            proteinGPer100g: 0,
            carbsGPer100g: 0.9,
            fatGPer100g: 0,
            nutritionSource: .openFoodFacts
        )

        #expect(ProductViewModel.searchMatches(
            query: "Monster Ultra White",
            name: brandMatch.name,
            brand: brandMatch.brand
        ))
        #expect(ProductViewModel.sortedSearchResults([brandMatch, exact], query: "Monster Ultra White").first?.id == exact.id)
    }

    @Test func openFoodFactsNameSearchReturnsCompletePackagedProducts() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
            let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(components.path == "/cgi/search.pl")
            #expect(queryItems["search_terms"] == "Monster")
            #expect(queryItems["page_size"] == "20")
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("MatLogg/") == true)
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("mailto:") == true)
            #expect(request.timeoutInterval == 10)

            let body = """
            {
              "products": [
                {
                  "code": "5060337502238",
                  "product_name": "Monster Ultra White",
                  "brands": "Monster",
                  "categories": "Energy drinks",
                  "image_url": "https://example.test/monster.jpg",
                  "nutriments": {
                    "energy-kcal_100g": 2,
                    "proteins_100g": 0,
                    "carbohydrates_100g": 0.9,
                    "fat_100g": 0,
                    "sugars_100g": 0
                  }
                },
                {
                  "code": "incomplete",
                  "product_name": "Incomplete Monster",
                  "nutriments": {
                    "energy-kcal_100g": 3
                  }
                }
              ]
            }
            """
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(session: URLSession(configuration: configuration))

        let products = try await service.searchProductsByNameOpenFoodFacts("Monster")

        #expect(products.count == 1)
        #expect(products.first?.name == "Monster Ultra White")
        #expect(products.first?.brand == "Monster")
        #expect(products.first?.barcodeEan == "5060337502238")
        #expect(products.first?.imageUrl == "https://example.test/monster.jpg")
        #expect(products.first?.caloriesPer100g == 2)
        #expect(products.first?.carbsGPer100g == 0.9)
        #expect(products.first?.nutritionSource == .openFoodFacts)
    }

    @Test func openFoodFactsBarcodeDoesNotReplaceMissingMacrosWithZero() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let body = """
            {
              "status": 1,
              "code": "1234567890123",
              "product": {
                "product_name": "Ufullstendig produkt",
                "nutriments": { "energy-kcal_100g": 120 }
              }
            }
            """
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
            return (response, Data(body.utf8))
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(session: URLSession(configuration: configuration))

        do {
            _ = try await service.searchProductByBarcodeOpenFoodFacts("1234567890123")
            Issue.record("Produkt uten komplette makroer skulle ha blitt avvist")
        } catch let error as APIService.APIError {
            guard case .decodingError = error else {
                Issue.record("Forventet decodingError, fikk \(error)")
                return
            }
        }
    }

    @Test func openFoodFactsRateLimitPreservesRetryAfter() async throws {
        SearchURLProtocolStub.handler = { request in
            let requestURL = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: requestURL,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "30"]
            ))
            return (response, Data())
        }
        defer { SearchURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SearchURLProtocolStub.self]
        let service = APIService(session: URLSession(configuration: configuration))

        do {
            _ = try await service.searchProductsByNameOpenFoodFacts("brød")
            Issue.record("Rate limit skulle ha blitt returnert som feil")
        } catch let error as APIService.APIError {
            guard case .rateLimited(let retryAfterSeconds) = error else {
                Issue.record("Forventet rateLimited, fikk \(error)")
                return
            }
            #expect(retryAfterSeconds == 30)
        }
    }
}

private final class SearchURLProtocolStub: URLProtocol, @unchecked Sendable {
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
