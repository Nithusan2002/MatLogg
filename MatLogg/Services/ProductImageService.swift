import Foundation
import UIKit
@preconcurrency import Vision

nonisolated protocol ProductImageStoring {
    func store(_ image: UIImage, kind: ProductImageKind, draftID: UUID) async throws -> String
    func data(at path: String) async throws -> Data
}

nonisolated enum ProductImageKind: String, Sendable {
    case nutritionLabel = "label"
    case front = "front"
}

nonisolated enum ProductImageError: LocalizedError, Sendable {
    case unreadable
    case tooLarge
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Bildet kunne ikke leses. Prøv på nytt i godt lys."
        case .tooLarge: return "Bildet er for stort. Prøv et nærmere utsnitt."
        case .storageUnavailable: return "Bildet kunne ikke lagres lokalt."
        }
    }
}

actor LocalProductImageStore: ProductImageStoring {
    nonisolated static let maximumBytes = 5 * 1_024 * 1_024
    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.rootURL = rootURL ?? base.appendingPathComponent("MatLogg/ProductImages", isDirectory: true)
    }

    func store(_ image: UIImage, kind: ProductImageKind, draftID: UUID) async throws -> String {
        let normalized = Self.normalized(image)
        guard let data = normalized.jpegData(compressionQuality: 0.78), !data.isEmpty else {
            throw ProductImageError.unreadable
        }
        guard data.count <= Self.maximumBytes else { throw ProductImageError.tooLarge }
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let url = rootURL.appendingPathComponent("\(draftID.uuidString)-\(kind.rawValue).jpg")
            try data.write(to: url, options: .atomic)
            return url.path
        } catch let error as ProductImageError {
            throw error
        } catch {
            throw ProductImageError.storageUnavailable
        }
    }

    func data(at path: String) async throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    }

    /// Rendering into a new bitmap fixes orientation and drops source EXIF/GPS metadata.
    nonisolated static func normalized(_ image: UIImage) -> UIImage {
        let maximumDimension: CGFloat = 2_400
        let scale = min(1, maximumDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

nonisolated protocol NutritionLabelOCRService {
    func recognizeText(in image: UIImage) async throws -> String
}

nonisolated struct VisionNutritionLabelOCRService: NutritionLabelOCRService {
    func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = LocalProductImageStore.normalized(image).cgImage else {
            throw ProductImageError.unreadable
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["nb-NO", "en-US"]
            request.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cgImage).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

nonisolated protocol NutritionLabelAIService {
    func extract(assetID: UUID, imageData: Data, localOCRText: String, language: String) async throws -> NutritionExtraction
}

nonisolated struct UnavailableNutritionLabelAIService: NutritionLabelAIService, Sendable {
    func extract(assetID: UUID, imageData: Data, localOCRText: String, language: String) async throws -> NutritionExtraction {
        throw ProductAIError.unavailable
    }
}

nonisolated enum ProductAIError: LocalizedError, Sendable {
    case unavailable
    case refused
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable: return "AI-avlesning er ikke tilgjengelig. Du kan fylle inn verdiene manuelt."
        case .refused: return "Bildet kunne ikke behandles. Du kan fylle inn verdiene manuelt."
        case .invalidResponse: return "Forslaget kunne ikke leses. Kontroller etiketten manuelt."
        }
    }
}
