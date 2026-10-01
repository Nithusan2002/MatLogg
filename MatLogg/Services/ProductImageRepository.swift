import Foundation

protocol ProductImageRepository: Sendable {
    func data(for url: URL) async throws -> Data
}

/// Public product images only; separate from authenticated API traffic.
actor CachedProductImageRepository: ProductImageRepository {
    private let cache: URLCache
    private let session: URLSession

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

    func data(for url: URL) async throws -> Data {
        if url.isFileURL {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let root = base.appendingPathComponent("MatLogg/ProductImages", isDirectory: true).resolvingSymlinksInPath()
            let file = url.resolvingSymlinksInPath()
            guard file.path.hasPrefix(root.path + "/"), file.pathExtension.lowercased() == "jpg" else {
                throw URLError(.unsupportedURL)
            }
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            guard !data.isEmpty, data.count <= 5 * 1024 * 1024 else { throw URLError(.badServerResponse) }
            return data
        }
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
