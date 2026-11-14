import Foundation

enum FeatureFlags {
    // Pilot: enable only after custom SMTP and email flows are verified.
    nonisolated static let emailAuthenticationEnabled = false
    // Export is a development opt-in until physical-device QA and release approval.
    nonisolated static var healthIntegrationEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--enable-healthkit-export")
        #else
        false
        #endif
    }
    nonisolated static let goalCalibrationEnabled = false
    nonisolated static let backendSyncEnabled = false
}
