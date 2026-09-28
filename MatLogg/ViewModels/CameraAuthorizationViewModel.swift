import AVFoundation
import Combine

enum CameraAccessState: Equatable {
    case checking
    case needsRequest
    case requesting
    case authorized
    case denied
    case restricted
    case unavailable
}

@MainActor
final class CameraAuthorizationViewModel: ObservableObject {
    @Published private(set) var state: CameraAccessState = .checking

    private let authorizationProvider: any CameraAuthorizationProviding

    init(authorizationProvider: any CameraAuthorizationProviding) {
        self.authorizationProvider = authorizationProvider
    }

    func refresh() {
        state = Self.state(for: authorizationProvider.authorizationStatus())
    }

    func requestAccess() async {
        guard state == .needsRequest else {
            refresh()
            return
        }

        state = .requesting
        let granted = await authorizationProvider.requestAccess()
        state = granted ? .authorized : .denied
    }

    func reportCameraUnavailable() {
        state = .unavailable
    }

    static func state(for status: AVAuthorizationStatus) -> CameraAccessState {
        switch status {
        case .notDetermined:
            .needsRequest
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .authorized:
            .authorized
        @unknown default:
            .restricted
        }
    }
}
