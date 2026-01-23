import Foundation

final class CrashReportingManager {
    static let shared = CrashReportingManager()
    
    private(set) var isEnabled = false
    
    private init() {}
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            startIfEnabled()
        } else {
            stopOrDisable()
        }
    }
    
    func startIfEnabled() {
        guard isEnabled else { return }
        // Hook for crash reporting SDK init.
    }
    
    func stopOrDisable() {
        // Hook for crash reporting SDK shutdown / disable.
    }
}
