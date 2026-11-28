#if DEBUG
import Foundation

/// Scripted public-catalog responses, available only in the isolated search QA app.
@MainActor
final class ProductSearchRetryQAFixture: HTTPClientProtocol {
    static func makeClient() -> ProductSearchRetryQAFixture? {
        guard Bundle.main.bundleIdentifier == "com.nithusan.MatLogg.searchqa20261128.MatLogg",
              ProcessInfo.processInfo.arguments.contains("--product-search-retry-qa") else { return nil }
        let mode = ProcessInfo.processInfo.environment["MATLOGG_SEARCH_RETRY_QA"] ?? "recover"
        return ProductSearchRetryQAFixture(mode: mode)
    }

    private let mode: String
    private var attempts: [String: Int] = [:]

    private init(mode: String) { self.mode = mode }

    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        guard let url = request.url else { throw HTTPClientError.invalidResponse }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "search_terms" }?.value ?? ""
        attempts[query, default: 0] += 1
        if mode == "timeout" { try await Task.sleep(for: .seconds(60)) }
        try await Task.sleep(for: .milliseconds(250))
        let status: Int
        if mode == "rate-limit" { status = 429 }
        else if mode == "unavailable" || attempts[query, default: 0] <= 2 { status = 503 }
        else { status = 200 }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
            headerFields: status == 429 ? ["Retry-After": "30"] : nil) else {
            throw HTTPClientError.invalidResponse
        }
        let body = #"{"products":[{"code":"9900000000028","product_name":"Havregryn nettvare QA","brands":"Syntetisk QA","nutriments":{"energy-kcal_100g":370,"proteins_100g":13,"carbohydrates_100g":60,"fat_100g":7}}]}"#
        return HTTPClientResponse(data: Data((status == 200 ? body : "{}").utf8), response: response)
    }
}
#endif
