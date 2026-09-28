import AVFoundation

@MainActor
protocol CameraAuthorizationProviding {
    func authorizationStatus() -> AVAuthorizationStatus
    func requestAccess() async -> Bool
}

@MainActor
struct CameraAuthorizationService: CameraAuthorizationProviding {
    nonisolated init() {}

    func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
