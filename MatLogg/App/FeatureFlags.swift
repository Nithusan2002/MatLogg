import Foundation

enum FeatureFlags {
    nonisolated static let goalCalibrationEnabled = false
    // Pilot opt-in only. Release stays disabled until physical-device QA/go-no-go.
    nonisolated static var healthIntegrationEnabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--enable-healthkit")
        #else
        return false
        #endif
    }
    nonisolated static let backendSyncEnabled = false
}
