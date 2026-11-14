import Foundation

enum FeatureFlags {
    // Pilot: enable only after custom SMTP and email flows are verified.
    nonisolated static let emailAuthenticationEnabled = false
    nonisolated static let goalCalibrationEnabled = false
    nonisolated static let backendSyncEnabled = false
}
