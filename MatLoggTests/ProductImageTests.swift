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
        model.selectImage(image)
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
        model.selectImage(nil)
        let withoutImage = try #require(await model.save())
        #expect(withoutImage.localImageData == nil)
        #expect(withoutImage.imageSource == .none)
    }

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
