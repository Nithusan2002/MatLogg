import Foundation
import Testing
@testable import MatLogg

struct ProductImageTests {
    @Test func cachedImageIsAvailableWithoutNetwork() async throws {
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        let url = try #require(URL(string: "https://images.example.invalid/product.png"))
        let bytes = Data([1, 2, 3])
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200,
                                                  httpVersion: nil, headerFields: ["Content-Type": "image/png"]))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: bytes),
                                  for: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
        let repository = CachedProductImageRepository(cache: cache)
        #expect(try await repository.data(for: url) == bytes)
    }

    @Test func insecureImageURLIsRejected() async throws {
        let url = try #require(URL(string: "http://images.example.invalid/product.png"))
        let repository = CachedProductImageRepository()
        await #expect(throws: URLError.self) { try await repository.data(for: url) }
    }

    @MainActor @Test func invalidOrMissingImageKeepsPlaceholder() async throws {
        let model = ProductThumbnailViewModel()
        let url = try #require(URL(string: "https://images.example.invalid/product.png"))
        await model.load(url: url, repository: InvalidImageRepository())
        #expect(model.image == nil)
        await model.load(url: nil, repository: InvalidImageRepository())
        #expect(model.image == nil)
    }
}

private struct InvalidImageRepository: ProductImageRepository {
    func data(for url: URL) async throws -> Data { Data("invalid image".utf8) }
}
