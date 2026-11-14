import Foundation
import UIKit
import Testing
@testable import MatLogg

struct ProductImageTests {
    @MainActor @Test func manualPhotoSurvivesReopenWithoutEnteringSyncPayload() async throws {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer {
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: databaseURL.path + suffix) }
        }
        let owner = UUID()
        let store = try LocalStore(databaseURL: databaseURL)
        let model = ManualProductViewModel(barcode: nil) { product in
            try store.saveProduct(product, ownerUserId: owner)
        }
        model.name = "Eget produkt"
        model.calories = "100"
        model.protein = "2"
        model.carbs = "10"
        model.fat = "4"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 600)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 600))
        }
        await model.selectImage(image)
        #expect(model.productImage?.size.width == 512)
        let product = try #require(await model.save())
        let bytes = try #require(product.localImageData)
        #expect(product.imageSource == .user)
        let reopened = try LocalStore(databaseURL: databaseURL)
        #expect(reopened.getProduct(product.id)?.localImageData == bytes)
        let events = reopened.fetchPendingEvents(limit: 10)
        #expect(events.count == 1)
        let json = try #require(JSONSerialization.jsonObject(with: events[0].payload) as? [String: Any])
        #expect(json["localImageData"] == nil)
        #expect(json["imageUrl"] == nil)
        let thumbnail = ProductThumbnailViewModel()
        await thumbnail.load(url: nil, localData: bytes, repository: nil)
        #expect(thumbnail.image != nil)
        await model.selectImage(nil)
        let withoutImage = try #require(await model.save())
        #expect(withoutImage.localImageData == nil)
        #expect(withoutImage.imageSource == .none)
    }

    @Test func cachedImageIsAvailableWithoutNetwork() async throws {
        let cache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 0, diskPath: UUID().uuidString)
        let url = try #require(URL(string: "https://images.example.invalid/product.png"))
        let bytes = Data([1, 2, 3])
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200,
                                                  httpVersion: nil, headerFields: ["Content-Type": "image/png"]))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: bytes),
                                  for: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
        let repository = CachedProductImageRepository(cache: cache)
        #expect(try await repository.data(for: url) == bytes)
    }

    @Test func openFoodFactsThumbnailsPreferSmallImageAndFallBackIfMissing() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenFoodFactsImageStub.self]
        let repository = CachedProductImageRepository(
            cache: URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0, diskPath: nil),
            configuration: configuration
        )
        let base = "https://images.openfoodfacts.org/images/products/123/"
        let smallAvailable = try #require(URL(string: base + "front_nb.1.400.jpg"))
        let smallMissing = try #require(URL(string: base + "front_nb.2.400.jpg"))

        // The stub only serves the 200 px URL for revision 1 and the original for revision 2.
        _ = try await repository.pixels(for: smallAvailable, maximumPixelSize: 160)
        _ = try await repository.pixels(for: smallMissing, maximumPixelSize: 160)
        await #expect(throws: URLError.self) {
            try await repository.pixels(for: smallAvailable, maximumPixelSize: 1200)
        }
    }

    @MainActor @Test func decodedImagesAreSharedAndSeparatedBySize() async throws {
        let cache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 0, diskPath: UUID().uuidString)
        let url = try #require(URL(string: "https://images.example.invalid/shared.png"))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let original = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 400), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 400))
        }
        let bytes = try #require(original.pngData())
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200,
                                                  httpVersion: nil, headerFields: ["Content-Type": "image/png"]))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: bytes),
                                  for: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
        let repository = CachedProductImageRepository(cache: cache)
        async let first = repository.pixels(for: url, maximumPixelSize: 160)
        async let second = repository.pixels(for: url, maximumPixelSize: 160)
        let (a, b) = try await (first, second)
        #expect(a === b)
        #expect(a.width == 160)
        #expect(a.height == 80)
        let cached = try await repository.pixels(for: url, maximumPixelSize: 160)
        #expect(cached === a)
        let larger = try await repository.pixels(for: url, maximumPixelSize: 320)
        #expect(larger.width == 320)
        #expect(larger !== a)
    }

    @Test func failedDecodeCanBeRetried() async throws {
        let cache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 0, diskPath: UUID().uuidString)
        let url = try #require(URL(string: "https://images.example.invalid/invalid.png"))
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200,
                                                  httpVersion: nil, headerFields: ["Content-Type": "image/png"]))
        cache.storeCachedResponse(CachedURLResponse(response: response, data: Data([1, 2, 3])),
                                  for: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
        let repository = CachedProductImageRepository(cache: cache)
        for _ in 0..<2 {
            await #expect(throws: (any Error).self) {
                try await repository.pixels(for: url, maximumPixelSize: 160)
            }
        }
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

private final class OpenFoodFactsImageStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        let hasImage = ["front_nb.1.200.jpg", "front_nb.2.400.jpg"].contains(url.lastPathComponent)
        guard let response = HTTPURLResponse(url: url, statusCode: hasImage ? 200 : 404,
                                             httpVersion: nil, headerFields: ["Content-Type": "image/gif"])
        else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if hasImage, let bytes = Data(base64Encoded: "R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7") {
            client.urlProtocol(self, didLoad: bytes)
        }
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
