import Foundation

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
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
        // Hook for analytics SDK init.
    }
    
    func stopOrDisable() {
        // Hook for analytics SDK shutdown / disable.
    }
}
