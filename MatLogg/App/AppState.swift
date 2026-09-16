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
    @Published var pendingSyncCount: Int = 0
    @Published var lastSyncAt: Date?
    @Published var lastSyncError: String?
    @Published var lastSyncSucceeded: Bool?
    
    // MARK: - Private Properties
    
    private let databaseService: DatabaseService
    
    // MARK: - Init
    
    convenience init() {
        self.init(databaseService: DatabaseService())
    }

    init(databaseService: DatabaseService, now: Date = Date(), calendar: Calendar = .current) {
        self.databaseService = databaseService
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
        let count = await databaseService.pendingSyncCount()
        pendingSyncCount = count
    }
    
    func triggerSync(reason: SyncReason) async {
        let result = await SyncEngine.shared.syncPendingEvents()
        lastSyncAt = Date()
        if FeatureFlags.backendSyncEnabled {
            lastSyncSucceeded = result.success
            lastSyncError = result.errorMessage
            if !result.success {
                presentError(title: "Synkronisering feilet", message: result.errorMessage)
            }
        } else {
            lastSyncSucceeded = nil
            lastSyncError = nil
        }
        await refreshSyncStatus()
    }
    
}
