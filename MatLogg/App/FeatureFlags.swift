import Foundation

enum FeatureFlags {
    nonisolated static let goalCalibrationEnabled = false
    nonisolated static let backendSyncEnabled = false
    nonisolated static var nutritionLabelAIEnabled: Bool { debugEnabled("--enable-nutrition-label-ai") }
    nonisolated static var sharedCatalogReadEnabled: Bool { debugEnabled("--enable-shared-catalog") }
    nonisolated static var catalogContributionsEnabled: Bool { debugEnabled("--enable-catalog-contributions") }
    nonisolated static var catalogAutoPublishEnabled: Bool { debugEnabled("--enable-catalog-auto-publish") }
    private nonisolated static func debugEnabled(_ argument: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(argument)
        #else
        false
        #endif
    }
}
