import Foundation
import ImageIO
import UIKit

/// Decode only the pixels needed by the destination, outside MainActor.
nonisolated enum ProductImagePreparation {
    static func image(from data: Data, maximumPixelSize: Int = 1200) async throws -> UIImage {
        UIImage(cgImage: try await pixels(from: data, maximumPixelSize: maximumPixelSize))
    }

    static func pixels(from data: Data, maximumPixelSize: Int) async throws -> CGImage {
        try await BackgroundWork.run {
            guard maximumPixelSize > 0, data.count <= 30 * 1024 * 1024,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let pixels = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
            return pixels
        }
    }

    static func cameraJPEG(from image: UIImage) async throws -> Data {
        try await BackgroundWork.run {
            let factor = min(1, 512 / max(image.size.width, image.size.height))
            let size = CGSize(width: max(1, image.size.width * factor), height: max(1, image.size.height * factor))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let redrawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let data = redrawn.jpegData(compressionQuality: 0.75) else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
    }
}
