import Foundation

enum FeatureFlags {
    // Pilot: enable only after custom SMTP and email flows are verified.
    nonisolated static let emailAuthenticationEnabled = false
    // Release exposes sharing settings; each profile must explicitly opt in.
    nonisolated static var healthIntegrationEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--enable-healthkit-export")
        #else
        true
        #endif
    }
    nonisolated static let goalCalibrationEnabled = false
    nonisolated static let backendSyncEnabled = false
}
