import Foundation
import CoreGraphics

protocol ProductImageRepository: Sendable {
    func data(for url: URL) async throws -> Data
    func pixels(for url: URL, maximumPixelSize: Int) async throws -> CGImage
}

extension ProductImageRepository {
    func pixels(for url: URL, maximumPixelSize: Int) async throws -> CGImage {
        try await ProductImagePreparation.pixels(from: data(for: url), maximumPixelSize: maximumPixelSize)
    }
}

/// Public product images only; separate from authenticated API traffic.
actor CachedProductImageRepository: ProductImageRepository {
    private let cache: URLCache
    private let session: URLSession
    private let decodedCache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 16 * 1024 * 1024
        cache.countLimit = 200
        return cache
    }()
    private var pendingImages: [String: Task<CGImage, Error>] = [:]
    private var pendingData: [URL: Task<Data, Error>] = [:]

    init(cache: URLCache = URLCache(memoryCapacity: 8 * 1024 * 1024,
                                    diskCapacity: 50 * 1024 * 1024,
                                    diskPath: "MatLoggProductImages")) {
        self.cache = cache
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 15
        session = URLSession(configuration: configuration)
    }

    func pixels(for url: URL, maximumPixelSize: Int) async throws -> CGImage {
        let key = "\(maximumPixelSize):\(url.absoluteString)"
        if let image = decodedCache.object(forKey: key as NSString) { return image }
        if let task = pendingImages[key] { return try await task.value }
        // Shared work survives a single row disappearing; callers check cancellation before publishing.
        let task = Task {
            try await ProductImagePreparation.pixels(from: self.data(for: url), maximumPixelSize: maximumPixelSize)
        }
        pendingImages[key] = task
        defer { pendingImages[key] = nil }
        let image = try await task.value
        decodedCache.setObject(image, forKey: key as NSString, cost: image.bytesPerRow * image.height)
        return image
    }

    func data(for url: URL) async throws -> Data {
        if let task = pendingData[url] { return try await task.value }
        let task = Task { try await self.fetchData(for: url) }
        pendingData[url] = task
        defer { pendingData[url] = nil }
        return try await task.value
    }

    private func fetchData(for url: URL) async throws -> Data {
        guard url.scheme == "https" else { throw URLError(.unsupportedURL) }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cached = cache.cachedResponse(for: request) { return cached.data }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              response.mimeType?.hasPrefix("image/") == true,
              data.count <= 5 * 1024 * 1024 else { throw URLError(.badServerResponse) }
        cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        return data
    }
}
