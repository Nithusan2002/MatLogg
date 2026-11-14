import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
protocol MealPhotoRepository {
    func loadPhoto(using loadData: () async throws -> Data?) async throws -> Data
}

struct LocalMealPhotoRepository: MealPhotoRepository {
    func loadPhoto(using loadData: () async throws -> Data?) async throws -> Data {
        guard let data = try await loadData() else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try await BackgroundWork.run { try Self.prepare(data) }
    }

    // Re-encode only pixels: no location, EXIF or other original metadata.
    nonisolated static func prepare(_ data: Data, maximumPixelSize: Int = 1200) throws -> Data {
        guard data.count <= 30 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= 2 * 1024 * 1024 else {
            throw CocoaError(.fileWriteUnknown)
        }
        return output as Data
    }
}
