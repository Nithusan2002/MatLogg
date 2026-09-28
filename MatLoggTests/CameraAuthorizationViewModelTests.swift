import AVFoundation
import Testing
@testable import MatLogg

@MainActor
struct CameraAuthorizationViewModelTests {
    @Test func refreshMapsEveryKnownAuthorizationState() {
        #expect(CameraAuthorizationViewModel.state(for: .notDetermined) == .needsRequest)
        #expect(CameraAuthorizationViewModel.state(for: .authorized) == .authorized)
        #expect(CameraAuthorizationViewModel.state(for: .denied) == .denied)
        #expect(CameraAuthorizationViewModel.state(for: .restricted) == .restricted)
    }

    @Test func requestAccessStartsOnlyAfterExplicitUserAction() async {
        let provider = FakeCameraAuthorizationProvider(status: .notDetermined, requestResult: true)
        let viewModel = CameraAuthorizationViewModel(authorizationProvider: provider)

        viewModel.refresh()

        #expect(viewModel.state == .needsRequest)
        #expect(provider.requestCount == 0)

        await viewModel.requestAccess()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCount == 1)
    }

    @Test func deniedRequestShowsDeniedState() async {
        let provider = FakeCameraAuthorizationProvider(status: .notDetermined, requestResult: false)
        let viewModel = CameraAuthorizationViewModel(authorizationProvider: provider)

        viewModel.refresh()
        await viewModel.requestAccess()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCount == 1)
    }

    @Test func returningFromSettingsRefreshesAuthorization() {
        let provider = FakeCameraAuthorizationProvider(status: .denied, requestResult: false)
        let viewModel = CameraAuthorizationViewModel(authorizationProvider: provider)

        viewModel.refresh()
        #expect(viewModel.state == .denied)

        provider.status = .authorized
        viewModel.refresh()

        #expect(viewModel.state == .authorized)
    }

    @Test func restrictedAccessDoesNotRequestPermission() async {
        let provider = FakeCameraAuthorizationProvider(status: .restricted, requestResult: true)
        let viewModel = CameraAuthorizationViewModel(authorizationProvider: provider)

        viewModel.refresh()
        await viewModel.requestAccess()

        #expect(viewModel.state == .restricted)
        #expect(provider.requestCount == 0)
    }

    @Test func unavailableCameraHasDedicatedState() {
        let provider = FakeCameraAuthorizationProvider(status: .authorized, requestResult: true)
        let viewModel = CameraAuthorizationViewModel(authorizationProvider: provider)

        viewModel.refresh()
        viewModel.reportCameraUnavailable()

        #expect(viewModel.state == .unavailable)
    }
}

@MainActor
private final class FakeCameraAuthorizationProvider: CameraAuthorizationProviding {
    var status: AVAuthorizationStatus
    private let requestResult: Bool
    private(set) var requestCount = 0

    init(status: AVAuthorizationStatus, requestResult: Bool) {
        self.status = status
        self.requestResult = requestResult
    }

    func authorizationStatus() -> AVAuthorizationStatus {
        status
    }

    func requestAccess() async -> Bool {
        requestCount += 1
        status = requestResult ? .authorized : .denied
        return requestResult
    }
}
