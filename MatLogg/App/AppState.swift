import Foundation
import Combine

enum AppTab: String, CaseIterable {
    case home
    case search
    case add
    case progress
    case profile
}

struct AppError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func general(_ message: String) -> AppError {
        AppError(title: "Noe gikk galt", message: message)
    }
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedMealType: String
    @Published var selectedTab: AppTab = .home
    @Published var logSelectedDate: Date = Date()
    @Published var logSelectedMeal: String?
    @Published var activeError: AppError?
    var errorMessage: String? {
        get { activeError?.message }
        set { activeError = newValue.map(AppError.general) }
    }
    @Published private(set) var syncStatusReadError: String?
    private var syncStatusRequest = UUID()
    @Published private(set) var syncQueueStatus: SyncQueueStatus = .empty
    @Published private(set) var syncFailures: [SyncFailureSummary] = []
    @Published private(set) var quarantinedSyncCount = 0
    @Published private(set) var isSyncing = false
    @Published private(set) var networkAvailability: NetworkAvailability = .unknown
    @Published var lastSyncAt: Date?
    @Published var lastSyncError: String?
    @Published var lastSyncSucceeded: Bool?
    
    // MARK: - Private Properties
    
    private let databaseService: DatabaseService
    private let syncEngine: SyncEngine
    private let syncEnabled: () -> Bool
    private var activeSyncUserId: UUID?

    var pendingSyncCount: Int { syncQueueStatus.pendingCount }
    var inFlightSyncCount: Int { syncQueueStatus.inFlightCount }
    var failedSyncCount: Int { syncQueueStatus.failedCount }
    var unsyncedSyncCount: Int { syncQueueStatus.unsyncedCount }
    var isSyncAvailable: Bool { syncEngine.isUploadAvailable && syncEnabled() }
    
    // MARK: - Init
    
    convenience init() {
        self.init(databaseService: DatabaseService())
    }

    init(databaseService: DatabaseService, now: Date = Date(), calendar: Calendar = .current) {
        self.databaseService = databaseService
        self.syncEngine = .shared
        self.syncEnabled = { FeatureFlags.backendSyncEnabled }
        self.selectedMealType = Self.defaultMealType(at: now, calendar: calendar)
        Task { await refreshSyncStatus() }
    }

    init(
        databaseService: DatabaseService,
        syncEngine: SyncEngine,
        syncEnabled: @escaping () -> Bool = { FeatureFlags.backendSyncEnabled },
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.databaseService = databaseService
        self.syncEngine = syncEngine
        self.syncEnabled = syncEnabled
        self.selectedMealType = Self.defaultMealType(at: now, calendar: calendar)
        Task { await refreshSyncStatus() }
    }

    static func defaultMealType(at date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<11: return "frokost"
        case 11..<16: return "lunsj"
        case 16..<21: return "middag"
        default: return "snacks"
        }
    }

    func presentError(title: String = "Noe gikk galt", message: String?) {
        guard let message, !message.isEmpty else { return }
        activeError = AppError(title: title, message: message)
    }
    
    // MARK: - Sync Status
    
    func refreshSyncStatus() async {
        let request = UUID()
        syncStatusRequest = request
        let owner = activeSyncUserId
        do {
            let quarantined = try await databaseService.quarantinedSyncCount()
            let status: SyncQueueStatus
            let failures: [SyncFailureSummary]
            if let owner {
                status = try await databaseService.syncQueueStatus(ownerUserId: owner)
                failures = try await databaseService.failedSyncEvents(ownerUserId: owner)
            } else { status = .empty; failures = [] }
            guard syncStatusRequest == request, activeSyncUserId == owner else { return }
            quarantinedSyncCount = quarantined
            syncQueueStatus = status
            syncFailures = failures
            syncStatusReadError = nil
        } catch {
            guard syncStatusRequest == request, activeSyncUserId == owner else { return }
            syncStatusReadError = "Kunne ikke lese synkstatus. Prøv igjen."
        }
    }

    func updateAuthenticatedUser(_ userId: UUID?) {
        if activeSyncUserId != userId {
            syncStatusRequest = UUID()
            syncQueueStatus = .empty
            syncFailures = []
            quarantinedSyncCount = 0
            syncStatusReadError = nil
        }
        activeSyncUserId = userId
        syncEngine.updateActiveOwner(userId)
        Task { await refreshSyncStatus() }
    }

    func updateNetworkAvailability(isConnected: Bool?) {
        networkAvailability = isConnected.map { $0 ? .online : .offline } ?? .unknown
    }
    
    func triggerSync(reason: SyncReason) async {
        guard isSyncAvailable else {
            lastSyncSucceeded = nil
            lastSyncError = nil
            await refreshSyncStatus()
            return
        }
        guard !isSyncing else { return }
        guard let activeSyncUserId else {
            await refreshSyncStatus()
            return
        }
        let syncUserId = activeSyncUserId
        isSyncing = true
        let result = await syncEngine.syncPendingEvents(ownerUserId: syncUserId)
        isSyncing = false
        guard self.activeSyncUserId == syncUserId else {
            await refreshSyncStatus()
            return
        }
        lastSyncAt = Date()
        lastSyncSucceeded = result.success
        lastSyncError = result.errorMessage
        if !result.success, case .userInitiated = reason {
            presentError(title: "Synkronisering feilet", message: result.errorMessage)
        }
        await refreshSyncStatus()
    }

    func retryFailedEvent(_ eventId: UUID) async {
        guard isSyncAvailable, let activeSyncUserId else { return }
        await databaseService.retryFailedEvent(eventId, ownerUserId: activeSyncUserId)
        await refreshSyncStatus()
        await triggerSync(reason: .userInitiated)
    }
    
}
