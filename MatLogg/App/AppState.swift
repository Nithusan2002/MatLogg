import Foundation
import Combine

enum AppTab: String, CaseIterable {
    case home
    case search
    case add
    case progress
    case profile
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedMealType: String = "lunsj" // default meal
    @Published var selectedTab: AppTab = .home
    @Published var logSelectedDate: Date = Date()
    @Published var logSelectedMeal: String?
    @Published var errorMessage: String?
    @Published var pendingSyncCount: Int = 0
    @Published var lastSyncAt: Date?
    @Published var lastSyncError: String?
    @Published var lastSyncSucceeded: Bool?
    
    // MARK: - Private Properties
    
    private let databaseService: DatabaseService
    
    // MARK: - Init
    
    init(databaseService: DatabaseService = DatabaseService()) {
        self.databaseService = databaseService
        Task { await refreshSyncStatus() }
    }
    
    // MARK: - Sync Status
    
    func refreshSyncStatus() async {
        let count = await databaseService.pendingSyncCount()
        pendingSyncCount = count
    }
    
    func triggerSync(reason: SyncReason) async {
        let result = await SyncEngine.shared.syncPendingEvents()
        lastSyncAt = Date()
        if FeatureFlags.backendSyncEnabled {
            lastSyncSucceeded = result.success
            lastSyncError = result.errorMessage
        } else {
            lastSyncSucceeded = nil
            lastSyncError = nil
        }
        await refreshSyncStatus()
    }
    
}
