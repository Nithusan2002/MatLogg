import Photos
import UIKit

enum MealSharePhotoSaveError: Error {
    case accessDenied
    case encodingFailed
}

@MainActor
protocol MealSharePhotoSaving {
    func requestAuthorization() async throws
    func save(_ image: UIImage) async throws
}

@MainActor
final class MealSharePhotoLibraryService: MealSharePhotoSaving {
    func requestAuthorization() async throws {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        try Task.checkCancellation()
        guard status == .authorized || status == .limited else {
            throw MealSharePhotoSaveError.accessDenied
        }
    }

    func save(_ image: UIImage) async throws {
        try Task.checkCancellation()
        guard let data = image.pngData() else { throw MealSharePhotoSaveError.encodingFailed }
        // Save only the rendered pixels; no original photo metadata or library reads.
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }
}
